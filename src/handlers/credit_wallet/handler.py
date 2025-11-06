# real-time-clearing-mock/src/handlers/credit_wallet/handler.py
import json
from decimal import Decimal
from libs.db_client import WALLETS_TABLE, transact_write_items

def handler(event, context):
    """
    Atomically credits the beneficiary's wallet.
    Note: No conditional check needed as a credit cannot fail due to 'InsufficientFunds'.
    """
    beneficiary_id = event.get('beneficiary_id')
    amount = Decimal(str(event.get('amount', 0)))

    if amount <= 0:
        raise ValueError("Invalid credit amount.")

    # Transaction Item: Update Beneficiary's Balance
    credit_item = {
        'Update': {
            'TableName': WALLETS_TABLE,
            'Key': {'PK': beneficiary_id, 'SK': 'WALLET'},
            'UpdateExpression': 'SET #b = #b + :amt',
            'ExpressionAttributeNames': {'#b': 'balance'},
            'ExpressionAttributeValues': {
                ':amt': amount
            }
        }
    }

    try:
        # If this transaction fails, it means the debit was successful, 
        # and the SFN will transition to the ReconciliationRequired state.
        transact_write_items([credit_item])
        print(f"Successfully credited {amount} to Beneficiary {beneficiary_id}")
        
        return event
        
    except Exception as e:
        # Any failure here is catastrophic, requiring reconciliation
        print(f"CRITICAL FAILURE: Beneficiary credit failed. {e}")
        raise # SFN will catch this and move to ReconciliationRequired