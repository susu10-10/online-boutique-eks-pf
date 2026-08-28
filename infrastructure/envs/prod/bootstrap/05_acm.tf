data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

#checkov:skip=CKV_TF_1:
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.0"

  domain_name = "*.${var.domain_name}"
  zone_id     = data.aws_route53_zone.main.zone_id

  validation_method = "DNS"

  subject_alternative_names = [
    var.domain_name
  ]

  wait_for_validation = true

  tags = var.tags


}