variable "aws_region" {
  description = "AWS region for the sandbox showcase"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type for the demo app"
  type        = string
  default     = "t3.small"
}

variable "allowed_cidr" {
  description = "CIDR allowed to reach port 8080 (keep 0.0.0.0/0 for Wiz External Exposure / Red Agent demos, or restrict if your sandbox SCP requires it)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "owner_tag" {
  description = "Owner tag for Wiz ownership attribution"
  type        = string
  default     = "salilslambe@wiz.io"
}

variable "github_repo_url" {
  description = "GitHub repo cloned on EC2 boot to build the demo container"
  type        = string
  default     = "https://github.com/SalilLambe/zeroday-aitd-demo-app.git"
}