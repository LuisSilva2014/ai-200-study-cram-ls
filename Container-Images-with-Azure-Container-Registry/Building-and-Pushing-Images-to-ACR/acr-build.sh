#!/usr/bin/env bash
# Build the sample image and store it in this lab's own registry.
# This script does not host the app. Hosting sample-api2 is the other lab.
#
# Run this from the folder that holds the Dockerfile, app.py, and
# requirements.txt. On Windows, run it from Git Bash. Docker Desktop must be
# running. This free trial blocks 'az acr build' (TasksOperationsNotAllowed).
set -euo pipefail

# --- Settings — edit these for your environment -----------------------------
RESOURCE_GROUP="rg-acr-lab"
LOCATION="eastus"
# Own registry for sample-api. Do not reuse the Container Apps lab registry.
ACR_NAME="acrlabapi1"
IMAGE_NAME="sample-api"
IMAGE_TAG="v1"

# --- 1. Resource group ------------------------------------------------------
# East US. West Europe rejected new resources on this free trial.
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# --- 2. Create the registry (Basic tier is enough for this lab) -------------
if ! az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --location "$LOCATION" \
    --sku Basic
fi

# --- 3. Build and push locally ----------------------------------------------
# Do not create a Container Apps environment here. This trial allows only one,
# and sample-api2 uses it. This lab only fills its own warehouse.
az acr login --name "$ACR_NAME"
docker build \
  -t "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" \
  -t "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest" \
  .
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest"

# --- 4. Verify the image landed in the registry -----------------------------
az acr repository list --name "$ACR_NAME" --output table
az acr repository show-tags \
  --name "$ACR_NAME" \
  --repository "$IMAGE_NAME" \
  --output table

echo "Pushed ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# --- Clean up when you are finished -----------------------------------------
# Deleting the resource group removes the registry and every image in it.
# az group delete --name "$RESOURCE_GROUP" --yes --no-wait
