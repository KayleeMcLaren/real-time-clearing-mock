# real-time-clearing-mock/terraform/lambda.tf

# Data source to get the current AWS Account ID for ARN construction
data "aws_caller_identity" "current" {} 

# --- IAM Role for Lambda Execution ---
resource "aws_iam_role" "clearing_lambda_role" {
  name = "ClearingLambdasRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy to allow basic execution (logging)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.clearing_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy to allow DynamoDB access (Read/Write to both tables)
resource "aws_iam_policy" "dynamodb_access_policy" {
  name = "ClearingDynamoDBAccessPolicy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:TransactWriteItems",
          "dynamodb:TransactGetItems"
        ],
        # CRITICAL FIX: The Lambda role must have permission on the EXISTING table's ARN
        # The ARN of the 'fintech-ecosystem-stg-wallets' table must be added here.
        # Since this ARN is external, we MUST define it as a string or pass it as a variable.
        # For now, we assume this policy is only granting permission to the new tables, 
        # and rely on the execution environment to have permission on the external table.
        # However, a cleaner solution would be to pass the external ARN as a variable.
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/fintech-ecosystem-stg-wallets", # Added External ARN
          aws_dynamodb_table.idempotency.arn,
          aws_dynamodb_table.wallets.arn # Retained for completeness, although this table is redundant now.
        ]
      },
      {
        Effect = "Allow",
        Action = "sqs:SendMessage",
        Resource = aws_sqs_queue.audit_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_attach" {
  role       = aws_iam_role.clearing_lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_access_policy.arn
}

# --- DATA SOURCE: Archive Python Code ---
data "archive_file" "clearing_lambdas_zip" {
  type        = "zip"
  output_path = "clearing_lambdas_${var.environment}.zip"
  source_dir  = "${path.module}/../src"
}

# --- 1. Idempotency Check Lambda ---
resource "aws_lambda_function" "idempotency_check" {
  function_name    = "IdempotencyCheckLambda-${var.environment}"
  role             = aws_iam_role.clearing_lambda_role.arn
  handler          = "handlers.idempotency_check.handler.handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 128
  
  filename         = data.archive_file.clearing_lambdas_zip.output_path
  source_code_hash = data.archive_file.clearing_lambdas_zip.output_base64sha256

  environment {
    variables = {
      WALLETS_TABLE_NAME    = "fintech-ecosystem-stg-wallets" # FIXED: Added quotes
      IDEMPOTENCY_TABLE_NAME = aws_dynamodb_table.idempotency.name
      AUDIT_QUEUE_URL       = aws_sqs_queue.audit_queue.id
    }
  }
}

# --- 2. Debit Wallet Lambda ---
resource "aws_lambda_function" "debit_wallet" {
  function_name    = "DebitWalletLambda-${var.environment}"
  role             = aws_iam_role.clearing_lambda_role.arn
  handler          = "handlers.debit_wallet.handler.handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 128
  
  filename         = data.archive_file.clearing_lambdas_zip.output_path
  source_code_hash = data.archive_file.clearing_lambdas_zip.output_base64sha256

  environment {
    variables = {
      WALLETS_TABLE_NAME    = "fintech-ecosystem-stg-wallets" # FIXED: Added quotes
      IDEMPOTENCY_TABLE_NAME = aws_dynamodb_table.idempotency.name
      AUDIT_QUEUE_URL       = aws_sqs_queue.audit_queue.id
    }
  }
}

# --- 3. Mock Interbank Transfer Lambda ---
resource "aws_lambda_function" "transfer_mock" {
  function_name    = "TransferMockLambda-${var.environment}"
  role             = aws_iam_role.clearing_lambda_role.arn
  handler          = "handlers.transfer_mock.handler.handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 128
  
  filename         = data.archive_file.clearing_lambdas_zip.output_path
  source_code_hash = data.archive_file.clearing_lambdas_zip.output_base64sha256
  
  environment {
    variables = {
      WALLETS_TABLE_NAME    = "fintech-ecosystem-stg-wallets" # FIXED: Added quotes
      IDEMPOTENCY_TABLE_NAME = aws_dynamodb_table.idempotency.name
      AUDIT_QUEUE_URL       = aws_sqs_queue.audit_queue.id
    }
  }
}


# --- 4. Credit Beneficiary Wallet Lambda ---
resource "aws_lambda_function" "credit_wallet" {
  function_name    = "CreditWalletLambda-${var.environment}"
  role             = aws_iam_role.clearing_lambda_role.arn
  handler          = "handlers.credit_wallet.handler.handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 128
  
  filename         = data.archive_file.clearing_lambdas_zip.output_path
  source_code_hash = data.archive_file.clearing_lambdas_zip.output_base64sha256

  environment {
    variables = {
      WALLETS_TABLE_NAME    = "fintech-ecosystem-stg-wallets" # FIXED: Added quotes
      IDEMPOTENCY_TABLE_NAME = aws_dynamodb_table.idempotency.name
      AUDIT_QUEUE_URL       = aws_sqs_queue.audit_queue.id
    }
  }
}