import os
import time
import razorpay
from dotenv import load_dotenv
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry

# Load .env from backend directory explicitly so it works regardless of working directory
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
load_dotenv()


def create_client():
    c = razorpay.Client(
        auth=(
            os.getenv("RAZORPAY_KEY_ID"),
            os.getenv("RAZORPAY_KEY_SECRET")
        )
    )
    # Set up adapter with retry for idle connection drops
    retries = Retry(
        total=3,
        backoff_factor=0.3,
        status_forcelist=[500, 502, 503, 504],
        raise_on_status=False
    )
    adapter = HTTPAdapter(max_retries=retries, pool_connections=5, pool_maxsize=10)
    c.session.mount("https://", adapter)
    c.session.mount("http://", adapter)
    return c


client = create_client()


def verify_payment(
    razorpay_payment_id: str,
    razorpay_order_id: str,
    razorpay_signature: str
) -> bool:
    global client
    data = {
        "razorpay_payment_id": razorpay_payment_id,
        "razorpay_order_id": razorpay_order_id,
        "razorpay_signature": razorpay_signature
    }

    try:
        client.utility.verify_payment_signature(data)
        return True
    except razorpay.errors.SignatureVerificationError:
        return False
    except Exception:
        try:
            client = create_client()
            client.utility.verify_payment_signature(data)
            return True
        except Exception:
            return False


def create_razorpay_order(amount: int, receipt: str):
    global client
    data = {
        "amount": amount,
        "currency": "INR",
        "receipt": receipt
    }

    last_error = None
    for attempt in range(3):
        try:
            order = client.order.create(data=data)
            return order
        except Exception as e:
            last_error = e
            # Recreate client with fresh session on connection drop
            client = create_client()
            time.sleep(0.3)

    if last_error:
        raise last_error


def get_payment(payment_id: str):
    global client
    try:
        return client.payment.fetch(payment_id)
    except Exception:
        client = create_client()
        return client.payment.fetch(payment_id)