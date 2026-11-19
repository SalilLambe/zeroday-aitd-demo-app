output "ec2_instance_id" {
  description = "Target EC2 Instance ID (needed for SSM & R&R testing)"
  value       = aws_instance.demo_app.id
}

output "ec2_public_ip" {
  description = "Target EC2 Public IP"
  value       = aws_instance.demo_app.public_ip
}

output "app_url" {
  description = "Demo App Health Check URL"
  value       = "http://${aws_instance.demo_app.public_ip}:8080/health"
}

output "security_group_id" {
  description = "Security Group ID attached to the demo EC2"
  value       = aws_security_group.demo_app.id
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name for Wiz Outpost Lite R&R (Component 2)"
  value       = aws_ecs_cluster.wiz_outpost_lite.name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN for Wiz Outpost Lite R&R (Component 2)"
  value       = aws_ecs_cluster.wiz_outpost_lite.arn
}

output "default_vpc_id" {
  description = "Default VPC ID"
  value       = data.aws_vpc.default.id
}

output "default_subnet_ids" {
  description = "Default Subnet IDs"
  value       = data.aws_subnets.default.ids
}