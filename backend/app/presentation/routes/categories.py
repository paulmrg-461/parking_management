"""Vehicle category endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.application.category_service import (
    CategoryNotFoundError,
    CategoryService,
    DuplicateCategoryNameError,
)
from app.infrastructure.repositories.category_repository import (
    SqlAlchemyCategoryRepository,
)
from app.presentation.deps import (
    get_category_repository,
    get_current_user,
    require_admin,
)
from app.presentation.schemas import CategoryCreate, CategoryRead, CategoryUpdate

router = APIRouter(tags=["categories"])


@router.get(
    "/categories",
    response_model=list[CategoryRead],
    dependencies=[Depends(get_current_user)],
)
async def list_categories(
    categories: SqlAlchemyCategoryRepository = Depends(get_category_repository),
) -> list[CategoryRead]:
    result = await CategoryService(categories).list_all()
    return [CategoryRead.model_validate(category) for category in result]


@router.post(
    "/categories",
    response_model=CategoryRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_admin)],
)
async def create_category(
    body: CategoryCreate,
    categories: SqlAlchemyCategoryRepository = Depends(get_category_repository),
) -> CategoryRead:
    try:
        category = await CategoryService(categories).create(body.name)
    except DuplicateCategoryNameError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Category already exists"
        ) from exc
    return CategoryRead.model_validate(category)


@router.patch(
    "/categories/{category_id}",
    response_model=CategoryRead,
    dependencies=[Depends(require_admin)],
)
async def update_category(
    category_id: int,
    body: CategoryUpdate,
    categories: SqlAlchemyCategoryRepository = Depends(get_category_repository),
) -> CategoryRead:
    try:
        category = await CategoryService(categories).update(category_id, body.name)
    except CategoryNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Category not found"
        ) from exc
    except DuplicateCategoryNameError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Category already exists"
        ) from exc
    return CategoryRead.model_validate(category)


@router.delete(
    "/categories/{category_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_admin)],
)
async def delete_category(
    category_id: int,
    categories: SqlAlchemyCategoryRepository = Depends(get_category_repository),
) -> None:
    try:
        await CategoryService(categories).delete(category_id)
    except CategoryNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Category not found"
        ) from exc
