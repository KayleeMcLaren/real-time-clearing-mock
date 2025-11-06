# real-time-clearing-mock/src/handlers/debit_wallet/handler.py
import json
from decimal import Decimal
from libs.db_client import WALLETS_TABLE, transact_write_items, ConditionalCheckFailedError

def handler(event, context):
    """
    Atomically debits the payer's wallet using TransactWriteItems.
    """
    payer_id = event.get('payer_id')
    amount = Decimal(str(event.get('amount', 0)))

    if amount <= 0:
        raise ValueError("Invalid debit amount.")

    # Transaction Item: Update Payer's Balance
    debit_item = {
        'Update': {
            'TableName': WALLETS_TABLE,
            'Key': {'PK': payer_id, 'SK': 'WALLET'}, # Assuming a single-table design PK/SK structure
            'UpdateExpression': 'SET #b = #b - :amt',
            'ExpressionAttributeNames': {'#b': 'balance'},
            'ExpressionAttributeValues': {
                # Ensure the balance is sufficient (Conditional Check)
                ':amt': amount, 
                ':zero': Decimal(0)
            },
            # This is the conditional check for Insufficient Funds
            'ConditionExpression': '#b >= :amt'
        }
    }

    try:
        transact_write_items([debit_item])
        print(f"Successfully debited {amount} from Payer {payer_id}")
        
        # Return the event to the next state
        return event
        
    except ConditionalCheckFailedError as e:
        # Re-raise the error the SFN Catch block is looking for
        raise ConditionalCheckFailedError("InsufficientFunds") from e
    
    # Other exceptions (InternalError) are handled by the SFN Retry/Catch logic