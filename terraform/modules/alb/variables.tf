variable "name_prefix" {
  description = "Prefix for all resource names e.g. simpletimeservice-dev"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS. Leave empty to use HTTP only."
  type        = string
  default     = ""
}
