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

data "aws_availability_zones" "available" {
  state = "available"
}

# Self-contained VPC + 2 Public Subnets (works in any region/sandbox + ready for ECS Outpost Lite)
resource "aws_vpc" "demo" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "zeroday-aitd-demo-vpc"
    Project     = "Zero-Day-AITD-Showcase"
    Owner       = var.owner_tag
    Environment = "sandbox"
  }
}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name    = "zeroday-aitd-demo-igw"
    Project = "Zero-Day-AITD-Showcase"
    Owner   = var.owner_tag
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.demo.id
  cidr_block              = cidrsubnet(aws_vpc.demo.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "zeroday-aitd-demo-public-${count.index + 1}"
    Project     = "Zero-Day-AITD-Showcase"
    Owner       = var.owner_tag
    Environment = "sandbox"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = {
    Name    = "zeroday-aitd-demo-public-rt"
    Project = "Zero-Day-AITD-Showcase"
    Owner   = var.owner_tag
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
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
  vpc_id      = aws_vpc.demo.id

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
  subnet_id                   = aws_subnet.public[0].id
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