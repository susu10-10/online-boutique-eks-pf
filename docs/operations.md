# Operations Runbook

This is a living document patterns are added as they're encountered, in the same spirit as the DOKS build's own `operations.md`. Each entry states the symptom, the actual root cause (not just the fix), and the remedy.

## Health check run this first, always

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get ingress -A
```

A healthy platform shows: all nodes `Ready`, every Argo CD Application `Synced`/`Healthy`, and all three Ingresses (`argocd-server`, `frontend`, `prometheus-grafana`) sharing one `ADDRESS` with `PORTS` showing `80, 443` for anything ACM-fronted.

## Forcing an Argo CD sync without waiting for the poll interval

This is not equivalent to a manual imperative fix — it only ever reconciles toward whatever is already committed to git, it just skips the ~3 minute default polling wait:

```bash
kubectl patch application <app-name> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## Symptom → root cause → remedy

**Pods stuck `Pending` with `0/1 nodes are available: 1 Too many pods`, despite low CPU/memory usage.**

Root cause: AWS caps pods per node by ENI/IP capacity, not compute headroom this is a hard ceiling independent of `kubectl describe nodes`' `Allocated resources` output.

Remedy: increase `desired_size` on the node group in `bootstrap/02_eks.tf`. Do not raise `min_size` in the same apply if it would exceed the *current* (pre-apply) `desired_size` the EKS API validates the new minimum against the old desired value mid-transaction and will reject the update; raise `desired_size` alone first if this happens.

**One Ingress's ALB never gets an HTTPS listener, even though its own annotations look correct.**

Root cause: if this Ingress shares an `alb.ingress.kubernetes.io/group.name` with others, the AWS Load Balancer Controller builds one combined model for the entire group. A single misconfigured member (commonly: missing `target-type: ip` when the backing Service is `ClusterIP`) blocks the whole group's model from deploying the symptom can appear on a completely unrelated, correctly-configured member of the same group.

Remedy: `kubectl describe ingress <name> -n <namespace>` and check the `Events` section for `FailedBuildModel` it names the actually-broken member, not necessarily the Ingress you ran the command against.

**An Argo CD Application stays `OutOfSync` indefinitely, and everything queued behind it in an App-of-Apps also appears stuck for unrelated reasons.**

Root cause: check whether the *parent* (root) Application's own sync operation is stuck `Running` Argo CD will not start a new sync while a previous operation is still in progress, so unrelated child apps can appear broken when they're actually just waiting in a blocked queue.

```bash
kubectl describe application root-platform-app -n argocd | grep -A5 "Operation State"
```

If it shows `waiting for deletion of argoproj.io/Application/<name>` indefinitely, that child's `resources-finalizer.argocd.argoproj.io` finalizer is stuck. Confirm nothing is legitimately still in progress, then:

```bash
kubectl patch application <stuck-app> -n argocd --type merge -p '{"metadata":{"finalizers":[]}}'
```

**A CRD-installing Argo CD Application fails repeatedly with `metadata.annotations: Too long: may not be more than 262144 bytes`.**

Root cause: Kubernetes caps every object's total annotation size at 256KiB. Client-side apply stores the entire object definition in a `last-applied-configuration` annotation for diffing some CRDs (External Secrets Operator's `ClusterSecretStore`/`SecretStore` among the largest in the ecosystem) exceed that limit on their own.

Remedy: add both `ServerSideApply=true` (prevents recurrence) and `Replace=true` (required once, to clear CRD objects already poisoned by prior failed client-side-apply attempts SSA alone does not retroactively fix an already-corrupted object) to the Application's `syncOptions`.

**A Helm value change to an already-running component (e.g. Linkerd's `externalCA` setting) doesn't appear to take effect after Argo CD reports `Synced`.**

Root cause: some values changes don't alter the Deployment spec in a way that forces Kubernetes to restart the pod on its own.

Remedy: `kubectl rollout restart deploy/<name> -n <namespace>`a restart signal, not a change to desired state; git remains the only source of truth for *what* the new config is.

## Cost controls

- Node group: scale `desired_size` down between demo/interview sessions if not actively needed;
  scaling to 0 is not supported for a group running DaemonSets (Falco, Alloy) without accepting
  their absence, prefer reducing to the minimum functional count instead
- NAT Gateway: single, not per-AZ, which is a deliberate cost/availability trade-off at this project's scale
- ALB: one shared load balancer across three hostnames via `group.name`, not three
- ECR: lifecycle policy retains only the last 5 tagged images per repository.