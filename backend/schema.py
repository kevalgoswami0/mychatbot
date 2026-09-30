from pydantic import BaseModel,Field,EmailStr

class SignupRequest(BaseModel):
    name: str =Field(min_length=2, max_length=100)
    email: EmailStr
    password: str
    confirm_password: str

class Login(BaseModel):
    email: EmailStr
    password: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class VerifyEmailRequest(BaseModel):
    email: EmailStr
    otp: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyResetOTPRequest(BaseModel):
    email: EmailStr
    otp: str


class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str

class ChatRequest(BaseModel):
    conversation_id: int
    message: str

class CreateOrderRequest(BaseModel):
    plan_id: int

class VerifyPaymentRequest(BaseModel):
    razorpay_payment_id: str
    razorpay_order_id: str
    razorpay_signature: str
    plan_id: int

class UpdateConversationRequest(BaseModel):
    title: str