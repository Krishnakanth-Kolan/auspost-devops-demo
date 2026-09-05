from fastapi.testclient import TestClient
from app.main import APP_NAME, APP_VERSION, app

client = TestClient(app)


def test_root() -> None:
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["application"] == APP_NAME
    assert body["version"] == APP_VERSION


def test_healthz() -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {
        "status": "success",
        "application": APP_NAME,
        "version": APP_VERSION,
    }


def test_readyz() -> None:
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"
