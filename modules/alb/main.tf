locals {
  resource_tags = {
    Name = var.project_name
    env  = var.env
  }
}

resource "aws_lb" "alb" {
  name                       = "${var.project_name}-${var.env}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  tags                       = local.resource_tags
}

resource "aws_lb_target_group" "https" {
  name     = "${var.project_name}-${var.env}-https"
  protocol = "HTTPS"
  port     = 443
  vpc_id   = var.vpc_id
  health_check {
    path    = "/"
    matcher = "200,400"
  }
  tags = local.resource_tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_arn
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
  condition {
    host_header {
      values = [var.domain_name]
    }
  }
}


data "aws_route53_zone" "hosted_zone" {
  name = "${var.domain_name}."
}

resource "aws_route53_record" "alb_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}