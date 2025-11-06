# real-time-clearing-mock/src/handlers/transfer_mock/handler.py
import json
import time
import random

def handler(event, context):
    """
    Mocks the interbank transfer process. Introduces a delay and a small chance of failure.
    """
    transaction_id = event.get('transaction_id')
    
    # Simulate network latency (2 to 5 seconds)
    sleep_time = random.uniform(2.0, 5.0)
    time.sleep(sleep_time)
    print(f"Mock interbank transfer for {transaction_id} took {sleep_time:.2f} seconds.")

    # Add a small, controlled failure chance (e.g., 5% chance of a temporary error)
    if random.random() < 0.05:
        print("MOCK FAILURE: Simulating a temporary interbank system error (InternalError).")
        # Raising a generic exception will trigger the SFN Retry logic
        raise Exception("InternalError") 
        
    # Add transfer completion status to the event
    event['transfer_status'] = 'CLEARED'
    
    return event