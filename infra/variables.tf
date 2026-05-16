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
