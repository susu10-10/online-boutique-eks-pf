# Security Posture & Threat Model

## 1. Defense in depth, layer by layer

| Layer | Control |
|---|---|
| Image supply chain | Cosign-signed images (keyless, OIDC-based), ECR scan-on-push, Trivy CI gate (fails build on high/critical CVEs), Semgrep + Checkov + Hadolint + TruffleHog in CI |
| Admission control | Kyverno 7 CEL policies enforced at admission, not just audited (see §2) |
| Runtime | Falco (eBPF)  behavioral anomaly detection at the syscall level, independent of admission-time checks |
| Network | Linkerd mTLS between every service; deny-all `NetworkPolicy` default, explicit per-service allow rules |
| Public edge | ACM-terminated TLS at the ALB; no plaintext HTTP reaches the VPC boundary |
| Cloud API access | IRSA no controller has AWS credentials broader than its own single purpose (see `docs/architecture.md` §3) |
| Secrets at rest | AWS Secrets Manager (AWS-managed KMS key see §4 for the explicit trade-off), never committed to git, never a cluster-pinned keypair |
| CI/CD trust | Zero static cloud credentials in either GitHub repo, OIDC federation, repo-and-branch-pinned trust policy |

## 2. Kyverno policies enforced

- `drop-all-capabilities` no Linux capabilities beyond the minimum a container needs
- `require-nonroot` no container may run as UID 0
- `require-probes` every container must define at least one health probe
- `require-readonly-rootf` root filesystem must be read-only
- `require-resource-limits` every container must declare CPU/memory requests and limits
- `restrict-latest-tag` no `:latest` image tags, immutable SHA-pinned tags only
- `restrict-seccomp` seccomp profile enforced

These are visible in this project's own build history as genuine, non-decorative controls: several components (Grafana's sidecars, early External Secrets Operator deployment) triggered real `PolicyViolation` warnings during development, which is documented in `docs/operations.md` rather than quietly suppressed.

## 3. Secrets architecture

sealed-secrets was evaluated and deliberately moved away from for this project, specifically because it encrypts against a keypair generated fresh per cluster, meaning that every sealed secret becomes permanently undecryptable ciphertext on any cluster migration or rebuild. This is not a hypothetical concern; it's the exact failure this migration hit (see [`docs/doks-to-eks-migration.md`](doks-to-eks-migration.md) §3.5). AWS Secrets Manager + External Secrets Operator, IRSA-authenticated, was chosen instead because the secret's source of truth lives outside the cluster's lifecycle entirely a full cluster rebuild regenerates the sync chain automatically with no manual re-encryption step.

The one value that genuinely cannot live in a committed file the raw Grafana admin password is seeded from a GitHub Actions encrypted secret, the same trust boundary already used for the OIDC role ARN and Route 53 zone ID. This is the standard, non-negotiable boundary in any secrets pipeline, not a workaround.

## 4. Documented risk acceptances

Every Checkov finding in this project's CI was either fixed or explicitly accepted with a written reason never silently suppressed:

| Finding | Decision | Reasoning |
|---|---|---|
| `CKV_TF_1` (module source pinned to commit hash) | Skipped, pipeline-level | `terraform-aws-modules` is one of the most-audited namespaces on the registry; semver pinning + a committed lockfile is judged sufficient given the namespace's audit history, versus the maintenance cost of commit-hash pinning at this project's scale |
| `CKV_AWS_355` (wildcard IAM resource) | Skipped per-statement, not blanket | Two categories: actions AWS genuinely does not permit scoping (`route53:ListHostedZones` requires `Resource: "*"` by design) and infrastructure-provisioning permissions (`ec2:*`, `eks:*`) where meaningful scoping is impractical for a pipeline that provisions the network/cluster itself |
| `CKV_AWS_149` (Secrets Manager CMK) | Skipped | AWS-managed key already encrypts at rest; a dedicated customer-managed KMS key is disproportionate setup for a single secret at this project's scale noted explicitly in `docs/architecture.md` §5 as a change warranted at real production scale |

Per-statement (not blanket) skips were used wherever the finding could recur for a genuinely different reason in the future a blanket pipeline-level skip on `CKV_AWS_355`, for example, would silently stop checking every future IAM statement in this directory, not just the ones already reasoned through.

## 5. What a real production deployment would add

- Customer-managed KMS keys per secret category, with a dedicated audit trail
- Automatic Secrets Manager rotation for any credential longer-lived than this project's scope
- AWS GuardDuty + Security Hub running continuously (evaluated during the ECS-phase build, not
  currently running continuously here to control cost)
- Multi-account separation between foundation, network, and workload layers