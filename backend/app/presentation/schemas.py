"""Pydantic schemas for auth and user management."""

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.domain.tariff import TariffType
from app.domain.user import UserRole


class LoginRequest(BaseModel):
    username: str
    pin: str


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    display_name: str
    role: UserRole
    is_active: bool


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead


class UserCreate(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    display_name: str = Field(min_length=1, max_length=100)
    role: UserRole
    pin: str

    @field_validator("pin")
    @classmethod
    def pin_must_be_digits(cls, value: str) -> str:
        if not value.isdigit() or not 4 <= len(value) <= 6:
            raise ValueError("PIN must be 4 to 6 digits")
        return value


class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=100)
    role: UserRole | None = None
    is_active: bool | None = None


class CategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class CategoryUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class TariffRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    category_id: int
    type: TariffType
    amount: int
    start_time: str | None
    end_time: str | None
    active: bool


class TariffCreate(BaseModel):
    category_id: int
    type: TariffType
    amount: int
    start_time: str | None = None
    end_time: str | None = None


class TariffUpdate(BaseModel):
    type: TariffType | None = None
    amount: int | None = None
    start_time: str | None = None
    end_time: str | None = None
    active: bool | None = None


class VehicleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    plate: str
    category_id: int
    color: str | None
    brand: str | None


class VehicleCreate(BaseModel):
    plate: str = Field(min_length=1, max_length=20)
    category_id: int
    color: str | None = Field(default=None, max_length=30)
    brand: str | None = Field(default=None, max_length=50)


class VehicleUpdate(BaseModel):
    category_id: int | None = None
    color: str | None = Field(default=None, max_length=30)
    brand: str | None = Field(default=None, max_length=50)
