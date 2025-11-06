# real-time-clearing-mock/terraform/api_gateway.tf

# --- 1. SFN Starter Lambda ---
resource "aws_lambda_function" "start_clearing_saga" {
  function_name    = "StartClearingSagaLambda-${var.environment}"
  role             = aws_iam_role.clearing_lambda_role.arn # Reuse the existing IAM Role
  handler          = "handlers.start_clearing.handler.handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 128
  
  filename         = data.archive_file.clearing_lambdas_zip.output_path
  source_code_hash = data.archive_file.clearing_lambdas_zip.output_base64sha256

  environment {
    variables = {
      # Pass the SFN ARN to the Lambda environment
      CLEANING_SAGAS_SFN_ARN = aws_sfn_state_machine.clearing_saga.arn
    }
  }
}

# Add SFN permissions to the Lambda Role (only for the starter lambda)
resource "aws_iam_policy" "sfn_start_execution_policy" {
  name = "SFNStartExecutionPolicy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = "states:StartExecution",
        Resource = aws_sfn_state_machine.clearing_saga.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_start_execution_attach" {
  role       = aws_iam_role.clearing_lambda_role.name
  policy_arn = aws_iam_policy.sfn_start_execution_policy.arn
}

# --- 2. API Gateway (REST) ---

# Create the API Gateway itself
resource "aws_api_gateway_rest_api" "clearing_api" {
  name        = "ClearingAPI-${var.environment}"
  description = "API endpoint for real-time payment clearing initiation."
}

# Get the root resource (/)
data "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.clearing_api.id
  path        = "/"
}

# Create the /clear resource path
resource "aws_api_gateway_resource" "clear" {
  rest_api_id = aws_api_gateway_rest_api.clearing_api.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "clear"
}

# Define the POST method on /clear
resource "aws_api_gateway_method" "post_clear" {
  rest_api_id   = aws_api_gateway_rest_api.clearing_api.id
  resource_id   = aws_api_gateway_resource.clear.id
  http_method   = "POST"
  authorization = "NONE" # You would typically use Cognito here, but we simplify for mock testing
}

# Define the integration (Lambda call)
resource "aws_api_gateway_integration" "clear_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.clearing_api.id
  resource_id             = aws_api_gateway_resource.clear.id
  http_method             = aws_api_gateway_method.post_clear.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.start_clearing_saga.invoke_arn
}

# Grant API Gateway permission to invoke the Lambda
resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_clearing_saga.function_name
  principal     = "apigateway.amazonaws.com"

  # Source ARN ensures only this API Gateway can invoke the Lambda
  source_arn = "${aws_api_gateway_rest_api.clearing_api.execution_arn}/*/*"
}

# Deploy the API
resource "aws_api_gateway_deployment" "clearing_deployment" {
  depends_on = [
    aws_api_gateway_method.post_clear,
    aws_api_gateway_integration.clear_lambda_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.clearing_api.id
  stage_name  = var.environment
}