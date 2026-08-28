# 1. Create the namespace for Argo CD
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

# 2. Install Argo CD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "10.2.1"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  values     = [file("${path.module}/../../../../clusters/boutique/argocd/values.yaml")]

  set = [{
    name  = "server.insecure"
    value = "true" # TLS is handled at the ALB edge
  }]
  depends_on = [kubernetes_namespace_v1.argocd]

}


# 3. Apply the Root App
resource "kubectl_manifest" "root_app" {
  depends_on = [helm_release.argocd]

  # Reads the root-app.yaml from your clusters directory
  yaml_body = file("../../../../clusters/boutique/argocd/root-app.yaml")
}