variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  # Set this in terraform.tfvars or via -var flag
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cloudsentry"
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  # Set this in terraform.tfvars
}

variable "vpc_id" {
  description = "VPC ID for the dashboard EC2 instance"
  type        = string
  # Set this in terraform.tfvars
}

variable "subnet_id" {
  description = "Subnet ID for the dashboard EC2 instance (must be in the VPC above)"
  type        = string
  # Set this in terraform.tfvars
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the dashboard EC2"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict to your IP in production
}
