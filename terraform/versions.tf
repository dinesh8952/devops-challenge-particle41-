terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend — run scripts/setup-backend.sh first to create
  # the S3 bucket and DynamoDB table, then replace BUCKET_NAME below.
  backend "s3" {
    bucket         = "simpletimeservice-tfstate-785186659004"
    key            = "devops-challenge/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-challenge"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
