from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List, Optional

class Settings(BaseSettings):
    # General
    ENV: str = "dev"
    LOG_LEVEL: str = "INFO"

    # CORS
    CORS_ALLOW_ORIGINS: List[str] = ["*"]

    # Database
    DATABASE_URL: str  # e.g., mysql+pymysql://user:pass@host:3306/db

    # Connection pool tuning
    POOL_SIZE: int = 10
    MAX_OVERFLOW: int = 20
    POOL_PRE_PING: bool = True
    POOL_RECYCLE: int = 1800  # seconds; helps avoid stale MySQL connections
    POOL_TIMEOUT: int = 30
    ECHO_SQL: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="",      # if you want prefixes, set e.g. "APP_"
        extra="ignore"
    )

settings = Settings()
