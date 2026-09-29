"""Parking settings endpoint tests (Success / Failure / Security)."""

from app.infrastructure.local_logo_storage import LocalLogoStorage
from app.main import app
from app.presentation.deps import get_logo_storage

PNG_LOGO = b"\x89PNG\r\n\x1a\n" + b"\x00" * 16 + b"logo-v1"
PNG_LOGO_V2 = b"\x89PNG\r\n\x1a\n" + b"\x00" * 16 + b"logo-v2"


def _use_tmp_logo_storage(tmp_path):
    storage = LocalLogoStorage(str(tmp_path))
    app.dependency_overrides[get_logo_storage] = lambda: storage


async def test_get_settings_returns_defaults_without_auth(client):
    response = await client.get("/api/settings")

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Parqueadero"
    assert body["address"] == ""
    assert body["schedule"] == ""
    assert body["phone"] == ""
    assert body["website"] == ""
    assert body["whatsapp"] == ""
    assert body["logo_version"] == 0


async def test_admin_patch_merges_and_persists(client, admin_headers):
    patched = await client.patch(
        "/api/settings",
        json={
            "name": "Parqueadero Central",
            "address": "Cra 7 # 12-34",
            "phone": "+57 300 111 2233",
        },
        headers=admin_headers,
    )
    fetched = await client.get("/api/settings")

    assert patched.status_code == 200
    assert fetched.json()["name"] == "Parqueadero Central"
    assert fetched.json()["address"] == "Cra 7 # 12-34"
    assert fetched.json()["phone"] == "+57 300 111 2233"
    # Untouched fields keep their defaults (merge, not replace).
    assert fetched.json()["schedule"] == ""


async def test_patch_rejects_empty_name_and_bad_website(client, admin_headers):
    empty_name = await client.patch(
        "/api/settings", json={"name": ""}, headers=admin_headers
    )
    bad_website = await client.patch(
        "/api/settings", json={"website": "not a url"}, headers=admin_headers
    )
    unchanged = await client.get("/api/settings")

    assert empty_name.status_code == 422
    assert bad_website.status_code == 422
    assert unchanged.json()["name"] == "Parqueadero"


async def test_patch_requires_authentication(client):
    response = await client.patch("/api/settings", json={"name": "Nope"})

    assert response.status_code in (401, 403)


async def test_operator_cannot_patch_settings(client, operator_headers):
    response = await client.patch(
        "/api/settings", json={"name": "Hijacked"}, headers=operator_headers
    )
    unchanged = await client.get("/api/settings")

    assert response.status_code == 403
    assert unchanged.json()["name"] == "Parqueadero"


async def test_admin_upload_logo_bumps_version_and_serves_png(
    client, admin_headers, tmp_path
):
    _use_tmp_logo_storage(tmp_path)

    first = await client.post(
        "/api/settings/logo",
        files={"file": ("logo.png", PNG_LOGO, "image/png")},
        headers=admin_headers,
    )
    replaced = await client.post(
        "/api/settings/logo",
        files={"file": ("logo.png", PNG_LOGO_V2, "image/png")},
        headers=admin_headers,
    )
    served = await client.get("/api/settings/logo")
    stored = await client.get("/api/settings")

    assert first.status_code == 200
    assert first.json()["logo_version"] == 1
    # A second upload replaces the file and bumps the version again.
    assert replaced.json()["logo_version"] == 2
    assert served.status_code == 200
    assert served.content == PNG_LOGO_V2
    assert served.headers["content-type"].startswith("image/png")
    assert stored.json()["logo_version"] == 2


async def test_logo_upload_rejects_non_image_and_oversized_file(
    client, admin_headers, tmp_path
):
    _use_tmp_logo_storage(tmp_path)

    text_upload = await client.post(
        "/api/settings/logo",
        files={"file": ("logo.txt", b"not an image", "text/plain")},
        headers=admin_headers,
    )
    oversized = await client.post(
        "/api/settings/logo",
        files={"file": ("big.png", b"\x00" * (5 * 1024 * 1024 + 1), "image/png")},
        headers=admin_headers,
    )
    stored = await client.get("/api/settings")
    served = await client.get("/api/settings/logo")

    assert text_upload.status_code == 422
    assert oversized.status_code == 413
    assert stored.json()["logo_version"] == 0
    assert served.status_code == 404


async def test_operator_cannot_upload_logo(client, operator_headers, tmp_path):
    _use_tmp_logo_storage(tmp_path)

    response = await client.post(
        "/api/settings/logo",
        files={"file": ("logo.png", PNG_LOGO, "image/png")},
        headers=operator_headers,
    )
    stored = await client.get("/api/settings")
    served = await client.get("/api/settings/logo")

    assert response.status_code == 403
    assert stored.json()["logo_version"] == 0
    assert served.status_code == 404
