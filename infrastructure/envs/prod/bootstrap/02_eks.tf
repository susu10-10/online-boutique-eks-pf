module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.project_name
  kubernetes_version = "1.33"

  # Optional
  #endpoint_public_access = true

  # Optional: Adds the current caller identity (terraform) as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    boutique_infrastructure = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m7i-flex.large"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }

  tags = var.tags
}

# module "eks" {

#   addons = {
#     coredns = {}
#     aws-ebs-csi-driver = {
#       service_account_role_arn = module.ebs_csi_driver_irsa.arn
#     }
#     kube-proxy = {}
#     vpc-cni = {
#       before_compute = true
#     }
#   }

# }