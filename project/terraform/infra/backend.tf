# AWS provider configuration
provider "aws" {
  region = "us-east-1"
}
# Terraform backend configuration
terraform {
    backend "s3" {
        bucket = "htw-aws-terraform-state-2025"
        key    = "terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "terraform-state-lock"
}
}