#!/usr/bin/env bash
# Build the sample image in the cloud and deploy it to Azure Container Apps with
# configuration supplied by the host: one plain environment variable and one
# value held as a Container Apps secret.
#
# Run this from the folder that holds the Dockerfile, app.py, and
# requirements.txt. On Windows, run it from Git Bash, WSL, or the Azure Cloud
# Shell. The Container Apps commands ship in the core Azure CLI; if your CLI is
# older than 2.62, run:  az extension add --name containerapp --upgrade
set -euo pipefail

# --- Settings — edit these for your environment -----------------------------
RESOURCE_GROUP="rg-aca-lab"
LOCATION="westeurope"
ACR_NAME="acalab${RANDOM}"          # globally unique, lowercase alphanumeric
ENVIRONMENT="aca-env"
APP_NAME="sample-api"
IMAGE_TAG="v1"

# --- 1. Resource group ------------------------------------------------------
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# --- 2. Registry and a cloud build of the image -----------------------------
# 'az acr build' builds on Azure's servers and pushes — no local Docker daemon.
az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic
az acr build \
  --registry "$ACR_NAME" \
  --image "${APP_NAME}:${IMAGE_TAG}" \
  --file Dockerfile \
  .

# The Feature lab uses the registry's admin user for a one-command pull. It is
# the quickest path for a throwaway lab; production pulls with a managed
# identity instead (covered in the securing section). Enable it here:
az acr update --name "$ACR_NAME" --admin-enabled true
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

# --- 3. Container Apps environment ------------------------------------------
# The environment is the shared boundary (networking, logs) that apps run in.
az containerapp env create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ENVIRONMENT" \
  --location "$LOCATION"

# --- 4. Create the app ------------------------------------------------------
# --secrets stores 'app-region' inside the app; --env-vars then passes a plain
# value (APP_GREETING) and a secret-backed value (APP_REGION=secretref:...).
# --target-port matches the port uvicorn listens on; --ingress external gives
# the app a public HTTPS URL.
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --environment "$ENVIRONMENT" \
  --image "${ACR_NAME}.azurecr.io/${APP_NAME}:${IMAGE_TAG}" \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --registry-username "$ACR_USER" \
  --registry-password "$ACR_PASS" \
  --target-port 8000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --secrets "app-region=westeurope" \
  --env-vars "APP_GREETING=Hello from Azure Container Apps" "APP_REGION=secretref:app-region"

# --- 5. Print the public URL ------------------------------------------------
FQDN=$(az containerapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --query properties.configuration.ingress.fqdn -o tsv)

echo "App URL:    https://${FQDN}"
echo "Try:        curl -s https://${FQDN}/"
echo "Health:     curl -s https://${FQDN}/health"

# --- Clean up when you are finished -----------------------------------------
# Deleting the resource group removes the app, the environment, and the registry.
# az group delete --name "$RESOURCE_GROUP" --yes --no-wait
