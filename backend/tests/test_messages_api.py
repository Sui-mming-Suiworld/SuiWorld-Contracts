import os
from typing import List

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("DATABASE_URL", "postgresql://user:pass@localhost/db")
os.environ.setdefault("SECRET_KEY", "bootstrap-secret")
os.environ.setdefault("ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "15")

from app.main import app


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_list_messages_returns_home_feed(client: TestClient) -> None:
    response = client.get("/messages")
    assert response.status_code == 200

    payload = response.json()
    assert [item["id"] for item in payload] == ["msg-001", "msg-002", "msg-003", "msg-004"]

    first = payload[0]
    assert first["metrics"]["displayed_status"] == "NORMAL"
    assert first["metrics"]["likes_to_threshold"] == 1
    assert first["metrics"]["alerts_to_threshold"] == 19

    hyped = payload[-1]
    assert hyped["metrics"]["displayed_status"] == "HYPED"
    assert hyped["metrics"]["likes_to_threshold"] is None
    assert hyped["metrics"]["alerts_to_threshold"] is None


def test_list_messages_search_matches_content_and_tags(client: TestClient) -> None:
    response = client.get("/messages", params={"search": "vault"})
    assert response.status_code == 200

    payload = response.json()
    assert [item["id"] for item in payload] == ["msg-002"]


def test_list_messages_tag_filter_modes(client: TestClient) -> None:
    and_params = [
        ("tags", "restaking"),
        ("tags", "strategy"),
        ("tag_mode", "and"),
    ]
    response = client.get("/messages", params=and_params)
    assert response.status_code == 200
    assert [item["id"] for item in response.json()] == ["msg-001"]

    or_params = [
        ("tags", "restaking"),
        ("tags", "risk"),
        ("tag_mode", "or"),
    ]
    response = client.get("/messages", params=or_params)
    assert response.status_code == 200
    assert [item["id"] for item in response.json()] == ["msg-001", "msg-003"]


def test_list_messages_sort_and_status_derivation(client: TestClient) -> None:
    response = client.get("/messages", params={"sort": "likes"})
    assert response.status_code == 200

    payload = response.json()
    assert [item["id"] for item in payload] == ["msg-002", "msg-001", "msg-004", "msg-003"]

    top_entry = payload[0]["metrics"]
    assert top_entry["base_status"] == "NORMAL"
    assert top_entry["displayed_status"] == "UNDER_REVIEW"
    assert top_entry["status_reason"] == "likes_threshold"
    assert top_entry["likes_to_threshold"] == 0

    alert_entry = payload[-1]["metrics"]
    assert alert_entry["displayed_status"] == "UNDER_REVIEW"
    assert alert_entry["status_reason"] == "alerts_threshold"
    assert alert_entry["alerts_to_threshold"] == 0


def test_list_messages_search_is_case_insensitive(client: TestClient) -> None:
    response = client.get("/messages", params={"search": "BURNER"})
    assert response.status_code == 200

    payload = response.json()
    assert [item["id"] for item in payload] == ["msg-003"]
