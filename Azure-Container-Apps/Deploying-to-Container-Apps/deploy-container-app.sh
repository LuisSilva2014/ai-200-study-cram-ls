#!/usr/bin/env bash
# Build the sample image and deploy it to Azure Container Apps with
# configuration supplied by the host: one plain environment variable and one
# value held as a Container Apps secret.
#
# Run this from the folder that holds the Dockerfile, app.py, and
# requirements.txt. On Windows, run it from Git Bash. Docker Desktop must be
# running. The Container Apps commands ship in the core Azure CLI; if your CLI is
# older than 2.62, run:  az extension add --name containerapp --upgrade
#
# Free-trial changes are explained in LS_NOTES.md in this folder.
set -euo pipefail

# --- Settings — edit these for your environment -----------------------------
RESOURCE_GROUP="rg-aca-lab"
LOCATION="eastus"
# ACR_NAME="acalab${RANDOM}"          # globally unique, lowercase alphanumeric
ACR_NAME="acalab26852"
# This trial allows only one Container Apps environment in the whole subscription.
# Delete sample-api and aca-env in rg-acr-lab before this script creates its own.
# Passing a full resource ID fails in Git Bash: it rewrites /subscriptions into
# a Windows path. Use the environment name in this resource group instead.
ENVIRONMENT="aca-env"
# sample-api is the ACR lab. This lab is sample-api2. AKS is sample-api3.
APP_NAME="sample-api2"
IMAGE_NAME="sample-api2"
IMAGE_TAG="v1"

# --- 1. Resource group ------------------------------------------------------
# East US. West Europe rejected new resources on this free trial.
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# --- 2. Registry, then a local build and push -------------------------------
# Do not use 'az acr build' here. This free trial blocks ACR Tasks
# (TasksOperationsNotAllowed). Docker Desktop builds the image and pushes it.
# Skip create when the name is already in the group (acalab16489).
if ! az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --location "$LOCATION" \
    --sku Basic
fi

az acr login --name "$ACR_NAME"
docker build -t "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" .
docker push "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"

# The Feature lab uses the registry's admin user for a one-command pull. It is
# the quickest path for a throwaway lab; production pulls with a managed
# identity instead (covered in the securing section). Enable it here:
az acr update --name "$ACR_NAME" --admin-enabled true
ACR_USER=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

# --- 3. This lab's own environment ------------------------------------------
# This trial allows only one Container Apps environment. If sample-api is
# already hosted, delete that app and its environment before this step.
OTHER_ENV=$(az containerapp env list --query "[?resourceGroup!='${RESOURCE_GROUP}'].name" -o tsv)
if [ -n "$OTHER_ENV" ]; then
  echo "Stop. Another Container Apps environment is still up: ${OTHER_ENV}"
  echo "Delete that app and its environment, then run this script again."
  exit 1
fi
if ! az containerapp env show --name "$ENVIRONMENT" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az containerapp env create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ENVIRONMENT" \
    --location "$LOCATION" \
    --logs-destination none
fi

# --- 4. Create the app ------------------------------------------------------
# --secrets stores 'app-region' inside the app; --env-vars then passes a plain
# value (APP_GREETING) and a secret-backed value (APP_REGION=secretref:...).
# --target-port matches the port uvicorn listens on; --ingress external gives
# the app a public HTTPS URL.
if ! az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --environment "$ENVIRONMENT" \
  --image "${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}" \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --registry-username "$ACR_USER" \
  --registry-password "$ACR_PASS" \
  --target-port 8000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --secrets "app-region=eastus" \
  --env-vars "APP_GREETING=Hello from Azure Container Apps" "APP_REGION=secretref:app-region"
fi

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
