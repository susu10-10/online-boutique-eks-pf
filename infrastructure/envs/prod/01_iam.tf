module "iam_github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.0"
}

# App Repo Policy to push images to ECR
resource "aws_iam_policy" "app_repo_policy" {
  name = "${var.project_name}-app-repo-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetRepositoryPolicy",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:ListImages",
          "ecr:ListTagsForResource"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/online-boutique/*"
      }
    ]
  })
}

# App Repo Role (Gh Action Runner) with trust relationship

module "iam_github_oidc_role_app_repo" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "${var.project_name}-github-deploy-app-repo"

  subjects = ["repo:susu10-10@75139663/online-boutique-app@1315018332:ref:refs/heads/main"]

  policies = {
    EcrDeployPolicy = aws_iam_policy.app_repo_policy.arn
  }

}


# Platform Repo Policy For EKS
resource "aws_iam_policy" "platform_repo_policy" {
  name        = "${var.project_name}-platform-repo-policy"
  description = "Permission for the platform repo to build VPC, EKS and IAM Infra"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 1. Edge & Identity (API GW, Cognito, ACM, Route53)
        Effect = "Allow"
        Action = [
          "apigateway:*",
          "cognito-idp:*",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:ListTagsForCertificate",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = [
          "arn:aws:apigateway:us-east-1::/*",
          "arn:aws:cognito-idp:us-east-1:767397659229:userpool/*",
          "arn:aws:acm:us-east-1:767397659229:certificate/*",
          "arn:aws:route53:::hostedzone/*",
          "arn:aws:route53:::change/*"
        ]
      },
      {
        # 2. Compute, Network & Routing (EKS, EC2, ELB, Servicediscovery, Autoscaling)
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "servicediscovery:*",
          "autoscaling:*"
        ]
        Resource = "*"
      },
      {
        # 3. Serverless Bridge & Cryptographic Vault (SQS, SNS, Lambda, SSM, ECR)
        Effect = "Allow"
        Action = [
          "sqs:*",
          "sns:*",
          "lambda:*",
          "ssm:*",
          "ecr:*"
        ]
        Resource = [
          "arn:aws:sqs:us-east-1:767397659229:*",
          "arn:aws:sns:us-east-1:767397659229:*",
          "arn:aws:lambda:us-east-1:767397659229:function:*",
          "arn:aws:lambda:us-east-1:767397659229:event-source-mapping:*",
          "arn:aws:ssm:us-east-1:767397659229:parameter/online-boutique/*",
          "arn:aws:ecr:us-east-1:767397659229:repository/*"
        ]
      },
      {
        # 4. Observability (CloudWatch Logs)
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy"
        ]
        Resource = "arn:aws:logs:us-east-1:767397659229:log-group:*"
      },
      {
        # 5. IAM for EKS IRSA and Node Roles
        Effect = "Allow"
        Action = [
          "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy",
          "iam:DetachRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:PassRole", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:CreatePolicy",
          "iam:DeletePolicy", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions", "iam:GetOpenIDConnectProvider", "iam:TagRole",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile", "iam:GetInstanceProfile"
        ]
        Resource = [
          "arn:aws:iam::767397659229:role/*",
          "arn:aws:iam::767397659229:policy/*",
          "arn:aws:iam::767397659229:instance-profile/*",
          "arn:aws:iam::767397659229:oidc-provider/token.actions.githubusercontent.com",
          "arn:aws:iam::767397659229:oidc-provider/oidc.eks.*"
        ]
      },
      {
        # 6. Terraform State Management
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:s3:::online-boutique-tfstate-767397659229",
          "arn:aws:s3:::online-boutique-tfstate-767397659229/*"
        ]
      },
      {
        # 7. Terraform Metadata & Auditing Exception (AWS APIs that require wildcard resources)
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters",
          "cognito-idp:DescribeUserPoolDomain",
          "route53:ListTagsForResource",
          "logs:ListTagsForResource",
          "lambda:GetEventSourceMapping",
          "lambda:ListEventSourceMappings"
        ]
        Resource = "*"
      },
      {
        # KMS & Metadata (Required for EKS secrets encryption)
        Effect = "Allow"
        Action = [
          "kms:CreateGrant", "kms:DescribeKey", "kms:GenerateDataKey",
          "kms:Decrypt", "iam:ListRoles", "ec2:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

# GH Runner Platform Repo Role

module "iam_github_oidc_role_platform_repo" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "${var.project_name}-github-deploy-platform-repo"

  subjects = ["repo:susu10-10@75139663/online-boutique-eks-pf@1346081594:ref:refs/heads/main"]

  policies = {
    PlatformDeployPolicy = aws_iam_policy.platform_repo_policy.arn
  }

}
