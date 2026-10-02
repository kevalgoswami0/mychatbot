import os
import hmac
import hashlib
import asyncio
import re
import jwt
from security import SECRET_KEY,ALGORITHM
from schema import VerifyPaymentRequest
from chatbot_service import ask_groq,ask_groq_with_history
from fastapi import APIRouter, Depends, HTTPException , WebSocket,WebSocketDisconnect
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from email_service import send_email
from fastapi.responses import FileResponse
import uuid
from tts_service import generate_speech
from payment_service import create_razorpay_order,verify_payment,get_payment
import random
from datetime import datetime, timedelta
from tts_service import generate_speech

from database import get_db
import models
from schema import Login, SignupRequest , RefreshTokenRequest ,ChatRequest,ResetPasswordRequest,VerifyResetOTPRequest,VerifyEmailRequest,ForgotPasswordRequest , CreateOrderRequest, UpdateConversationRequest
from security import hash_password, verify_password,create_access_token,verify_access_token,bearer_scheme,create_refresh_token,verify_refresh_token,create_password_reset_token,verify_password_reset_token

from security import authenticate_websocket
from security import WebSocketException, status


router = APIRouter(
    prefix="/users",
    tags=["Users"]
)


@router.get("/")
def get_users(
    db: Session = Depends(get_db)
):
    users = db.query(models.User).all()
    return users

@router.post("/signup")
async def signup(
    user: SignupRequest,
    db: Session = Depends(get_db)
):
    existing_user = db.query(models.User).filter(models.User.email == user.email).first()
    if existing_user :
        raise HTTPException(
            status_code=400,
            detail="email already existing")
    if user.password != user.confirm_password:
        raise HTTPException(status_code=400, detail="Password and confirm password do not match")

    hashed_password = hash_password(user.password)

    new_user = models.User(
        name=user.name,
        email=user.email,
        password=hashed_password
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    otp = str(random.randint(100000, 999999))

 
    otp_record = models.EmailOTP(
    email=user.email,
    otp=otp,
    expires_at=datetime.utcnow() + timedelta(minutes=10),
    purpose="email_verification"
)

    db.add(otp_record)
    db.commit()

    
    await send_email(
        email=user.email,
        subject="Email Verification OTP",
        body=f"Your verification OTP is: {otp}\n\nThis OTP expires in 10 minutes."
    )

    return {
        "message": "Signup successful. Check your email for the verification OTP."
    }


@router.post("/verify-email")
def verify_email(
    data: VerifyEmailRequest,
    db: Session = Depends(get_db)
):
    otp_record = db.query(models.EmailOTP).filter(
        models.EmailOTP.email == data.email,
        models.EmailOTP.otp == data.otp
    ).first()

    if not otp_record:
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP"
        )

    if otp_record.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=400,
            detail="OTP expired"
        )

    user = db.query(models.User).filter(
        models.User.email == data.email
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    user.is_email_verified = True

    db.delete(otp_record)
    db.commit()

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    new_refresh_token = models.RefreshToken(
        user_id=user.id,
        token=refresh_token,
        expires_at="30 days",
        revoked=False
    )
    db.add(new_refresh_token)
    db.commit()

    return {
        "message": "Email verified successfully",
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email
        }
    }

@router.post("/login")
def user_login(
    user: Login,
    db: Session = Depends(get_db)
):
    existing_user = db.query(models.User).filter(
        models.User.email == user.email
    ).first()

    if not existing_user:
        raise HTTPException(
            status_code=400,
            detail="Invalid email or password"
        )

    if not verify_password(
        user.password,
        existing_user.password
    ):
        raise HTTPException(
            status_code=400,
            detail="Invalid email or password"
        )

    if not existing_user.is_email_verified:
        raise HTTPException(
            status_code=403,
            detail="Please verify your email first"
        )

    access_token = create_access_token(existing_user.id)
    refresh_token = create_refresh_token(existing_user.id)

    db.query(models.RefreshToken).filter(
        models.RefreshToken.user_id == existing_user.id
    ).delete(synchronize_session=False)

    new_refresh_token = models.RefreshToken(
        user_id=existing_user.id,
        token=refresh_token,
        expires_at="30 days",
        revoked=False
    )

    db.add(new_refresh_token)
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": {
            "id": existing_user.id,
            "name": existing_user.name,
            "email": existing_user.email
        }
    }


@router.get("/me")
def get_my_profile(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    user = db.query(models.User).filter(
        models.User.id == user_id
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    return {
        "id": user.id,
        "name": user.name,
        "email": user.email
    }


@router.delete("/account")
def delete_account(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    user = db.query(models.User).filter(
        models.User.id == user_id
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    user_email = user.email

    # 1. Delete all messages for user's conversations
    user_conversations = db.query(models.Conversation).filter(
        models.Conversation.user_id == user_id
    ).all()
    conv_ids = [c.id for c in user_conversations]
    if conv_ids:
        db.query(models.Message).filter(
            models.Message.conversation_id.in_(conv_ids)
        ).delete(synchronize_session=False)

    # 2. Delete conversations
    db.query(models.Conversation).filter(
        models.Conversation.user_id == user_id
    ).delete(synchronize_session=False)

    # 3. Delete chat sessions
    db.query(models.ChatSession).filter(
        models.ChatSession.user_id == user_id
    ).delete(synchronize_session=False)

    # 4. Delete subscriptions
    db.query(models.Subscription).filter(
        models.Subscription.user_id == user_id
    ).delete(synchronize_session=False)

    # 5. Delete payment orders
    db.query(models.PaymentOrder).filter(
        models.PaymentOrder.user_id == user_id
    ).delete(synchronize_session=False)

    # 6. Delete refresh tokens
    db.query(models.RefreshToken).filter(
        models.RefreshToken.user_id == user_id
    ).delete(synchronize_session=False)

    # 7. Delete password reset tokens
    db.query(models.PasswordResetToken).filter(
        models.PasswordResetToken.user_id == user_id
    ).delete(synchronize_session=False)

    # 8. Delete email OTPs associated with user email
    if user_email:
        db.query(models.EmailOTP).filter(
            models.EmailOTP.email == user_email
        ).delete(synchronize_session=False)

    # 9. Delete user record
    db.delete(user)
    db.commit()

    return {
        "message": "Account and all associated data permanently deleted"
    }


@router.post("/refresh")
def refresh_token(
    data: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    user_id = verify_refresh_token(data.refresh_token)

    stored_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token == data.refresh_token,
        models.RefreshToken.user_id == user_id,
        models.RefreshToken.revoked == False
    ).first()

    if not stored_token:
        raise HTTPException(
            status_code=401,
            detail="Refresh token is invalid or revoked"
        )

    access_token = create_access_token(user_id)

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

@router.post("/forgot-password")
async def forgot_password(
    data: ForgotPasswordRequest,
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(
        models.User.email == data.email
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    otp = str(random.randint(100000, 999999))

    otp_record = models.EmailOTP(
        email=data.email,
        otp=otp,
        expires_at=datetime.utcnow() + timedelta(minutes=10),
        purpose="password_reset"
    )

    db.add(otp_record)
    db.commit()

    await send_email(
        email=data.email,
        subject="Password Reset OTP",
        body=f"Your password reset OTP is: {otp}\n\nThis OTP expires in 10 minutes."
    )

    return {
        "message": "Password reset OTP sent to your email"
    }

@router.post("/verify-reset-otp")
def verify_reset_otp(
    data: VerifyResetOTPRequest,
    db: Session = Depends(get_db)
):
    otp_record = db.query(models.EmailOTP).filter(
        models.EmailOTP.email == data.email,
        models.EmailOTP.otp == data.otp,
        models.EmailOTP.purpose == "password_reset"
    ).first()

    if not otp_record:
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP"
        )

    if otp_record.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=400,
            detail="OTP expired"
        )

    user = db.query(models.User).filter(
        models.User.email == data.email
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    reset_token = create_password_reset_token(user.id)

    reset_token = create_password_reset_token(user.id)

    reset_token_record = models.PasswordResetToken(
    user_id=user.id,
    token=reset_token,
    expires_at=datetime.utcnow() + timedelta(minutes=10),
    used=False
)

    db.add(reset_token_record)
    db.commit()

    return {
        "message": "OTP verified",
        "reset_token": reset_token
}

@router.post("/reset-password")
def reset_password(
    data: ResetPasswordRequest,
    db: Session = Depends(get_db)
):
    user_id = verify_password_reset_token(data.reset_token)

    reset_record = db.query(models.PasswordResetToken).filter(
    models.PasswordResetToken.token == data.reset_token,
    models.PasswordResetToken.user_id == user_id,
    models.PasswordResetToken.used == False
    ).first()

    if not reset_record:
        raise HTTPException(
            status_code=401,
            detail="Reset token is invalid or already used"
        )

    if reset_record.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=401,
            detail="Reset token expired"
        )

    user = db.query(models.User).filter(
        models.User.id == user_id
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )

    user.password = hash_password(data.new_password)
    reset_record.used = True

    db.query(models.RefreshToken).filter(
        models.RefreshToken.user_id == user_id,
        models.RefreshToken.revoked == False
    ).update({
        models.RefreshToken.revoked: True
    })

    db.commit()

    return {
        "message": "Password reset successful"
    }

@router.post("/logout")

def logout(
    data: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    stored_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token == data.refresh_token
    ).first()

    if not stored_token:
        raise HTTPException(
            status_code=404,
            detail="Refresh token not found"
        )

    stored_token.revoked = True

    db.commit()

    return {
        "message": "Logout successful"
    }

@router.post("/chat")
def chat(
    data: ChatRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    if not check_chat_access(user_id, db):
        raise HTTPException(
            status_code=403,
            detail="Free chat limit reached (2 min/day). Please upgrade for unlimited access."
        )

    conversation = db.query(models.Conversation).filter(
        models.Conversation.id == data.conversation_id,
        models.Conversation.user_id == user_id
    ).first()

    if not conversation:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    record_chat_activity(user_id, db)

    user_message = models.Message(
        conversation_id=conversation.id,
        role="user",
        content=data.message
    )

    db.add(user_message)
    db.commit()

    response = ask_groq(data.message)

    assistant_message = models.Message(
        conversation_id=conversation.id,
        role="assistant",
        content=response
    )

    db.add(assistant_message)
    db.commit()

    return {
        "conversation_id": conversation.id,
        "response": response
    }


@router.post("/conversations")
def create_conversation(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    conversation = models.Conversation(
        user_id=user_id,
        title="New Chat"
    )

    db.add(conversation)
    db.commit()
    db.refresh(conversation)

    return {
        "id": str(conversation.id),
        "conversation_id": conversation.id,
        "title": conversation.title,
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
        "message_count": 0
    }


@router.get("/conversations")
def get_conversations(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    conversations = db.query(models.Conversation).filter(
        models.Conversation.user_id == user_id
    ).order_by(models.Conversation.id.desc()).all()

    result = []
    for conv in conversations:
        msg_count = db.query(models.Message).filter(
            models.Message.conversation_id == conv.id
        ).count()

        result.append({
            "id": str(conv.id),
            "conversation_id": conv.id,
            "title": conv.title,
            "message_count": msg_count,
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat(),
        })

    return result


@router.get("/conversations/{conversation_id}/messages")
def get_conversation_messages(
    conversation_id: int,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    conv = db.query(models.Conversation).filter(
        models.Conversation.id == conversation_id,
        models.Conversation.user_id == user_id
    ).first()

    if not conv:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    messages = db.query(models.Message).filter(
        models.Message.conversation_id == conversation_id
    ).order_by(models.Message.id.asc()).all()

    return [
        {
            "id": str(msg.id),
            "conversation_id": str(msg.conversation_id),
            "role": msg.role,
            "content": msg.content,
            "status": "sent"
        }
        for msg in messages
    ]


@router.delete("/conversations/{conversation_id}")
def delete_conversation(
    conversation_id: int,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    conv = db.query(models.Conversation).filter(
        models.Conversation.id == conversation_id,
        models.Conversation.user_id == user_id
    ).first()

    if not conv:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    db.query(models.Message).filter(
        models.Message.conversation_id == conversation_id
    ).delete()
    db.delete(conv)
    db.commit()

    return {"message": "Conversation deleted successfully"}


@router.patch("/conversations/{conversation_id}")
def rename_conversation(
    conversation_id: int,
    data: UpdateConversationRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    conv = db.query(models.Conversation).filter(
        models.Conversation.id == conversation_id,
        models.Conversation.user_id == user_id
    ).first()

    if not conv:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found"
        )

    conv.title = data.title.strip() if data.title.strip() else "Untitled Conversation"
    db.commit()

    return {
        "id": str(conv.id),
        "conversation_id": conv.id,
        "title": conv.title
    }


@router.post("/create-order")
def create_order(
    data: CreateOrderRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    
    plan = db.query(models.Plan).filter(
        models.Plan.id == data.plan_id
    ).first()

    if not plan:
        raise HTTPException(
            status_code=404,
            detail="Plan not found"
        )

    
    if plan.price <= 0:
        raise HTTPException(
            status_code=400,
            detail="This plan does not require payment"
        )

   
    amount = plan.price * 100

    
    receipt = f"user_{user_id}_plan_{plan.id}"

    try:
        order = create_razorpay_order(
            amount=amount,
            receipt=receipt
        )
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Unable to connect to payment gateway: {str(e)}"
        )

    
    payment_order = models.PaymentOrder(
        user_id=user_id,
        plan_id=plan.id,
        razorpay_order_id=order["id"],
        amount=amount,
        status="created",
        created_at=datetime.utcnow()
    )

    db.add(payment_order)
    db.commit()
    db.refresh(payment_order)

    return {
        "order_id": order["id"],
        "amount": order["amount"],
        "currency": order["currency"],
        "plan_id": plan.id,
        "plan_name": plan.name,
        "key_id": os.getenv("RAZORPAY_KEY_ID")
    }

@router.post("/verify-payment")
def verify_razorpay_payment(
    data: VerifyPaymentRequest,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    # 1. Identify logged-in user
    user_id = verify_access_token(credentials)

    # 2. Find the payment order we created
    payment_order = db.query(models.PaymentOrder).filter(
        models.PaymentOrder.razorpay_order_id == data.razorpay_order_id,
        models.PaymentOrder.user_id == user_id
    ).first()

    if not payment_order:
        raise HTTPException(
            status_code=404,
            detail="Payment order not found"
        )

    # 3. Check if already processed (Duplication Protection)
    if payment_order.status == "paid":
        existing_sub = get_current_subscription(user_id, db)
        if not existing_sub:
            existing_sub = db.query(models.Subscription).filter(
                models.Subscription.user_id == user_id,
                models.Subscription.plan_id == payment_order.plan_id
            ).order_by(models.Subscription.id.desc()).first()
        plan = db.query(models.Plan).filter(models.Plan.id == payment_order.plan_id).first()
        plan_name = plan.name if plan else "Basic"
        return {
            "message": "Payment already verified and subscription is active",
            "subscription_id": existing_sub.id if existing_sub else None,
            "plan_id": payment_order.plan_id,
            "plan_name": plan_name,
            "status": existing_sub.status if existing_sub else "active",
            "start_date": existing_sub.start_date if existing_sub else None,
            "end_date": existing_sub.end_date if existing_sub else None
        }

    # 4. Make sure the plan matches
    if payment_order.plan_id != data.plan_id:
        raise HTTPException(
            status_code=400,
            detail="Plan does not match payment order"
        )

    # 5. Verify Razorpay signature
    is_test_mode = os.getenv("RAZORPAY_KEY_ID", "").startswith("rzp_test_")
    secret = os.getenv("RAZORPAY_KEY_SECRET", "")

    # Calculate HMAC signature
    payload = f"{data.razorpay_order_id}|{data.razorpay_payment_id}".encode("utf-8")
    expected_signature = hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()

    signature_valid = hmac.compare_digest(data.razorpay_signature, expected_signature)
    if not signature_valid:
        try:
            signature_valid = verify_payment(
                razorpay_payment_id=data.razorpay_payment_id,
                razorpay_order_id=data.razorpay_order_id,
                razorpay_signature=data.razorpay_signature
            )
        except Exception:
            signature_valid = False

    if not signature_valid:
        payment_order.status = "failed"
        db.commit()
        raise HTTPException(
            status_code=400,
            detail="Payment signature verification failed"
        )

    # 6. For live production mode only, fetch from Razorpay API
    if not is_test_mode:
        try:
            payment = get_payment(data.razorpay_payment_id)
            if payment:
                if payment.get("order_id") != payment_order.razorpay_order_id:
                    raise HTTPException(
                        status_code=400,
                        detail="Payment does not belong to this order"
                    )
                if payment.get("amount") != payment_order.amount:
                    raise HTTPException(
                        status_code=400,
                        detail="Payment amount does not match"
                    )
                if payment.get("status") not in ["captured", "authorized"]:
                    raise HTTPException(
                        status_code=400,
                        detail="Payment has not been successfully completed"
                    )
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f"Unable to verify payment with Razorpay: {str(e)}"
            )

    # 10. Get plan
    plan = db.query(models.Plan).filter(
        models.Plan.id == payment_order.plan_id
    ).first()

    if not plan:
        raise HTTPException(
            status_code=404,
            detail="Plan not found"
        )

    # 11. Calculate subscription dates
    start_date = datetime.utcnow()
    duration_days = plan.duration_days if (plan.duration_days and plan.duration_days > 0) else 30
    end_date = start_date + timedelta(days=duration_days)

    # 12. Expire existing active subscriptions for this user
    existing_subscriptions = db.query(
        models.Subscription
    ).filter(
        models.Subscription.user_id == user_id,
        models.Subscription.status == "active"
    ).all()

    for old_sub in existing_subscriptions:
        old_sub.status = "expired"

    # 13. Create new subscription
    subscription = models.Subscription(
        user_id=user_id,
        plan_id=plan.id,
        status="active",
        start_date=start_date,
        end_date=end_date
    )

    db.add(subscription)

    # 14. Mark payment as paid
    payment_order.status = "paid"

    db.commit()
    db.refresh(subscription)

    return {
        "message": "Payment verified and subscription activated",
        "subscription_id": subscription.id,
        "plan_id": plan.id,
        "plan_name": plan.name,
        "status": subscription.status,
        "start_date": subscription.start_date,
        "end_date": subscription.end_date
    }

FREE_DAILY_LIMIT_SECONDS = 2 * 60  # 2 minutes = 120 seconds (temporary for testing)


def get_current_subscription(user_id: int, db: Session):
    db.expire_all()
    now = datetime.utcnow()
    active_subs = db.query(models.Subscription).filter(
        models.Subscription.user_id == user_id,
        models.Subscription.status == "active"
    ).order_by(models.Subscription.id.desc()).all()

    valid_sub = None
    has_changes = False

    for sub in active_subs:
        if sub.end_date and sub.end_date <= now:
            sub.status = "expired"
            has_changes = True
        elif valid_sub is None:
            valid_sub = sub
        else:
            # If multiple active subscriptions exist, retain the latest valid one and expire older
            sub.status = "expired"
            has_changes = True

    if has_changes:
        db.commit()

    return valid_sub


def get_user_daily_chat_usage(user_id: int, db: Session):
    """
    Calculates combined total chat usage (in seconds) for today across all conversations for this user.
    If the user has an active paid subscription, limit is not applicable.
    """
    db.expire_all()
    subscription = get_current_subscription(user_id, db)
    if subscription:
        plan = db.query(models.Plan).filter(models.Plan.id == subscription.plan_id).first()
        plan_name = plan.name if plan else "Basic"
        return {
            "is_subscribed": True,
            "has_access": True,
            "daily_limit_seconds": FREE_DAILY_LIMIT_SECONDS,
            "used_seconds_today": 0,
            "remaining_seconds_today": FREE_DAILY_LIMIT_SECONDS,
            "limit_reached": False,
            "plan_name": plan_name
        }

    now = datetime.utcnow()
    start_of_today = datetime(now.year, now.month, now.day, 0, 0, 0)
    end_of_today = start_of_today + timedelta(days=1)

    # Fetch all sessions for this specific user created today
    sessions = db.query(models.ChatSession).filter(
        models.ChatSession.user_id == user_id,
        models.ChatSession.started_at >= start_of_today,
        models.ChatSession.started_at < end_of_today
    ).all()

    total_used_seconds = sum(s.duration_seconds or 0 for s in sessions)
    limit_reached = total_used_seconds >= FREE_DAILY_LIMIT_SECONDS
    remaining_seconds = max(0, FREE_DAILY_LIMIT_SECONDS - total_used_seconds)

    return {
        "is_subscribed": False,
        "has_access": not limit_reached,
        "daily_limit_seconds": FREE_DAILY_LIMIT_SECONDS,
        "used_seconds_today": total_used_seconds,
        "remaining_seconds_today": remaining_seconds,
        "limit_reached": limit_reached,
        "plan_name": "Free"
    }


def record_chat_activity(user_id: int, db: Session, active_seconds: int = 15):
    """
    Records chat activity for today across any conversation for free users.
    Active conversation interactions within 2 minutes accumulate into the same session.
    """
    subscription = get_current_subscription(user_id, db)
    if subscription:
        return True

    now = datetime.utcnow()
    start_of_today = datetime(now.year, now.month, now.day, 0, 0, 0)
    end_of_today = start_of_today + timedelta(days=1)

    # Check current total usage
    usage = get_user_daily_chat_usage(user_id, db)
    if usage["limit_reached"]:
        return False

    # Find active session today for this user
    active_session = db.query(models.ChatSession).filter(
        models.ChatSession.user_id == user_id,
        models.ChatSession.started_at >= start_of_today,
        models.ChatSession.started_at < end_of_today,
        models.ChatSession.status == "active"
    ).order_by(models.ChatSession.id.desc()).first()

    if not active_session:
        active_session = models.ChatSession(
            user_id=user_id,
            started_at=now,
            ended_at=now,
            duration_seconds=active_seconds,
            status="active"
        )
        db.add(active_session)
    else:
        last_time = active_session.ended_at or active_session.started_at
        gap = (now - last_time).total_seconds()
        if gap < 120:  # Within 2 minutes of active conversation
            active_session.duration_seconds = (active_session.duration_seconds or 0) + active_seconds
            active_session.ended_at = now
        else:
            # Idle gap exceeded: close older session and start fresh active session
            active_session.status = "closed"
            new_session = models.ChatSession(
                user_id=user_id,
                started_at=now,
                ended_at=now,
                duration_seconds=active_seconds,
                status="active"
            )
            db.add(new_session)

    db.commit()
    return True


def check_chat_access(user_id: int, db: Session):
    db.expire_all()
    usage = get_user_daily_chat_usage(user_id, db)
    return usage["has_access"]


@router.get("/chat-limit")
def get_chat_limit(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)
    return get_user_daily_chat_usage(user_id, db)


@router.get("/subscription")
def get_subscription(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    user_id = verify_access_token(credentials)

    subscription = get_current_subscription(user_id, db)
    usage = get_user_daily_chat_usage(user_id, db)

    if not subscription:
        return {
            "has_subscription": False,
            "plan_name": "Free",
            "status": "active",
            "start_date": None,
            "end_date": None,
            "daily_limit_seconds": usage["daily_limit_seconds"],
            "used_seconds_today": usage["used_seconds_today"],
            "remaining_seconds_today": usage["remaining_seconds_today"],
            "limit_reached": usage["limit_reached"]
        }

    plan = db.query(models.Plan).filter(
        models.Plan.id == subscription.plan_id
    ).first()

    if not plan:
        raise HTTPException(
            status_code=404,
            detail="Plan not found"
        )

    return {
        "has_subscription": True,
        "subscription_id": subscription.id,
        "plan_id": plan.id,
        "plan_name": plan.name,
        "price": plan.price,
        "status": subscription.status,
        "start_date": subscription.start_date,
        "end_date": subscription.end_date,
        "daily_limit_seconds": usage["daily_limit_seconds"],
        "used_seconds_today": usage["used_seconds_today"],
        "remaining_seconds_today": usage["remaining_seconds_today"],
        "limit_reached": False
    }


@router.get("/plans")
def get_plans(
    db: Session = Depends(get_db)
):
    plans = db.query(models.Plan).all()

    return {
        "plans": [
            {
                "id": plan.id,
                "name": plan.name,
                "price": plan.price,
                "duration_days": plan.duration_days
            }
            for plan in plans
        ]
    }

def extract_complete_sentence(buffer: str):
    """
    Returns:
    (complete_sentence, remaining_buffer)

    If there is no complete sentence yet:
    (None, buffer)
    """

    match = re.search(r"(.+?[.!?।\n])(?:\s+|$)", buffer, re.DOTALL)

    if match:
        sentence = match.group(1).strip()
        remaining = buffer[match.end():].strip()

        if sentence:
            return sentence, remaining

    return None, buffer

@router.websocket("/ws/chat/{conversation_id}")
async def websocket_chat(
    websocket: WebSocket,
    conversation_id: int,
    db: Session = Depends(get_db)
):
    try:
        user_id = await authenticate_websocket(websocket)

        conversation = db.query(models.Conversation).filter(
            models.Conversation.id == conversation_id,
            models.Conversation.user_id == user_id
        ).first()

        if not conversation:
            raise WebSocketException(
                code=1008,
                reason="Conversation not found"
            )

        if not check_chat_access(user_id, db):
            raise WebSocketException(
                code=1008,
                reason="Free chat limit reached (2 min/day). Upgrade for unlimited access."
            )

        await websocket.accept()

        await websocket.send_json({
            "type": "connected",
            "conversation_id": conversation_id,
            "user_id": user_id
        })

        while True:
            data = await websocket.receive_json()

            message = data.get("message")
            language = data.get("language", "en")

            if not message:
                await websocket.send_json({
                    "type": "error",
                    "message": "Message is required"
                })
                continue

            if not check_chat_access(user_id, db):
                await websocket.send_json({
                    "type": "error",
                    "code": "LIMIT_EXCEEDED",
                    "message": "Free chat limit reached (2 min/day). Upgrade for unlimited access."
                })
                break

            record_chat_activity(user_id, db)

            # Save user message
            user_message = models.Message(
                conversation_id=conversation_id,
                role="user",
                content=message
            )

            db.add(user_message)
            db.commit()

            # Get conversation history
            history = db.query(models.Message).filter(
                models.Message.conversation_id == conversation_id
            ).order_by(
                models.Message.id.asc()
            ).all()

            messages = [
                {
                    "role": item.role,
                    "content": item.content
                }
                for item in history
            ]

            try:
                # Start Groq streaming
                stream = ask_groq_with_history(messages)

                full_response = ""

                for chunk in stream:

                    chunk_text = chunk.choices[0].delta.content

                    if not chunk_text:
                        continue

                    full_response += chunk_text

                    # Send text chunk immediately
                    await websocket.send_json({
                        "type": "chunk",
                        "conversation_id": conversation_id,
                        "content": chunk_text
                    })

                # Save complete AI response
                assistant_message = models.Message(
                    conversation_id=conversation_id,
                    role="assistant",
                    content=full_response
                )

                db.add(assistant_message)
                db.commit()
                db.refresh(assistant_message)

                # Generate ONE WAV after complete response
                audio_filename = f"{uuid.uuid4()}.wav"
                audio_path = os.path.join(
                    "audio",
                    audio_filename
                )

                os.makedirs(
                    "audio",
                    exist_ok=True
                )

                try:
                    await generate_speech(
                        text=full_response,
                        output_file=audio_path,
                        language=language
                    )

                    with open(
                        audio_path,
                        "rb"
                    ) as audio_file:

                        audio_data = audio_file.read()

                    await websocket.send_json({
                        "type": "audio_start",
                        "conversation_id": conversation_id,
                        "format": "wav"
                    })

                    await websocket.send_bytes(audio_data)

                finally:

                    if os.path.exists(audio_path):
                        os.remove(audio_path)

                # Tell Flutter response is complete
                await websocket.send_json({
                    "type": "message_complete",
                    "conversation_id": conversation_id
                })

            except Exception as stream_err:

                print(
                    f"Error streaming AI response: {stream_err}"
                )

                await websocket.send_json({
                    "type": "error",
                    "message": "AI assistant is temporarily busy. Please try again."
                })

    except WebSocketDisconnect:

        print("WebSocket disconnected")
@router.post("/tts")
async def text_to_speech(text: str):

    filename = f"{uuid.uuid4()}.wav"
    output_file = os.path.join("audio", filename)

    os.makedirs("audio", exist_ok=True)

    try:
        await generate_speech(
            text=text,
            output_file=output_file,
            language="en"
        )

        return FileResponse(
            path=output_file,
            media_type="audio/wav",
            filename=filename
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )