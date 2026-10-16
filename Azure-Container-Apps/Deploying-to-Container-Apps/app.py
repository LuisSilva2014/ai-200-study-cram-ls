"""A small FastAPI service for demonstrating deployment to a managed container host.

The point of this app is configuration, not features. It reads two values from the
environment and echoes them back, so once it runs on Azure Container Apps you can see
exactly how a plain environment variable and a secret reach the running container
without rebuilding the image. The same image therefore behaves differently per
deployment based only on the settings the host injects.
"""

import os

from fastapi import FastAPI

app = FastAPI(title="Sample API", version="1.0.0")


@app.get("/")
def index() -> dict:
    # Read on each request so the response reflects the environment the host
    # injected into this revision — no rebuild needed to change it.
    return {
        "message": os.getenv("APP_GREETING", "Hello from a container"),
        "region": os.getenv("APP_REGION", "unknown"),
    }


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
