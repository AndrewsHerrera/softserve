locals {
  resource_tags = {
    Name = var.project_name
    env  = var.env
  }
  vpc_cidr            = "10.0.0.0/16"
  private_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_rds_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  public_subnets      = ["10.0.5.0/24", "10.0.6.0/24"]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block       = local.vpc_cidr
  instance_tenancy = "default"
  tags             = local.resource_tags
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-private"
  }
}

resource "aws_subnet" "rds_private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_rds_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-rds-private"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = local.resource_tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(local.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "ip" {
  count  = 2
  domain = "vpc"
  tags   = local.resource_tags
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.ip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = local.resource_tags
  depends_on    = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = {
    Name = "${var.project_name}-private"
  }
}

resource "aws_route_table" "rds_private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = {
    Name = "${var.project_name}-rds-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "rds_private" {
  count          = 2
  subnet_id      = aws_subnet.rds_private[count.index].id
  route_table_id = aws_route_table.rds_private[count.index].id
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.env}-ec2"
  description = "${var.project_name}-${var.env}-ec2"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = local.resource_tags
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.env}-alb"
  description = "${var.project_name}-${var.env}-alb"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = local.resource_tags
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.env}-rds"
  description = "${var.project_name}-${var.env}-rds"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.ec2.id]
  }
  tags = {
    Name = "${var.project_name}-rds-private"
  }
}

resource "aws_flow_log" "flow" {
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  tags            = local.resource_tags
}

resource "aws_cloudwatch_log_group" "flow" {
  name = "${var.project_name}-vpc-flow"
}

data "aws_iam_policy_document" "flow_doc" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flow" {
  name               = "${var.project_name}-vpc-flow"
  assume_role_policy = data.aws_iam_policy_document.flow_doc.json
}

data "aws_iam_policy_document" "flow" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = [aws_cloudwatch_log_group.flow.arn]
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "${var.project_name}-vpc-flow"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow.json
}
