variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "online-boutique-eks"
}

variable "environment" {
  description = "The environment to deploy to"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "online-boutique-AWS-EKS"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

variable "domain_name" {
  description = "The custom domain name for the portfolio"
  type        = string
  default     = "suworks.me"
}

variable "aws_account_id" {
  description = "The AWS account ID"
  type        = string
  default     = "767397659229"
}


variable "grafana_admin_password" {
  description = "Grafana admin password — passed via -var in CI, sourced from GitHub Secrets"
  type        = string
  sensitive   = true
}
