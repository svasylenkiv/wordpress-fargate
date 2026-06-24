# ─── Root Terragrunt конфіг ───────────────────────────────────────────────────
# Цей файл наслідують всі дочірні terragrunt.hcl через include "root"

locals {
  # Визначаємо environment з шляху: environments/dev → "dev"
  # path_relative_to_include() повертає відносний шлях від цього файлу
  path_parts  = split("/", path_relative_to_include())
  environment = try(local.path_parts[1], "unknown")

  # Проєктні константи
  project_name = "wordpress-fargate"
  aws_region   = "us-east-1"

  # Account ID береться з environment-specific конфігу
  aws_account_id = get_env("AWS_ACCOUNT_ID", "")

  # Спільні теги для всіх ресурсів
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Repository  = "github.com/YOUR_ORG/wordpress-fargate"
  }
}

# ─── Remote State Backend ─────────────────────────────────────────────────────
remote_state {
  backend = "s3"

  # Конфіг бекенду генерується динамічно для кожного модуля
  config = {
    bucket         = "${local.project_name}-tfstate-${local.aws_account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "${local.project_name}-tfstate-lock"

    # Retry для тимчасових AWS помилок
    skip_bucket_versioning         = true   # вже увімкнено через bootstrap
    skip_bucket_server_side_encryption = true  # вже увімкнено через bootstrap
  }

  # Генерувати backend.tf автоматично в кожній дочірній теці
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ─── Генерація provider.tf ────────────────────────────────────────────────────
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    terraform {
      required_version = ">= 1.7.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.40"
        }
      }
    }

    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = {
          Project     = "${local.common_tags.Project}"
          Environment = "${local.common_tags.Environment}"
          ManagedBy   = "${local.common_tags.ManagedBy}"
          Repository  = "${local.common_tags.Repository}"
        }
      }
    }
  EOF
}

# ─── Terraform версія ─────────────────────────────────────────────────────────
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()

    # Автоматично підставляти common.tfvars якщо існує
    optional_var_files = [
      "${get_terragrunt_dir()}/common.tfvars",
      "${get_parent_terragrunt_dir()}/common.tfvars"
    ]
  }

  # Retry для тимчасових AWS API помилок
  extra_arguments "retry_lock" {
    commands  = ["apply", "destroy", "plan"]
    arguments = ["-lock-timeout=10m"]
  }
}

# ─── Спільні inputs для всіх модулів ──────────────────────────────────────────
inputs = {
  project_name = local.project_name
  aws_region   = local.aws_region
  environment  = local.environment
  common_tags  = local.common_tags
}