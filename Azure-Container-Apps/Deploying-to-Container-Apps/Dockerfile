# Build a small FastAPI image on a slim Python base.
FROM python:3.11-slim

# Stream logs straight to the container output, and skip writing .pyc files.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Install dependencies first, in their own layer, so this step is cached and
# only re-runs when requirements.txt changes — not on every code edit.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code.
COPY app.py .

# Run as an unprivileged user rather than root.
RUN useradd --create-home --uid 1000 appuser
USER appuser

# Document the port the app listens on. Container Apps routes ingress here.
EXPOSE 8000

# Start the API. 0.0.0.0 makes it reachable from outside the container.
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
