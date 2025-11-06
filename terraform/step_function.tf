# Define the IAM Role for the Step Function
resource "aws_iam_role" "clearing_sf_role" {
  name = "ClearingSagaSFNRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "states.${var.aws_region}.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the required policy for SFN to call Lambdas, publish to SNS, and log to CloudWatch
resource "aws_iam_role_policy" "clearing_sf_policy" {
  name = "ClearingSagaSFNPolicy-${var.environment}"
  role = aws_iam_role.clearing_sf_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Lambda Invoke Permissions (Required for all Task states)
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          aws_lambda_function.idempotency_check.arn,
          aws_lambda_function.debit_wallet.arn,
          aws_lambda_function.credit_wallet.arn,
          aws_lambda_function.transfer_mock.arn
        ]
      },
      # 2. SNS Publish Permissions (Required for PublishSuccessEvent/PublishFailedEvent states)
      {
        Effect = "Allow",
        Action = "sns:Publish",
        Resource = var.integration_sns_topic_arn
      },
    ]
  })
}

# Data source to read the ASL definition file and substitute placeholders
data "local_file" "clearing_saga_asl" {
  filename = "${path.module}/../src/clearing_saga_asl.json"
}

# Define the Step Function State Machine
resource "aws_sfn_state_machine" "clearing_saga" {
  name     = "ClearingSagaSFN-${var.environment}"
  role_arn = aws_iam_role.clearing_sf_role.arn
  type     = "STANDARD" # Standard is great for sagas/auditing

  # CRITICAL DEPENDENCY: Ensure policy is attached before creating the SFN.
  depends_on = [
    aws_iam_role_policy.clearing_sf_policy,
  ]

  definition = templatefile("${path.module}/../src/clearing_saga_asl.json", {
    Idempotency_Check_Lambda_ARN = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:IdempotencyCheckLambda-${var.environment}",
    Debit_Wallet_Lambda_ARN      = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:DebitWalletLambda-${var.environment}",
    Transfer_Mock_Lambda_ARN     = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:TransferMockLambda-${var.environment}",
    Credit_Wallet_Lambda_ARN     = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:CreditWalletLambda-${var.environment}",
    SNS_Topic_ARN                = var.integration_sns_topic_arn
  })
}


# Add the SFN ARN to outputs
output "clearing_saga_sfn_arn" {
  description = "The ARN of the Clearing Saga Step Function"
  value       = aws_sfn_state_machine.clearing_saga.arn
}