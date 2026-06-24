include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl", "environments/prod/terragrunt.hcl")
}

terraform {
  source = "../../../modules//vpc"
}

inputs = {
  vpc_cidr            = "10.1.0.0/16"
  availability_zones  = ["eu-central-1a", "eu-central-1b"]
  public_subnets      = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets     = ["10.1.10.0/24", "10.1.11.0/24"]
  database_subnets    = ["10.1.20.0/24", "10.1.21.0/24"]
}