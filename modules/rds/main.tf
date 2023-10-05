locals {
  resource_tags = {
    Name = var.project_name
    env  = var.env
  }
}

resource "aws_db_parameter_group" "parameter_group" {
  name   = "${var.project_name}-${var.env}"
  family = "postgres15"
  parameter {
    apply_method = "immediate"
    name         = "rds.force_ssl"
    value        = "1"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-${var.env}"
  subnet_ids = var.private_rds_subnet_ids
}

resource "aws_db_instance" "db" {
  identifier                          = "${var.project_name}-${var.env}"
  allocated_storage                   = 10
  storage_type                        = "gp2"
  engine                              = "postgres"
  engine_version                      = "15.2"
  instance_class                      = "db.t3.small"
  db_name                             = var.project_name
  username                            = var.project_name
  password                            = random_password.passwd.result
  parameter_group_name                = aws_db_parameter_group.parameter_group.id
  db_subnet_group_name                = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids              = [var.rds_sg_id]
  storage_encrypted                   = true
  skip_final_snapshot                 = true
  ca_cert_identifier                  = "rds-ca-ecc384-g1"
  multi_az                            = true
  backup_retention_period             = 35
  iam_database_authentication_enabled = true
  tags                                = local.resource_tags
}

resource "random_password" "passwd" {
  special = false
  length  = 30
}

resource "aws_secretsmanager_secret" "secrets" {
  name = "${var.project_name}-${var.env}"
  tags = local.resource_tags
}

resource "aws_secretsmanager_secret_version" "passwd" {
  secret_id = aws_secretsmanager_secret.secrets.id
  secret_string = jsonencode({
    RDS_PASSWORD = random_password.passwd.result
  })
}
