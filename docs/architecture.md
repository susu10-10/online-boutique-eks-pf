# Architecture & Security Deep Dive, Networking, State Design, and GitOps Ordering

## 1. Three-state Terraform, and why the split

| State | Directory | Backend key | Owns | Change frequency |
|---|---|---|---|---|
|Account foundation | `infrastructure/envs/prod/` | `eks-platform/bootstrap.tfstate` | OIDC providers (GitHub Actions + cluster IRSA), the two deploy roles (app-repo, platform-repo), ECR repositories | Rare touched once per new repo/role, essentially never after |
| Hardware & network | `infrastructure/envs/prod/bootstrap/` | `eks-platform/eks_bootstrap.tfstate` | VPC, EKS cluster, managed node group, IRSA roles, ACM cert, Secrets Manager entries | Occasional node scaling, new IRSA roles |
| Software mesh | `infrastructure/envs/prod/cluster/` | `eks-platform/cluster.tfstate` | Namespaces, AWS Load Balancer Controller, external-dns, Argo CD install, the one-time root Application handoff | Rare after initial stabilization |

Each state is a **separate Terraform root module** separate `terraform init`, separate state file, separate GitHub Actions workflow. State 3 reads state 2's outputs via `terraform_remote_state`, not shared variables, this is what lets the `kubernetes`/`helm` providers in state 3 authenticate against a cluster that state 2 alone knows how to reach.

## 2. Network design

```
Public subnets (2 AZs)          Private subnets (2 AZs)
┌─────────────────┐             ┌──────────────────────────────┐
│   ALB (shared    │             │  EKS managed node group       │
│   group: 3 hosts) │────────────▶│  (m7i-flex.large × 3)         │
└─────────────────┘             │                                │
        ▲                        │  - All 11 boutique services    │
        │                        │  - Argo CD, Linkerd, Kyverno,  │
   Route 53                      │    Falco, Loki, Prometheus     │
   (external-dns                 └──────────────────────────────┘
    managed)                             NAT Gateway (1, cost-controlled)
```

Unlike the ECS-phase project (which avoided NAT Gateway entirely via VPC endpoints), this cluster **does** run a NAT Gateway. EKS worker nodes need broader outbound access for kubelet bootstrap and Helm chart pulls than ECS Fargate tasks need for their narrower set of AWS API calls the zero-NAT pattern doesn't transfer cleanly to node-based Kubernetes, and forcing it here would cost more in VPC endpoint sprawl than the NAT Gateway itself. Documented as a deliberate trade-off, not an oversight.

## 3. IRSA one role per controller, least privilege per role

| Controller | ServiceAccount | Scope |
|---|---|---|
| AWS Load Balancer Controller | `kube-system:aws-load-balancer-controller` | `elasticloadbalancing:*`, EC2 describe/tag actions (AWS-managed policy) |
| EBS CSI driver | `kube-system:ebs-csi-controller-sa` | AWS-managed `AmazonEBSCSIDriverPolicy` |
| external-dns | `kube-system:external-dns` | `route53:ChangeResourceRecordSets` scoped to the `suworks.me` zone ID only; `route53:ListHostedZones` on `*` (the one action AWS does not permit scoping) |
| External Secrets Operator | `external-secrets:external-secrets` | `secretsmanager:GetSecretValue`/`DescribeSecret` scoped to `online-boutique/*` only |

No controller has access to any AWS resource outside its own narrow purpose. None of the four
have write access to IAM, VPC, or each other's resources.

## 4. Shared ALB one load balancer, three hostnames

`argocd.suworks.me`, `grafana.suworks.me`, and `shop.suworks.me` share a single ALB via matching `alb.ingress.kubernetes.io/group.name: boutique-shared-alb` annotations, one ALB (~$16/mo) instead of three. The AWS LoadBalancer Controller builds **one combined model per group**: every member Ingress must be independently valid (correct `target-type`, correct certificate ARN) or the controller refuses to deploy the entire group's model, not just the broken member. See `docs/operations.md` for the specific incident this caused.

## 5. Argo CD sync-wave ordering (as currently applied)

| Wave | Applications | Why this wave |
|---|---|---|
| 0 (default, unset) | `alloy`, `cert-manager`, `external-secrets`, `falco`, `monitoring-servicemonitors` | No dependency on anything else in this platform |
| 1 | `kyverno-controller`, `linkerd-crds`, `trust-manager` | CRDs/controllers other waves depend on existing first |
| 2 | `certificates`, `kyverno-custom-policies`, `loki`, `prometheus` | Depend on wave-1 CRDs/controllers being registered |
| 3 | `boutique`, `linkerd-cp`, `prometheus-rules` | Depend on wave-2 resources (namespaces, storage, CRs) existing |
| 10 | `platform-secrets` | Deliberately late to ensure, that the External Secrets Operator (wave 0) and its CRDs are fully stable before any `ExternalSecret`/`ClusterSecretStore` is applied |

`root-platform-app` itself has no sync-wave, it's the App-of-Apps that creates every row in this
table from `clusters/boutique/infrastructure-apps/`, via `directory.recurse: true`.

## 6. Storage

EKS ships with no default `StorageClass`, unlike DOKS's implicit DO Block Storage default. A `gp3` `StorageClass` is explicitly defined (`platform-configs/storage/gp3-storageclass.yaml`) and marked `storageclass.kubernetes.io/is-default-class: "true"`, restoring the "PVCs just work" behavior the DOKS build had for free.