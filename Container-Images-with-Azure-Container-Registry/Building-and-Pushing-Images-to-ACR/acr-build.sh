#!/usr/bin/env bash
# Build a container image in the cloud with ACR and push it to your registry —
# no local Docker daemon required. 'az acr build' uploads the build context,
# builds the image on Azure's build servers, and pushes it for you.
#
# Run this from the folder that holds the Dockerfile, app.py, and
# requirements.txt. On Windows, run it from Git Bash, WSL, or the Azure Cloud
# Shell.
set -euo pipefail

# --- Settings — edit these for your environment -----------------------------
RESOURCE_GROUP="rg-acr-lab"
LOCATION="eastus"
# Registry names are global and must be lowercase alphanumeric, 5–50 characters.
# $RANDOM keeps the name unique so the lab does not collide with an existing one.
ACR_NAME="acrlab${RANDOM}"
IMAGE_NAME="sample-api"
IMAGE_TAG="v1"

# --- 1. Resource group ------------------------------------------------------
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# --- 2. Create the registry (Basic tier is enough for this lab) -------------
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --location "$LOCATION" \
  --sku Basic

# --- 3. Build and push in one step, on ACR's build servers ------------------
# Two --image flags tag the same build with a version and 'latest'. The trailing
# '.' is the build context: the current folder, sent to the cloud for the build.
az acr build \
  --registry "$ACR_NAME" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --image "${IMAGE_NAME}:latest" \
  --file Dockerfile \
  .

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
