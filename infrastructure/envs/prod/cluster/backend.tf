terraform {
  backend "s3" {
    bucket       = "online-boutique-tfstate-767397659229"
    key          = "online-boutique/prod/eks-platform/cluster.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}