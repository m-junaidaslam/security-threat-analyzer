variable "aws_region" {
  type        = string
  description = "AWS region for the deployment."
  default     = "eu-central-1"
}

variable "project" {
  type        = string
  description = "Project name used in resource names."
  default     = "threat-analyzer"
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
  default     = "dev"
}