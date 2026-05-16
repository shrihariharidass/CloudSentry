variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "858688858026"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cloudcustodian-ui"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = "AWS-New"
}

variable "vpc_id" {
  description = "VPC ID for the dashboard EC2"
  type        = string
  default     = "vpc-0f163aeb33940bbe4"
}

variable "subnet_id" {
  description = "Subnet ID for the dashboard EC2"
  type        = string
  default     = "subnet-09bbba0757a5f9929"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (your IP + GitHub Actions)"
  type        = list(string)
  default = [
    "0.0.0.0/0" # Restrict this to your IP in production
  ]
}
