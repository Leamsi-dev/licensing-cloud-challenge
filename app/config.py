from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    database_url: str
    redis_url: str
    jwt_private_key_path: Optional[str] = "keys/private_key.pem"
    jwt_public_key_path: Optional[str] = "keys/public_key.pem"
    jwt_algorithm: str = "RS256"
    jwt_expires_minutes: int = 30
    
    class Config:
        env_file = ".env"


settings = Settings()