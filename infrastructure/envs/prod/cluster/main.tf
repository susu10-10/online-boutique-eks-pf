# Create the namespace for Argo CD
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace_v1" "platform" {
  metadata {
    name = "platform"
  }
}

resource "kubernetes_namespace_v1" "boutique" {
  metadata {
    name = "boutique"
    labels = {
      "linkerd.io/inject" = "enabled"
    }
  }
}


# AWS Load Balancer Controller must exist before Argo CD's own Ingress
# (installed below) can ever get an ALB provisioned. This is exactly why it
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "3.5.0"

  set = [
    { name = "clusterName", value = data.terraform_remote_state.bootstrap.outputs.cluster_name },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = data.terraform_remote_state.bootstrap.outputs.aws_lb_controller_irsa_role_arn },
    { name = "vpcId", value = data.terraform_remote_state.bootstrap.outputs.vpc_id },
    { name = "region", value = var.aws_region },
  ]
}

# external-dns writes the argocd.suworks.me Route 53 record once the ALB exists
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.21.0"

  set = [
    { name = "provider", value = "aws" },
    { name = "aws.zoneType", value = "public" },
    { name = "domainFilters[0]", value = var.domain_name },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = "external-dns" },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = data.terraform_remote_state.bootstrap.outputs.external_dns_irsa_role_arn },
    { name = "policy", value = "sync" },
  ]
}

# Install Argo CD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "10.2.1"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  values = [
  templatefile("${path.module}/../../../../clusters/boutique/argocd/values.yaml"), {
    acm_certificate_arn = data.terraform_remote_state.bootstrap.outputs.acm_certificate_arn
}]

  set = [{
    name  = "server.insecure"
    value = "true" # TLS is handled at the ALB edge
  }]
  depends_on = [
    kubernetes_namespace_v1.argocd,
    helm_release.aws_lb_controller,
    helm_release.external_dns,
  ]

}


# Apply the Root App
resource "kubectl_manifest" "root_app" {
  depends_on = [helm_release.argocd]

  # Reads the root-app.yaml from your clusters directory
  yaml_body = file("../../../../clusters/boutique/argocd/root-app.yaml")
}