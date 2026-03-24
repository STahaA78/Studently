from pydantic_settings import BaseSettings

class Config(BaseSettings):
    DEBUG: bool
    MONGO_URL: str
    FIREBASE_CONFIG: dict
    REDIS_URL: str

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

CONFIG = Config()
    