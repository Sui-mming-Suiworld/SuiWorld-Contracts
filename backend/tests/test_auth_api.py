import os
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

# Ensure required settings values exist before importing the app config
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")
os.environ.setdefault("SECRET_KEY", "bootstrap-secret")
os.environ.setdefault("ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "15")
os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "anon-key")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "service-role-key")

from app.main import app
from app.config import settings
from app.api import auth as auth_module


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture(autouse=True)
def override_settings(monkeypatch):
    monkeypatch.setattr(settings, "SECRET_KEY", "test-secret", raising=False)
    monkeypatch.setattr(settings, "ALGORITHM", "HS256", raising=False)
    monkeypatch.setattr(settings, "ACCESS_TOKEN_EXPIRE_MINUTES", 15, raising=False)


@pytest.fixture
def base_payload():
    return {
        "provider": "google",
        "jwt": "fake-jwt",
        "nonce": "expected-nonce",
        "suiAddress": "0xabc123",
        "sessionKey": "test-session-key",
        "signature": "signature",
        "proof": {
            "proof": {"pi_a": "value"},
            "publicInputs": ["input-1", "input-2"],
            "maxEpoch": 42,
            "jwtRandomness": "0xdeadbeef",
        },
    }


@pytest.fixture
def fixed_datetime(monkeypatch):
    real_datetime = auth_module.datetime
    fixed_now = real_datetime(2024, 1, 1, 0, 0, 0, tzinfo=timezone.utc)

    class FixedDateTime(real_datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is None:
                return fixed_now.replace(tzinfo=None)
            return fixed_now.astimezone(tz)

    monkeypatch.setattr(auth_module, "datetime", FixedDateTime)
    return fixed_now


def _mock_profile(payload):
    return SimpleNamespace(
        id=1,
        supabase_id=None,
        email="user@example.com",
        sui_address=payload["suiAddress"],
        session_key=payload["sessionKey"],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )


def test_zk_login_success(client, base_payload, fixed_datetime, monkeypatch):
    exp_dt = fixed_datetime + timedelta(minutes=10)

    monkeypatch.setattr(
        auth_module,
        "_decode_zklogin_jwt",
        lambda token: {
            "sub": "user-id",
            "email": "user@example.com",
            "nonce": "expected-nonce",
            "exp": int(exp_dt.timestamp()),
        },
    )

    profile = _mock_profile(base_payload)
    monkeypatch.setattr(auth_module, "_upsert_profile", lambda *args, **kwargs: profile)

    def fake_create_session_token(**kwargs):
        assert kwargs["subject"] == profile.sui_address
        return "signed-session-token", fixed_datetime + timedelta(minutes=15)

    monkeypatch.setattr(auth_module, "create_session_token", fake_create_session_token)

    response = client.post("/auth/zk-login", json=base_payload)
    assert response.status_code == 200

    data = response.json()
    assert data["profile"]["sui_address"] == base_payload["suiAddress"]
    assert data["session"]["token"] == "signed-session-token"
    assert data["session"]["expires_at"] == (
        fixed_datetime + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    ).isoformat()


def test_zk_login_nonce_mismatch(client, base_payload, monkeypatch):
    monkeypatch.setattr(
        auth_module,
        "_decode_zklogin_jwt",
        lambda token: {"nonce": "unexpected", "exp": int(datetime.now(timezone.utc).timestamp())},
    )

    response = client.post("/auth/zk-login", json=base_payload)
    assert response.status_code == 400
    assert response.json()["detail"] == "Nonce mismatch between proof and OIDC token"


def test_zk_login_expired_token(client, base_payload, fixed_datetime, monkeypatch):
    monkeypatch.setattr(
        auth_module,
        "_decode_zklogin_jwt",
        lambda token: {
            "nonce": "expected-nonce",
            "exp": int((fixed_datetime - timedelta(minutes=1)).timestamp()),
        },
    )

    response = client.post("/auth/zk-login", json=base_payload)
    assert response.status_code == 401
    assert response.json()["detail"] == "OIDC token has expired"


def test_supabase_login_success(client, monkeypatch):
    payload = {"access_token": "supabase-token"}

    monkeypatch.setattr(
        auth_module,
        "verify_supabase_jwt",
        lambda token: {"sub": "supabase-user", "email": "claims@example.com"},
    )
    monkeypatch.setattr(
        auth_module,
        "_fetch_supabase_user",
        lambda token: {"id": "supabase-user", "email": "user@example.com"},
    )

    profile = SimpleNamespace(
        id=2,
        supabase_id="supabase-user",
        email="user@example.com",
        sui_address=None,
        session_key=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    monkeypatch.setattr(auth_module, "_upsert_profile", lambda *args, **kwargs: profile)
    monkeypatch.setattr(
        auth_module,
        "create_session_token",
        lambda **kwargs: ("supabase-session", datetime.now(timezone.utc) + timedelta(minutes=15)),
    )

    response = client.post("/auth/supabase-login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["profile"]["supabase_id"] == "supabase-user"
    assert data["profile"]["email"] == "user@example.com"
    assert data["session"]["token"] == "supabase-session"
