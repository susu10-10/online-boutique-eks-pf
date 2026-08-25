
# MicroSvc to loop through
locals {
  microservices = [
    "frontend",
    "cartservice",
    "productcatalogservice",
    "currencyservice",
    "paymentservice",
    "shippingservice",
    "emailservice",
    "checkoutservice",
    "recommendationservice",
    "adservice",
    "loadgenerator"
  ]
}

module "ecr" {
  source   = "terraform-aws-modules/ecr/aws"
  version  = "~> 3.0.0"
  for_each = toset(local.microservices)

  # Create repos like online-boutique/frontend
  repository_name = "${var.project_name}/${each.key}"

  # Gh Actions to push updated SHA tags over the existing ref if needed
  repository_image_tag_mutability = "IMMUTABLE"

  #ecr vuln scanner
  repository_image_scan_on_push = true
  repository_force_delete       = true


  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 3 images",
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = 3
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = var.tags

}