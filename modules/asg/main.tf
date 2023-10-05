locals {
  resource_tags = {
    Name = var.project_name
    env  = var.env
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_key_pair" "key" {
  key_name   = "${var.project_name}-${var.env}"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_launch_template" "main" {
  name = "${var.project_name}-${var.env}"
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 8
      encrypted   = true
    }
  }
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = 20
      encrypted   = true
    }
  }
  disable_api_stop        = true
  disable_api_termination = true
  image_id                = data.aws_ami.ubuntu.id
  instance_type           = "t3.small"
  key_name                = "${var.project_name}-${var.env}"
  vpc_security_group_ids  = [var.ec2_sg_id]
  tag_specifications {
    resource_type = "instance"
    tags          = local.resource_tags
  }
  user_data = filebase64("${path.module}/nginx.sh")
  metadata_options {
    http_tokens = "required"
  }
  depends_on = [aws_key_pair.key]
  tags       = local.resource_tags
}

resource "aws_autoscaling_group" "asg" {
  name                      = "${var.project_name}-${var.env}-asg"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  vpc_zone_identifier       = var.private_subnet_ids
  launch_template {
    id      = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }
}

resource "aws_autoscaling_attachment" "attachment" {
  autoscaling_group_name = aws_autoscaling_group.asg.id
  lb_target_group_arn    = var.target_group_arn
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-${var.env}-cpu-up"
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  scaling_adjustment     = 1
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name          = "${var.project_name}-${var.env}-cpu-up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  threshold           = 65
  period              = 60
  statistic           = "Average"
  namespace           = "AWS/EC2"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-${var.env}-cpu-down"
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  scaling_adjustment     = -1
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_down_alarm" {
  alarm_name          = "cpu_down_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  threshold           = 40
  period              = 60
  statistic           = "Average"
  namespace           = "AWS/EC2"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}
