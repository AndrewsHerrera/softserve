locals {
  project_name = "softserve"
  env          = "prod"
}

module "networking" {
  source       = "./modules/networking"
  project_name = local.project_name
  env          = local.env
  allowed_ip   = var.allowed_ip
}

module "rds" {
  source                 = "./modules/rds"
  project_name           = local.project_name
  env                    = local.env
  vpc_id                 = module.networking.vpc_id
  private_rds_subnet_ids = module.networking.private_rds_subnet_ids
  rds_sg_id              = module.networking.rds_sg_id
}

module "alb" {
  source            = "./modules/alb"
  project_name      = local.project_name
  env               = local.env
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  alb_sg_id         = module.networking.alb_sg_id
  domain_name       = var.domain_name
  acm_arn           = var.acm_arn
}

module "asg" {
  source             = "./modules/asg"
  project_name       = local.project_name
  env                = local.env
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  ec2_sg_id          = module.networking.ec2_sg_id
  target_group_arn   = module.alb.target_group_arn
}