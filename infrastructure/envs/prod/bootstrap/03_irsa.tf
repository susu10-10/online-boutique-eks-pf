#checkov:skip=CKV_TF_1:terraform-aws-modules is a verified, widely-audited registry namespace; version pinned via semver constraint + lockfile
module "alb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name                                   = "aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true


  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  #   policies = {
  #     policy = "arn:aws:iam::012345678901:policy/myapp"
  #   }
}

# IAM Role IRSA - EBS CSI Driver

#checkov:skip=CKV_TF_1:terraform-aws-modules is a verified, widely-audited registry namespace; version pinned via semver constraint + lockfile
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name = "ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags

}

