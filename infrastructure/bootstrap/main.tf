terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Bootstrap не має remote backend — state зберігається локально.
  # Закомітимо bootstrap.tfstate в .gitignore (він не містить секретів,
  # але краще тримати локально або в захищеному місці).
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Component   = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── S3 Bucket для Terraform State ───────────────────────────────────────────

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Захист від випадкового видалення через terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      # Використовуємо aws/s3 managed key — достатньо для state files
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    # Зберігати тільки останні 30 нежиттєвих версій state файлів
    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 30
    }

    # Прибирати незавершені multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Object Lock вимкнено: sandbox SCP блокує s3:PutBucketObjectLockConfiguration.
# Для prod достатньо versioning + lifecycle вище.

# ─── DynamoDB для State Locking ───────────────────────────────────────────────

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${var.project_name}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"   # нема сенсу платити за provisioned для lock table
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Point-in-time recovery — захист від випадкового видалення даних
  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ─── IAM OIDC Provider для GitHub Actions ────────────────────────────────────
# Дозволяє GitHub Actions отримувати тимчасові AWS credentials без статичних ключів

data "aws_iam_openid_connect_provider" "github" {
  count = 0   # Спробуємо спочатку перевірити чи вже існує
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint GitHub OIDC endpoint (актуальний станом на 2024)
  # Перевірити поточний: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# ─── IAM Role для GitHub Actions (Terraform deploys) ─────────────────────────

resource "aws_iam_role" "github_actions_terraform" {
  name        = "${var.project_name}-github-actions-terraform"
  description = "Role assumed by GitHub Actions for Terraform operations"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Дозволяємо тільки наш репозиторій, будь-яку гілку/environment
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  max_session_duration = 3600   # 1 година — достатньо для terraform apply
}

# Прикріпити AdministratorAccess для Terraform (потрібен для створення будь-яких ресурсів)
# У майбутньому можна звузити до конкретних сервісів.
resource "aws_iam_role_policy_attachment" "github_actions_terraform_admin" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ─── IAM Role для GitHub Actions (ECS deploys — менше прав) ──────────────────

resource "aws_iam_role" "github_actions_deploy" {
  name        = "${var.project_name}-github-actions-deploy"
  description = "Role assumed by GitHub Actions for ECS/CodeDeploy operations only"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # Deploy role — тільки з main гілки
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  max_session_duration = 3600
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "deploy-policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR — push images
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      # ECS — оновлення сервісів
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:DescribeClusters"
        ]
        Resource = "*"
      },
      # CodeDeploy — Blue/Green deployments
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision",
          "codedeploy:ListDeployments",
          "codedeploy:StopDeployment"
        ]
        Resource = "*"
      },
      # ALB — canary weight updates
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      },
      # CloudWatch — читати метрики для canary rollout рішень
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      # IAM PassRole — для ECS task definitions
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-ecs-task-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-ecs-exec-role"
        ]
      }
    ]
  })
}