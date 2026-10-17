#!/usr/bin/env bash
# Two functions on the Consumption plan (serverless). Azure runs one when its request arrives.
# There is no Express server and no VM left running (serverless). The plan scales to zero.
# Run this yourself from Git Bash, in this folder. Do not use West Europe.
set -euo pipefail

RESOURCE_GROUP="rg-func-lab"
LOCATION="eastus"
STORAGE_ACCOUNT="silvaswatchfuncsa"
FUNCTION_APP="silvaswatch-func"
SUBSCRIPTION_NAME="Azure subscription 1"

# The free trial is this subscription. Set it so a stale default cannot point somewhere else.
az account set --subscription "$SUBSCRIPTION_NAME"
echo "Subscription: $SUBSCRIPTION_NAME"
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT/SilvasWatch.Function"

# A missing Microsoft.Storage registration makes the name check say SubscriptionNotFound.
# That message is wrong. The free trial subscription is fine. Register the provider.
for namespace in Microsoft.Storage Microsoft.Web; do
  state="$(az provider show --namespace "$namespace" --query registrationState -o tsv)"
  if [[ "$state" != "Registered" ]]; then
    echo "Registering $namespace"
    az provider register --namespace "$namespace" --wait
  fi
done

if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
fi

# The host stores its own files in this account. The movie does not go here.
if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  AVAILABLE="$(az storage account check-name --name "$STORAGE_ACCOUNT" --query nameAvailable -o tsv)"
  if [[ "$AVAILABLE" != "true" ]]; then
    echo "Storage name $STORAGE_ACCOUNT is taken. Change STORAGE_ACCOUNT at the top of this script."
    exit 1
  fi
  az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false >/dev/null
fi

# Consumption plan: pay per run, scale to zero. Node 22. No Application Insights.
# App Insights would ask for Log Analytics, and that provider is not registered on this trial.
# To play with another language, delete silvaswatch-func first. Create is skipped while it exists.
# Then replace the node / 22 pair below with one of these pairs, and deploy that language's files.
#   python           3.12
#   dotnet-isolated  10
if ! az functionapp show --name "$FUNCTION_APP" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az functionapp create \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --storage-account "$STORAGE_ACCOUNT" \
    --consumption-plan-location "$LOCATION" \
    --os-type Linux \
    --runtime node \
    --runtime-version 22 \
    --functions-version 4 \
    --disable-app-insights true >/dev/null
fi

# Remote build runs npm install in Azure. The zip does not carry node_modules.
# Git Bash tar does not write a real zip on this machine, so Python writes it.
ZIP="$ROOT/deploy.zip"
rm -f "$ZIP"
python - "$(cygpath -w "$APP_DIR")" "$(cygpath -w "$ZIP")" << 'PY'
import os, sys, zipfile
root, dest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for dirpath, _, files in os.walk(root):
        for name in files:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root).replace("\\", "/")
            archive.write(full, rel)
PY

az functionapp deployment source config-zip \
  --name "$FUNCTION_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --src "$ZIP" \
  --build-remote true

rm -f "$ZIP"

HOST="$(az functionapp show --name "$FUNCTION_APP" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)"
echo "Function app:  $FUNCTION_APP"
echo "Health:        https://$HOST/api/health"
echo "Play:          https://$HOST/api/watch"
echo "Poster:        https://$HOST/api/thumbnail"
echo "The first call after idle can take a few seconds. That is the cold start."
echo "Open the health URL in a browser. It is a GET."

# The Consumption plan already sleeps when nobody calls it. Compute is not billed while it is idle.
# Stop makes a browser open fail, so the app cannot wake up. Start allows the next call to wake it.
# az functionapp stop --name "$FUNCTION_APP" --resource-group "$RESOURCE_GROUP"
# az functionapp start --name "$FUNCTION_APP" --resource-group "$RESOURCE_GROUP"

# --- Delete the group when the lab is finished -----------------------------
# az group delete --name "$RESOURCE_GROUP" --yes --no-wait
