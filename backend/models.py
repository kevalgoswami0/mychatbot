from sqlalchemy import Boolean, Column, Integer, String,DateTime

from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    is_email_verified = Column(Boolean, default=False)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer)
    token = Column(String, unique=True, index=True)
    expires_at = Column(String)
    revoked = Column(Boolean, default=False)


class EmailOTP(Base):
    __tablename__ = "email_otps"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, index=True)
    otp = Column(String)
    expires_at = Column(DateTime)
    purpose = Column(String)

class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer)
    token = Column(String, unique=True, index=True)
    expires_at = Column(DateTime)
    used = Column(Boolean, default=False)


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    title = Column(String)


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    conversation_id = Column(Integer, index=True)
    role = Column(String)
    content = Column(String)

from sqlalchemy import Column, Integer, String, Boolean, DateTime


class Plan(Base):
    __tablename__ = "plans"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    price = Column(Integer, default=0)
    message_limit = Column(Integer)
    duration_days = Column(Integer)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    plan_id = Column(Integer, index=True)
    status = Column(String, default="active")
    start_date = Column(DateTime)
    end_date = Column(DateTime)


class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    started_at = Column(DateTime)
    ended_at = Column(DateTime, nullable=True)
    duration_seconds = Column(Integer, default=0)
    status = Column(String, default="active")


class PaymentOrder(Base):
    __tablename__ = "payment_orders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    plan_id = Column(Integer, index=True)
    razorpay_order_id = Column(
        String,
        unique=True,
        index=True
    )
    amount = Column(Integer)
    status = Column(
        String,
        default="created"
    )
    created_at = Column(DateTime)