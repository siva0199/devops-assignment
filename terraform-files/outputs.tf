output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
