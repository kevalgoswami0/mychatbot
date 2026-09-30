from dotenv import load_dotenv
load_dotenv()
from fastapi import FastAPI, Depends , HTTPException
from sqlalchemy.orm import Session

from database import engine, Base, SessionLocal , get_db
import models
from route import router

import route
from schema import SignupRequest , Login
from security import hash_password


from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


Base.metadata.create_all(bind=engine)
from sqlalchemy.orm import Session
import models

Base.metadata.create_all(bind=engine)


db = Session(bind=engine)

if db.query(models.Plan).count() == 0:
    free_plan = models.Plan(
        name="Free",
        price=0,
        message_limit=0,
        duration_days=0
    )

    basic_plan = models.Plan(
        name="Basic",
        price=1,
        message_limit=0,
        duration_days=30
    )

    pro_plan = models.Plan(
        name="Pro",
        price=2,
        message_limit=0,
        duration_days=30
    )

    db.add_all([
        free_plan,
        basic_plan,
        pro_plan
    ])

    db.commit()

db.close()

app.include_router(router)



