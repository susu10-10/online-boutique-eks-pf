variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
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
