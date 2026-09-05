"""User management endpoints (admin only)."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.user_service import (
    DuplicateUsernameError,
    UserNotFoundError,
    UserService,
)
from app.infrastructure.repositories.user_repository import SqlAlchemyUserRepository
from app.presentation.deps import get_user_repository, require_admin
from app.presentation.schemas import UserCreate, UserRead, UserUpdate

router = APIRouter(tags=["users"])


@router.get(
    "/users",
    response_model=list[UserRead],
    dependencies=[Depends(require_admin)],
)
async def list_users(
    users: SqlAlchemyUserRepository = Depends(get_user_repository),
) -> list[UserRead]:
    result = await UserService(users).list_all()
    return [UserRead.model_validate(user) for user in result]


@router.post(
    "/users",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_admin)],
)
async def create_user(
    body: UserCreate,
    users: SqlAlchemyUserRepository = Depends(get_user_repository),
) -> UserRead:
    try:
        user = await UserService(users).create(
            body.username, body.display_name, body.role, body.pin
        )
    except DuplicateUsernameError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Username already exists"
        ) from exc
    return UserRead.model_validate(user)


@router.patch(
    "/users/{user_id}",
    response_model=UserRead,
    dependencies=[Depends(require_admin)],
)
async def update_user(
    user_id: int,
    body: UserUpdate,
    users: SqlAlchemyUserRepository = Depends(get_user_repository),
) -> UserRead:
    try:
        user = await UserService(users).update(
            user_id, body.display_name, body.role, body.is_active
        )
    except UserNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        ) from exc
    return UserRead.model_validate(user)
