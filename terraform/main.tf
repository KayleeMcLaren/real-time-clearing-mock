# --- SNS TOPIC (For events originating from this service) ---
resource "aws_sns_topic" "clearing_events" {
  name = "ClearingEvents-${var.environment}"
  # Optional: Enable KMS encryption for the topic
  # kms_master_key_id = "alias/aws/sns"
}


# --- DYNAMODB TABLES (Core Ledger) ---

# 1. Wallets Table: Stores user balances
resource "aws_dynamodb_table" "wallets" {
  name             = "wallets-${var.environment}"
  # PAY_PER_REQUEST is the best option for Free Tier cost control
  billing_mode     = "PAY_PER_REQUEST" 
  hash_key         = "PK"
  range_key        = "SK"
  
  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  tags = {
    Name = "wallets-${var.environment}"
  }
}

# 2. Idempotency Table: Used for fast checks to prevent duplicate payments
resource "aws_dynamodb_table" "idempotency" {
  name             = "idempotency-${var.environment}"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "idempotency_key"
  
  attribute {
    name = "idempotency_key"
    type = "S"
  }
  
  # TTL is crucial here: automatically expire old transaction IDs to save cost.
  ttl {
    attribute_name = "expiry_time"
    enabled        = true
  }

  tags = {
    Name = "idempotency-${var.environment}"
  }
}


# --- SQS QUEUES (Audit & Resilience) ---

# 3a. Dead Letter Queue (DLQ) for Audit: For messages that fail processing
resource "aws_sqs_queue" "audit_dlq" {
  name                      = "audit-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 days
  tags = {
    Name = "audit-dlq-${var.environment}"
  }
}

# 3b. Main Audit Queue: Receives all transaction logs before batching to S3
resource "aws_sqs_queue" "audit_queue" {
  name                      = "audit-queue-${var.environment}"
  message_retention_seconds = 259200 # 3 days

  # Redrive policy links the main queue to the DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.audit_dlq.arn
    maxReceiveCount     = 3 # A message is moved to the DLQ after 3 failed receive attempts
  })
  
  tags = {
    Name = "audit-queue-${var.environment}"
  }
}