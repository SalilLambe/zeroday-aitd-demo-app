terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use default VPC & subnets so this deploys cleanly in any AWS sandbox
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI (includes AWS CLI v2 and SSM Agent by default)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Security Group exposing port 8080 (no SSH port 22 needed; we use SSM)
resource "aws_security_group" "demo_app" {
  name        = "zeroday-aitd-demo-app-sg"
  description = "Allow HTTP 8080 to Zero-Day AITD Demo App"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Demo App HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Allow all outbound for SSM, Docker build, and Wiz Sensor"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "zeroday-aitd-demo-app-sg"
    Project     = "Zero-Day-AITD-Showcase"
    Owner       = var.owner_tag
    Environment = "sandbox"
  }
}

# IAM Role for EC2 with SSM enabled
resource "aws_iam_role" "demo_ec2_role" {
  name = "zeroday-aitd-demo-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "Zero-Day-AITD-Showcase"
    Owner   = var.owner_tag
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.demo_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "demo_ec2_profile" {
  name = "zeroday-aitd-demo-ec2-profile"
  role = aws_iam_role.demo_ec2_role.name
}

# Target EC2 instance
resource "aws_instance" "demo_app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.demo_app.id]
  iam_instance_profile        = aws_iam_instance_profile.demo_ec2_profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh", {
    github_repo_url = var.github_repo_url
  })

  # IMDSv2 enforced; change http_tokens to "optional" only if you want to demo IMDSv1 attack path
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "zeroday-aitd-demo-app"
    Project     = "Zero-Day-AITD-Showcase"
    Owner       = var.owner_tag
    Environment = "sandbox"
  }
}

# ECS Cluster for Component 2 (Wiz Outpost Lite R&R on ECS)
resource "aws_ecs_cluster" "wiz_outpost_lite" {
  name = "wiz-rr-outpost-ecs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name    = "wiz-rr-outpost-ecs"
    Project = "Zero-Day-AITD-Showcase"
    Owner   = var.owner_tag
  }
}

resource "aws_ecs_cluster_capacity_providers" "wiz_outpost_lite" {
  cluster_name       = aws_ecs_cluster.wiz_outpost_lite.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}