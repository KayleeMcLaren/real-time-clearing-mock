# real-time-clearing-mock/src/libs/db_client.py
import os
import boto3
from decimal import Decimal
import json

# Use the environment variables set by Terraform
WALLETS_TABLE = os.environ.get("WALLETS_TABLE_NAME")
IDEMPOTENCY_TABLE = os.environ.get("IDEMPOTENCY_TABLE_NAME")

# Initialize DynamoDB client and table resources
DYNAMODB = boto3.resource('dynamodb')

def serialize_decimal(obj):
    """Helper function to serialize Decimal objects for JSON logging."""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError ("Type %s not serializable" % type(obj))

def transact_write_items(transaction_items: list):
    """
    Executes a list of TransactWriteItems operations.
    Raises an exception on failure, ensuring atomicity.
    """
    # Use the low-level client for the transaction API
    client = boto3.client('dynamodb') 
    
    try:
        client.transact_write_items(
            TransactItems=transaction_items
        )
        # Log success (optional, but good practice)
        print(f"Transaction successful: {len(transaction_items)} operations.")
    except client.exceptions.TransactionCanceledException as e:
        # This occurs if a condition check fails (e.g., Insufficient funds)
        print(f"Transaction Canceled: {e}")
        # Re-raise with a specific error type the Step Function can catch
        raise ConditionalCheckFailedError("DynamoDB condition check failed, possibly insufficient funds.") from e
    except Exception as e:
        print(f"Unexpected Transaction Error: {e}")
        # Re-raise a generic error
        raise InternalError(f"Internal DynamoDB error: {e}") from e

class ConditionalCheckFailedError(Exception):
    """Custom error for SFN Catch block (e.g., Insufficient Funds)."""
    pass

class InternalError(Exception):
    """Custom error for SFN Retry block (e.g., temporary internal failure)."""
    pass

class IdempotencyKeyConflict(Exception):
    """Custom error for SFN Idempotency Check (Duplicate Transaction)."""
    pass