import os
from dotenv import load_dotenv
load_dotenv()
from pwdlib import PasswordHash
from datetime import datetime, timedelta, timezone
import jwt
from fastapi import HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import WebSocket, WebSocketException, status

SECRET_KEY = os.getenv('SECRET_KEY', '8f7c2a91d4e6b3f8a1c5e9d2f6b7a4c1e8d3f5a9b2c6e7f1a4d8c3e5b9')
ALGORITHM = os.getenv('ALGORITHM', 'HS256')
Password_Hash = PasswordHash.recommended()
bearer_scheme = HTTPBearer()

def hash_password(password: str):
    return Password_Hash.hash(password)


import uuid
def verify_password(password: str, hashed_password: str):
    return Password_Hash.verify(password, hashed_password)


def create_access_token(user_id: int):
    expires = datetime.now(timezone.utc) + timedelta(days=7)

    payload = {
        "sub": str(user_id),
        "exp": expires,
        "jti": str(uuid.uuid4())
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token


def verify_access_token(
    credentials: HTTPAuthorizationCredentials
):
    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        user_id = payload.get("sub")

        if user_id is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid token"
            )

        return int(user_id)

    except jwt.PyJWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token"
        )


def create_refresh_token(user_id: int):

    expires = datetime.now(timezone.utc) + timedelta(days=30)

    payload = {
        "sub": str(user_id),
        "exp": expires,
        "type": "refresh",
        "jti": str(uuid.uuid4())
    }

    token = jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM
    )

    return token


def verify_refresh_token(refresh_token: str):

    try:
        payload = jwt.decode(
            refresh_token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=401,
                detail="Invalid refresh token"
            )

        user_id = payload.get("sub")

        if user_id is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid refresh token"
            )

        return int(user_id)

    except jwt.PyJWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired refresh token"
        )


def create_password_reset_token(user_id: int):
    expires = datetime.now(timezone.utc) + timedelta(minutes=10)

    payload = {
        "sub": str(user_id),
        "exp": expires,
        "type": "password_reset"
    }

    token = jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM
    )

    return token


def verify_password_reset_token(token: str):
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        if payload.get("type") != "password_reset":
            raise HTTPException(
                status_code=401,
                detail="Invalid reset token"
            )

        user_id = payload.get("sub")

        if user_id is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid reset token"
            )

        return int(user_id)

    except jwt.PyJWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired reset token"
        )



async def authenticate_websocket(websocket: WebSocket):
    token = websocket.query_params.get("token")

    if not token:
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION
        )

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        user_id = payload.get("sub")

        if user_id is None:
            raise WebSocketException(
                code=status.WS_1008_POLICY_VIOLATION
            )

        return int(user_id)

    except jwt.PyJWTError:
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION
        )
