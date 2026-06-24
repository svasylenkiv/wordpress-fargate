include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("terragrunt.hcl", "environments/dev/terragrunt.hcl")
}

terraform {
  source = "../../../modules//vpc"
}

inputs = {
  # Специфічні inputs для vpc — додамо в День 3
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["eu-central-1a", "eu-central-1b"]
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets     = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnets    = ["10.0.20.0/24", "10.0.21.0/24"]
}