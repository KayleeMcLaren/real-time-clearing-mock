output "wallets_table_name" {
  description = "The name of the DynamoDB Wallets table"
  value = aws_dynamodb_table.wallets.name
}

output "idempotency_table_name" {
  description = "The name of the DynamoDB Idempotency table"
  value = aws_dynamodb_table.idempotency.name
}

output "audit_queue_arn" {
  description = "The ARN of the SQS Audit Queue"
  value = aws_sqs_queue.audit_queue.arn
}

output "audit_queue_url" {
  description = "The URL of the SQS Audit Queue"
  value = aws_sqs_queue.audit_queue.id
}

output "clearing_sns_topic_arn" {
  description = "The ARN of the Clearing Events SNS Topic"
  value = aws_sns_topic.clearing_events.arn
}

output "idempotency_check_lambda_arn" {
  description = "ARN of the Lambda that checks for duplicate transactions in SFN." # Added description
  value = aws_lambda_function.idempotency_check.arn
}

output "debit_wallet_lambda_arn" {
  description = "ARN of the Lambda that atomically debits the payer's wallet." # Added description
  value = aws_lambda_function.debit_wallet.arn
}

output "transfer_mock_lambda_arn" {
  description = "ARN of the Lambda that mocks interbank latency and failure." # Added description
  value = aws_lambda_function.transfer_mock.arn
}

output "credit_wallet_lambda_arn" {
  description = "ARN of the Lambda that atomically credits the beneficiary's wallet." # Added description
  value = aws_lambda_function.credit_wallet.arn
}

output "api_gateway_endpoint_url" {
  description = "The base URL for the Clearing API endpoint."
  value = aws_api_gateway_deployment.clearing_deployment.invoke_url
}