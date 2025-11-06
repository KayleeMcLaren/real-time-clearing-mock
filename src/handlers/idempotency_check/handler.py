# real-time-clearing-mock/src/handlers/idempotency_check/handler.py
import json
import time
from libs.db_client import DYNAMODB, IDEMPOTENCY_TABLE, IdempotencyKeyConflict

def handler(event, context):
    """
    Checks the idempotency table. If the key exists, it means the transaction
    is a duplicate. If not, it inserts the key and proceeds.
    """
    idempotency_key = event.get('transaction_id')
    
    if not idempotency_key:
        print("Error: Missing transaction_id in event.")
        raise ValueError("Missing 'transaction_id'")

    table = DYNAMODB.Table(IDEMPOTENCY_TABLE)
    
    # Calculate expiry time (e.g., 1 hour from now)
    expiry_time = int(time.time()) + 3600 

    try:
        # Attempt to insert the key only if it doesn't already exist.
        table.put_item(
            Item={
                'idempotency_key': idempotency_key,
                'status': 'IN_PROGRESS',
                'expiry_time': expiry_time
            },
            ConditionExpression='attribute_not_exists(idempotency_key)'
        )
        
        print(f"Idempotency key {idempotency_key} successfully reserved.")
        # Return the original event to the next state
        return event
        
    except DYNAMODB.meta.client.exceptions.ConditionalCheckFailedException:
        print(f"Idempotency key {idempotency_key} already exists. Duplicate transaction.")
        # Raise the specific error caught by the SFN Catch block
        raise IdempotencyKeyConflict("Duplicate transaction detected.")
    
    except Exception as e:
        # Re-raise any other critical error
        print(f"Error during idempotency check: {e}")
        raise