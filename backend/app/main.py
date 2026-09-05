"""FastAPI application factory."""

from fastapi import FastAPI

from app.core.config import settings
from app.presentation.routes import (
    auth,
    categories,
    health,
    tariffs,
    users,
    vehicles,
)


def create_app() -> FastAPI:
    application = FastAPI(title=settings.app_name)
    application.include_router(health.router, prefix=settings.api_prefix)
    application.include_router(auth.router, prefix=settings.api_prefix)
    application.include_router(users.router, prefix=settings.api_prefix)
    application.include_router(categories.router, prefix=settings.api_prefix)
    application.include_router(tariffs.router, prefix=settings.api_prefix)
    application.include_router(vehicles.router, prefix=settings.api_prefix)
    return application


app = create_app()
