import os


class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        "sqlite:////app/instance/driving_exam.db"
        if os.getenv("FLASK_ENV") == "production"
        else "sqlite:///driving_exam.db",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_AS_ASCII = False
