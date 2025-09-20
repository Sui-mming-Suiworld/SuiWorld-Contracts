import os
import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from jose import JWTError

# Ensure required settings values exist before importing the app config
os.environ.setdefault("DATABASE_URL", "postgresql://user:pass@localhost/db")
os.environ.setdefault("SECRET_KEY", "bootstrap-secret")
os.environ.setdefault("ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "15")

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


def test_zk_login_success(client, base_payload, fixed_datetime, monkeypatch):
    exp_dt = fixed_datetime + timedelta(minutes=10)

    def fake_get_unverified_claims(token):
        assert token == "fake-jwt"
        return {
            "sub": "user-id",
            "email": "user@example.com",
            "nonce": "expected-nonce",
            "exp": int(exp_dt.timestamp()),
        }

    def fake_encode(payload, key, algorithm):
        assert payload["sui_address"] == base_payload["suiAddress"]
        assert payload["session_key"] == base_payload["sessionKey"]
        assert key == settings.SECRET_KEY
        assert algorithm == settings.ALGORITHM
        return "signed-session-token"

    monkeypatch.setattr(auth_module.jwt, "get_unverified_claims", fake_get_unverified_claims)
    monkeypatch.setattr(auth_module.jwt, "encode", fake_encode)

    response = client.post("/auth/zk-login", json=base_payload)
    assert response.status_code == 200

    data = response.json()
    assert data["address"] == base_payload["suiAddress"]
    assert data["provider"] == base_payload["provider"]
    assert data["session_token"] == "signed-session-token"
    assert data["session_expires_at"] == (fixed_datetime + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)).isoformat()

    oidc_claims = data["oidc_claims"]
    assert oidc_claims["sub"] == "user-id"
    assert oidc_claims["email"] == "user@example.com"
    assert oidc_claims["nonce"] == "expected-nonce"
    assert oidc_claims["expires_at"] == exp_dt.isoformat()

    proof_summary = data["proof"]
    assert proof_summary["maxEpoch"] == base_payload["proof"]["maxEpoch"]
    assert proof_summary["publicInputsCount"] == len(base_payload["proof"]["publicInputs"])
    assert proof_summary["jwtRandomness"] == base_payload["proof"]["jwtRandomness"]


def test_zk_login_invalid_token(client, base_payload, monkeypatch):
    def fake_get_unverified_claims(_token):
        raise JWTError("token parsing failed")

    monkeypatch.setattr(auth_module.jwt, "get_unverified_claims", fake_get_unverified_claims)

    response = client.post("/auth/zk-login", json=base_payload)
    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid OIDC token: token parsing failed"


def test_zk_login_nonce_mismatch(client, base_payload, monkeypatch):
    def fake_get_unverified_claims(_token):
        return {"nonce": "unexpected"}

    monkeypatch.setattr(auth_module.jwt, "get_unverified_claims", fake_get_unverified_claims)

    response = client.post("/auth/zk-login", json=base_payload)
    assert response.status_code == 400
    assert response.json()["detail"] == "Nonce mismatch between proof and OIDC token"


def test_zk_login_expired_token(client, base_payload, fixed_datetime, monkeypatch):
    def fake_get_unverified_claims(_token):
        return {
            "exp": int((fixed_datetime - timedelta(minutes=1)).timestamp()),
            "nonce": "expected-nonce",
        }

    monkeypatch.setattr(auth_module.jwt, "get_unverified_claims", fake_get_unverified_claims)

    response = client.post("/auth/zk-login", json=base_payload)
    assert response.status_code == 401
    assert response.json()["detail"] == "OIDC token has expired"
