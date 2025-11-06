# Define the environment variable to tag and namespace resources
variable "environment" {
  description = "The deployment environment (e.g., stg, prd)"
  type        = string
}

# Define the AWS region
variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1" # Recommended for lower cost or specific SA/EU region
}

# New variable for integration
variable "integration_sns_topic_arn" {
  description = "The ARN of the external SNS topic (from the main ecosystem) to publish settlement results to."
  type        = string
}