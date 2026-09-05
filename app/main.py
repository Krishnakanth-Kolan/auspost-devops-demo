import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse

APP_NAME = os.getenv("APP_NAME", "auspost-devops-demo")
APP_VERSION = os.getenv("APP_VERSION", "0.0.0-dev")

app = FastAPI(title=APP_NAME, version=APP_VERSION)


@app.get("/", tags=["application"])
def root() -> dict[str, str]:
    return {
        "application": APP_NAME,
        "version": APP_VERSION,
        "message": "AusPost Senior DevOps Engineer technical assessment demo",
    }


@app.get("/healthz", tags=["health"])
def healthz() -> JSONResponse:
    return JSONResponse(
        status_code=200,
        content={
            "status": "success",
            "application": APP_NAME,
            "version": APP_VERSION,
        },
    )


@app.get("/readyz", tags=["health"])
def readyz() -> dict[str, str]:
    return {"status": "ready", "version": APP_VERSION}
