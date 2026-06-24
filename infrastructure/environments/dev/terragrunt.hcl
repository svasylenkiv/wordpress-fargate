# Env-level конфіг для dev — наслідує root
locals {
  environment    = "dev"
  aws_region     = "eu-central-1"

  # Dev: мінімальні розміри для економії
  rds_instance_class = "db.t3.micro"
  rds_multi_az       = false
  ecs_cpu            = 512
  ecs_memory         = 1024
  ecs_min_capacity   = 1
  ecs_max_capacity   = 2
  nat_gateway_count  = 1    # один NAT для dev (prod — по одному на AZ)
}

inputs = {
  environment        = local.environment
  rds_instance_class = local.rds_instance_class
  rds_multi_az       = local.rds_multi_az
  ecs_cpu            = local.ecs_cpu
  ecs_memory         = local.ecs_memory
  ecs_min_capacity   = local.ecs_min_capacity
  ecs_max_capacity   = local.ecs_max_capacity
  nat_gateway_count  = local.nat_gateway_count
}