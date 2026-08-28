# Read the outputs from the bootstrap stack
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = "online-boutique-tfstate-767397659229"
    key    = "online-boutique/prod/eks-platform/eks-bootstrap.tfstate"
    region = "us-east-1"
  }
}

# Ask AWS for a 15-minute token to access the cluster
data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.bootstrap.outputs.cluster_name
}