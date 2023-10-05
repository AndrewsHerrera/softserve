output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private.*.id
}

output "private_rds_subnet_ids" {
  value = aws_subnet.rds_private.*.id
}

output "public_subnet_ids" {
  value = aws_subnet.public.*.id
}

output "ec2_sg_id" {
  value = aws_security_group.ec2.id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}