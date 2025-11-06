# real-time-clearing-mock/terraform/provider.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a stable, recent version
    }
  }
}

provider "aws" {
  # Use the region defined in variables.tf and stg.tfvars (us-east-1)
  region = var.aws_region
  
  # Assumes you have run 'aws configure' locally to authenticate
}

# Optional: Add a backend for remote state storage (Highly recommended for production, 
# but for a quick dev start, local state is okay. I recommend using S3 eventually!)
# backend "s3" {
#   bucket = "your-tf-state-bucket-name"
#   key    = "real-time-clearing-mock/terraform.tfstate"
#   region = "us-east-1" 
#   encrypt = true
# }