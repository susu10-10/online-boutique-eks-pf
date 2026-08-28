output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "acm_certificate_arn" {
  description = "The ARN of the validated ACM certificate"
  value       = module.acm.acm_certificate_arn
}


output "cluster_certificate_authority_data" {
  description = "Base64 encoded EKS certificate data required to communicate with the cli"
  value       = module.eks.cluster_certificate_authority_data
}

output "ebs_csi_driver_irsa_role_arn" {
  description = "IAM Role ARN for the EBS CSI Driver"
  value       = module.ebs_csi_driver_irsa.iam_role_arn
}

output "aws_lb_controller_irsa_role_arn" {
  description = "IAM Role ARN for the AWS Load Balancer Controller"
  value       = module.alb_irsa.iam_role_arn
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "oidc_provider_arn" {
  description = "The ARN of the EKS OIDC Provider"
  value       = module.eks.oidc_provider_arn
}