"""A small FastAPI service used to demonstrate building a container image.

The app has no external services to call, so the image builds and runs the same
way on your machine, on the registry's build servers, and on any container host.
A root endpoint returns service metadata; a health endpoint backs container
probes and deployment smoke tests.
"""

from fastapi import FastAPI

app = FastAPI(title="Sample API", version="1.0.0")


@app.get("/")
def index() -> dict:
    return {"service": "Sample API", "version": "1.0.0"}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
