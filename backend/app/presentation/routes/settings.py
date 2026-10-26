"""Parking settings (branding) endpoints."""

from fastapi import APIRouter, Depends, File, Header, Request, Response, UploadFile

from app.application.settings_service import SettingsService
from app.domain.parking_settings import LogoAsset
from app.presentation.deps import (
    get_settings_service,
    get_upload_limits,
    require_admin,
)
from app.presentation.http_cache import conditional_json
from app.presentation.schemas import ParkingSettingsRead, ParkingSettingsUpdate
from app.presentation.uploads import UploadLimits, read_photo_uploads

router = APIRouter(tags=["settings"])

_ETAG = '"logo-v{version}"'


@router.get("/settings")
async def get_settings(
    request: Request,
    service: SettingsService = Depends(get_settings_service),
) -> Response:
    # Public on purpose: branding must render on the login screen pre-auth.
    # Conditional GET (ETag) keeps the client refresh cheap.
    model = ParkingSettingsRead.model_validate(await service.get())
    return conditional_json(request, model, {})


@router.patch(
    "/settings",
    response_model=ParkingSettingsRead,
    dependencies=[Depends(require_admin)],
)
async def update_settings(
    body: ParkingSettingsUpdate,
    service: SettingsService = Depends(get_settings_service),
) -> ParkingSettingsRead:
    return ParkingSettingsRead.model_validate(await service.update(body.to_patch()))


@router.get("/settings/logo")
async def get_logo(
    response: Response,
    service: SettingsService = Depends(get_settings_service),
    if_none_match: str | None = Header(default=None, alias="If-None-Match"),
) -> Response:
    asset = await service.logo_asset()
    if asset is None:
        response.status_code = 404
        return response
    etag = _ETAG.format(version=asset.version)
    if if_none_match == etag:
        response.status_code = 304
        response.headers["ETag"] = etag
        return response
    return _logo_response(asset, etag)


def _logo_response(asset: LogoAsset, etag: str) -> Response:
    return Response(
        content=asset.content,
        media_type=asset.media_type,
        headers={"ETag": etag, "Cache-Control": "no-cache"},
    )


@router.post(
    "/settings/logo",
    response_model=ParkingSettingsRead,
    dependencies=[Depends(require_admin)],
)
async def upload_logo(
    file: UploadFile = File(...),
    service: SettingsService = Depends(get_settings_service),
    limits: UploadLimits = Depends(get_upload_limits),
) -> ParkingSettingsRead:
    uploads = await read_photo_uploads([file], limits)
    return ParkingSettingsRead.model_validate(await service.upload_logo(uploads[0]))
