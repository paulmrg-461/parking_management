"""Application configuration via environment variables."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Parking Management API"
    api_prefix: str = "/api"
    database_url: str = (
        "postgresql+asyncpg://postgres:postgres@localhost:5432/parking"
    )
    secret_key: str = "change-me-in-production-use-a-32-byte-secret-minimum"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    evidence_storage_path: str = "./data/evidence"


settings = Settings()
