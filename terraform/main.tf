locals {
  # All resources named: {project}-{env}-{resource}  e.g. simpletimeservice-dev-vpc
  name_prefix = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "alb" {
  source = "./modules/alb"

  name_prefix         = local.name_prefix
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  container_port      = var.container_port
  acm_certificate_arn = var.acm_certificate_arn
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix                 = local.name_prefix
  environment                 = var.environment
  aws_region                  = var.aws_region
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  alb_security_group_id       = module.alb.alb_security_group_id
  target_group_arn            = module.alb.target_group_arn
  alb_arn_suffix              = module.alb.alb_arn_suffix
  alb_target_group_arn_suffix = module.alb.alb_target_group_arn_suffix
  container_image             = var.container_image
  container_port              = var.container_port
  task_cpu                    = var.task_cpu
  task_memory                 = var.task_memory
  desired_count               = var.desired_count
}
