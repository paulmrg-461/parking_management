"""Authentication endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.auth_service import AuthService
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository
from app.presentation.deps import get_user_repository
from app.presentation.schemas import LoginRequest, TokenResponse, UserRead

router = APIRouter(tags=["auth"])


@router.post("/auth/login", response_model=TokenResponse)
async def login(
    body: LoginRequest,
    users: SqlAlchemyUserRepository = Depends(get_user_repository),
) -> TokenResponse:
    service = AuthService(users)
    user = await service.login(body.username, body.pin)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
        )
    return TokenResponse(
        access_token=service.issue_token(user),
        user=UserRead.model_validate(user),
    )
