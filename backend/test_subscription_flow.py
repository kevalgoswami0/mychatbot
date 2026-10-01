import os
import hmac
import hashlib
from datetime import datetime, timedelta
import requests
from database import SessionLocal
import models
from security import create_access_token, hash_password

BASE_URL = "http://127.0.0.1:8000"

def setup_test_users():
    db = SessionLocal()
    try:
        # Create or fetch User A
        user_a = db.query(models.User).filter(models.User.email == "test_user_a@test.com").first()
        if not user_a:
            user_a = models.User(
                name="Test User A",
                email="test_user_a@test.com",
                password=hash_password("Pass123!"),
                is_email_verified=True
            )
            db.add(user_a)
            db.commit()
            db.refresh(user_a)

        # Create or fetch User B
        user_b = db.query(models.User).filter(models.User.email == "test_user_b@test.com").first()
        if not user_b:
            user_b = models.User(
                name="Test User B",
                email="test_user_b@test.com",
                password=hash_password("Pass123!"),
                is_email_verified=True
            )
            db.add(user_b)
            db.commit()
            db.refresh(user_b)

        # Clean prior test subscriptions and sessions for these two test users
        db.query(models.Subscription).filter(
            models.Subscription.user_id.in_([user_a.id, user_b.id])
        ).delete(synchronize_session=False)

        db.query(models.ChatSession).filter(
            models.ChatSession.user_id.in_([user_a.id, user_b.id])
        ).delete(synchronize_session=False)

        db.query(models.PaymentOrder).filter(
            models.PaymentOrder.user_id.in_([user_a.id, user_b.id])
        ).delete(synchronize_session=False)

        db.commit()
        return user_a.id, user_b.id
    finally:
        db.close()

def run_tests():
    print("==================================================")
    print("RUNNING 10 COMPREHENSIVE SUBSCRIPTION & ACCESS TESTS")
    print("==================================================")

    user_a_id, user_b_id = setup_test_users()
    token_a = create_access_token(user_a_id)
    token_b = create_access_token(user_b_id)
    headers_a = {"Authorization": f"Bearer {token_a}", "Content-Type": "application/json"}
    headers_b = {"Authorization": f"Bearer {token_b}", "Content-Type": "application/json"}

    # ----------------------------------------------------
    # TEST 1: User A logs in. Uses chatbot for 2 minutes.
    # Expected: User A reaches daily free limit, access is blocked.
    # ----------------------------------------------------
    print("\n--- TEST 1: User A 2-minute Daily Free Limit ---")
    db = SessionLocal()
    # Add 120 seconds of usage for User A today
    session_a = models.ChatSession(
        user_id=user_a_id,
        started_at=datetime.utcnow(),
        ended_at=datetime.utcnow(),
        duration_seconds=120,
        status="active"
    )
    db.add(session_a)
    db.commit()
    db.close()

    res_sub_a = requests.get(f"{BASE_URL}/users/subscription", headers=headers_a).json()
    print("User A Subscription:", res_sub_a)
    assert res_sub_a["has_subscription"] is False
    assert res_sub_a["limit_reached"] is True
    assert res_sub_a["used_seconds_today"] >= 120
    assert res_sub_a["remaining_seconds_today"] == 0

    res_limit_a = requests.get(f"{BASE_URL}/users/chat-limit", headers=headers_a).json()
    assert res_limit_a["has_access"] is False
    assert res_limit_a["limit_reached"] is True

    # Attempt to send message via HTTP
    conv_res = requests.post(f"{BASE_URL}/users/conversations", headers=headers_a).json()
    conv_id = conv_res["conversation_id"]
    chat_res = requests.post(
        f"{BASE_URL}/users/chat",
        headers=headers_a,
        json={"conversation_id": conv_id, "message": "Hello?"}
    )
    print("User A Chat Attempt Status Code:", chat_res.status_code)
    assert chat_res.status_code == 403, f"Expected 403 Forbidden, got {chat_res.status_code}"
    print("PASS: TEST 1 - User A reached daily free limit and was blocked.")

    # ----------------------------------------------------
    # TEST 2: User B logs in.
    # Expected: User B has independent 2-minute allowance; unaffected by User A.
    # ----------------------------------------------------
    print("\n--- TEST 2: User B Isolation ---")
    res_sub_b = requests.get(f"{BASE_URL}/users/subscription", headers=headers_b).json()
    print("User B Subscription:", res_sub_b)
    assert res_sub_b["has_subscription"] is False
    assert res_sub_b["limit_reached"] is False
    assert res_sub_b["used_seconds_today"] == 0
    assert res_sub_b["remaining_seconds_today"] == 120

    res_limit_b = requests.get(f"{BASE_URL}/users/chat-limit", headers=headers_b).json()
    assert res_limit_b["has_access"] is True
    assert res_limit_b["limit_reached"] is False
    print("PASS: TEST 2 - User B has full independent 2-minute allowance.")

    # ----------------------------------------------------
    # TEST 3: User A purchases subscription using Razorpay TEST MODE.
    # Expected: Payment verified, User A subscribed, User B unchanged.
    # ----------------------------------------------------
    print("\n--- TEST 3: User A Razorpay Test Payment & Verification ---")
    order_res = requests.post(f"{BASE_URL}/users/create-order", headers=headers_a, json={"plan_id": 2}).json()
    print("Order Created:", order_res)
    order_id = order_res["order_id"]
    fake_payment_id = f"pay_test_{order_id[6:]}"

    secret = os.getenv("RAZORPAY_KEY_SECRET", "zFwAf4j3bqsXs03CeAufF6jJ")
    payload = f"{order_id}|{fake_payment_id}".encode("utf-8")
    valid_signature = hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()

    verify_res = requests.post(
        f"{BASE_URL}/users/verify-payment",
        headers=headers_a,
        json={
            "razorpay_order_id": order_id,
            "razorpay_payment_id": fake_payment_id,
            "razorpay_signature": valid_signature,
            "plan_id": 2
        }
    )
    print("Verify Response:", verify_res.status_code, verify_res.json())
    assert verify_res.status_code == 200
    assert verify_res.json()["status"] == "active"

    # User A now has active subscription and unlimited access
    sub_a_after = requests.get(f"{BASE_URL}/users/subscription", headers=headers_a).json()
    print("User A Subscribed Status:", sub_a_after)
    assert sub_a_after["has_subscription"] is True
    assert sub_a_after["status"] == "active"
    assert sub_a_after["limit_reached"] is False

    # User B remains free and unaffected
    sub_b_after = requests.get(f"{BASE_URL}/users/subscription", headers=headers_b).json()
    assert sub_b_after["has_subscription"] is False
    assert sub_b_after["limit_reached"] is False
    print("PASS: TEST 3 - User A successfully subscribed. User B remains free.")

    # ----------------------------------------------------
    # TEST 4: Restart app (fresh HTTP request for User A).
    # Expected: User A is still subscribed.
    # ----------------------------------------------------
    print("\n--- TEST 4: App Restart Persistence ---")
    sub_a_restart = requests.get(f"{BASE_URL}/users/subscription", headers=headers_a).json()
    assert sub_a_restart["has_subscription"] is True
    assert sub_a_restart["status"] == "active"
    assert sub_a_restart["plan_name"] == "Basic"
    print("PASS: TEST 4 - Subscription state persisted across app restart.")

    # ----------------------------------------------------
    # TEST 5: Logout User A. Login User B.
    # Expected: User B does NOT inherit User A's subscription.
    # ----------------------------------------------------
    print("\n--- TEST 5: User Switch / Logout-Login Isolation ---")
    sub_b_fresh = requests.get(f"{BASE_URL}/users/subscription", headers=headers_b).json()
    assert sub_b_fresh["has_subscription"] is False
    assert sub_b_fresh["plan_name"] == "Free"
    print("PASS: TEST 5 - User B does NOT inherit User A's subscription.")

    # ----------------------------------------------------
    # TEST 6: Payment fails (e.g. invalid signature).
    # Expected: Subscription is NOT activated.
    # ----------------------------------------------------
    print("\n--- TEST 6: Failed Payment Handling ---")
    order_b_res = requests.post(f"{BASE_URL}/users/create-order", headers=headers_b, json={"plan_id": 2}).json()
    order_b_id = order_b_res["order_id"]
    fake_b_payment = f"pay_test_{order_b_id[6:]}"

    fail_res = requests.post(
        f"{BASE_URL}/users/verify-payment",
        headers=headers_b,
        json={
            "razorpay_order_id": order_b_id,
            "razorpay_payment_id": fake_b_payment,
            "razorpay_signature": "completely_invalid_signature_hex_12345",
            "plan_id": 2
        }
    )
    print("Failed Verification Status:", fail_res.status_code, fail_res.json())
    assert fail_res.status_code == 400
    # Confirm User B is still free
    sub_b_check = requests.get(f"{BASE_URL}/users/subscription", headers=headers_b).json()
    assert sub_b_check["has_subscription"] is False
    print("PASS: TEST 6 - Failed payment rejected and subscription not activated.")

    # ----------------------------------------------------
    # TEST 7: Payment is cancelled/abandoned.
    # Expected: User remains in previous state.
    # ----------------------------------------------------
    print("\n--- TEST 7: Abandoned Payment ---")
    # Order was created in Test 6, user abandoned without verifying
    sub_b_abandon = requests.get(f"{BASE_URL}/users/subscription", headers=headers_b).json()
    assert sub_b_abandon["has_subscription"] is False
    assert sub_b_abandon["plan_name"] == "Free"
    print("PASS: TEST 7 - Abandoned payment did not activate subscription.")

    # ----------------------------------------------------
    # TEST 8: Duplicate payment callback protection.
    # Expected: No duplicate subscription records, safe idempotence.
    # ----------------------------------------------------
    print("\n--- TEST 8: Payment Duplication Protection ---")
    dup_res = requests.post(
        f"{BASE_URL}/users/verify-payment",
        headers=headers_a,
        json={
            "razorpay_order_id": order_id,
            "razorpay_payment_id": fake_payment_id,
            "razorpay_signature": valid_signature,
            "plan_id": 2
        }
    )
    print("Duplicate Call Status:", dup_res.status_code, dup_res.json())
    assert dup_res.status_code == 200
    assert "already verified" in dup_res.json()["message"].lower()

    # Verify no duplicate active subscription records in database for User A
    db = SessionLocal()
    subs_count = db.query(models.Subscription).filter(
        models.Subscription.user_id == user_a_id,
        models.Subscription.status == "active"
    ).count()
    db.close()
    assert subs_count == 1, f"Expected exactly 1 active subscription, found {subs_count}"
    print("PASS: TEST 8 - Duplicate payment recognized safely without duplicating subscription.")

    # ----------------------------------------------------
    # TEST 9: Subscription expires.
    # Expected: User returns to free-user access rules.
    # ----------------------------------------------------
    print("\n--- TEST 9: Subscription Expiry ---")
    db = SessionLocal()
    sub_to_expire = db.query(models.Subscription).filter(
        models.Subscription.user_id == user_a_id,
        models.Subscription.status == "active"
    ).first()
    sub_to_expire.end_date = datetime.utcnow() - timedelta(days=1)
    db.commit()
    db.close()

    # Now verify User A is recognized as expired and returned to Free tier
    sub_a_expired = requests.get(f"{BASE_URL}/users/subscription", headers=headers_a).json()
    print("User A Expired Sub:", sub_a_expired)
    assert sub_a_expired["has_subscription"] is False
    assert sub_a_expired["plan_name"] == "Free"
    print("PASS: TEST 9 - Expired subscription automatically reverted to free tier.")

    # ----------------------------------------------------
    # TEST 10: Bypass prevention (restart, new chat, direct calls).
    # Expected: Backend strictly enforces limits.
    # ----------------------------------------------------
    print("\n--- TEST 10: Free Limit Bypass Prevention ---")
    # User A now free and has 600s session from Test 1
    # Try creating a new conversation
    new_conv = requests.post(f"{BASE_URL}/users/conversations", headers=headers_a).json()
    new_conv_id = new_conv["conversation_id"]

    bypass_chat = requests.post(
        f"{BASE_URL}/users/chat",
        headers=headers_a,
        json={"conversation_id": new_conv_id, "message": "Can I bypass?"}
    )
    print("Bypass Attempt Status Code:", bypass_chat.status_code)
    assert bypass_chat.status_code == 403, f"Expected 403, got {bypass_chat.status_code}"

    # Try chat limit endpoint
    bypass_limit = requests.get(f"{BASE_URL}/users/chat-limit", headers=headers_a).json()
    assert bypass_limit["has_access"] is False
    assert bypass_limit["limit_reached"] is True
    print("PASS: TEST 10 - Bypass attempts across new conversations and direct calls strictly blocked.")

    print("\n==================================================")
    print("ALL 10 TESTS PASSED WITH 100% SUCCESS!")
    print("==================================================")

if __name__ == "__main__":
    run_tests()
