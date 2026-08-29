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

# external-dns: watches Ingress hostname annotations and writes/updates Route 53
# records automatically. Required by cluster/main.tf's external-dns helm_release
# without this, argocd.suworks.me (and later the boutique storefront's hostname)
# has no way to get a DNS record without a manual aws_route53_record per app.

resource "aws_iam_policy" "external_dns" {
  name        = "${var.project_name}-external-dns-policy"
  description = "Scoped to the suworks.me hosted zone only — least privilege, not route53:*"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${data.aws_route53_zone.main.zone_id}"
      },
      {
        #checkov:skip=CKV_AWS_355:route53:ListHostedZones does not support resource-level permissions — AWS requires Resource "*" for this specific action, per AWS's own IAM action reference. Not scopable by design, not an oversight.

        Effect   = "Allow"
        Action   = ["route53:ListHostedZones"]
        Resource = "*"
      }
    ]
  })
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name = "external-dns"

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  policies = {
    ExternalDnsPolicy = aws_iam_policy.external_dns.arn
  }

  tags = var.tags
}