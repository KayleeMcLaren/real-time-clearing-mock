# real-time-clearing-mock/src/handlers/start_clearing/handler.py
import os
import json
import boto3
import uuid

# Environment variables set by Terraform
SFN_ARN = os.environ.get("CLEANING_SAGAS_SFN_ARN")

# Initialize AWS clients
SFN_CLIENT = boto3.client('stepfunctions')

def handler(event, context):
    """
    Receives payment request via API Gateway, validates the payload, 
    and starts the Step Function execution.
    """
    try:
        # API Gateway passes the body as a string, so we must parse it
        body = json.loads(event.get('body', '{}'))
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }

    # --- 1. Input Validation (Basic) ---
    required_fields = ['payer_id', 'beneficiary_id', 'amount']
    if not all(field in body for field in required_fields):
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f"Missing fields: {', '.join(required_fields)}"})
        }

    # Create a unique transaction ID if not provided (best practice for idempotency)
    transaction_id = body.get('transaction_id', str(uuid.uuid4()))
    
    # Prepare the input payload for the Step Function
    sfn_input = {
        'transaction_id': transaction_id,
        'payer_id': body['payer_id'],
        'beneficiary_id': body['beneficiary_id'],
        # Amounts should be passed as strings to maintain precision (Python Decimal objects)
        'amount': str(body['amount']) 
    }

    # --- 2. Start Step Function Execution ---
    try:
        response = SFN_CLIENT.start_execution(
            stateMachineArn=SFN_ARN,
            # Use the transaction_id for the execution name for easy tracing
            name=f"{transaction_id}", 
            input=json.dumps(sfn_input)
        )
        
        print(f"SFN Execution started: {response['executionArn']}")

        # --- 3. Return 202 Accepted (Asynchronous) ---
        return {
            'statusCode': 202, # 202 Accepted: Processing started, result pending via event bus
            'body': json.dumps({
                'message': 'Clearing saga initiated successfully.',
                'transaction_id': transaction_id,
                'execution_arn': response['executionArn']
            })
        }
        
    except Exception as e:
        print(f"Error starting Step Function: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to start clearing workflow.'})
        }