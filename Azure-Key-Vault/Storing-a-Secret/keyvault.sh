#!/usr/bin/env bash
# Store one demo secret in Key Vault, then point the function app at it.
# The secret value stays in the vault. The function app only stores the secret's name.
# Run this yourself from Git Bash, in this folder. Do not use West Europe.
set -euo pipefail

SUBSCRIPTION_NAME="Azure subscription 1"
RESOURCE_GROUP="rg-keyvault-lab"
LOCATION="eastus"
VAULT_NAME="silvaswatchkv"
SECRET_NAME="watch-api-key"
SECRET_VALUE="demo-play-key"
FUNCTION_GROUP="rg-func-lab"
FUNCTION_APP="silvaswatch-func"

az account set --subscription "$SUBSCRIPTION_NAME"
echo "Subscription: $SUBSCRIPTION_NAME"

state="$(az provider show --namespace Microsoft.KeyVault --query registrationState -o tsv)"
if [[ "$state" != "Registered" ]]; then
  echo "Registering Microsoft.KeyVault"
  az provider register --namespace Microsoft.KeyVault --wait
fi

if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
fi

# Standard tier. Software protection. No HSM key, so no monthly key charge.
if ! az keyvault show --name "$VAULT_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az keyvault create \
    --name "$VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku standard \
    --enable-rbac-authorization true \
    --retention-days 7 >/dev/null
fi

VAULT_ID="$(az keyvault show --name "$VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"
USER_ID="$(az ad signed-in-user show --query id -o tsv)"

assign_role() {
  local role="$1"
  local principal="$2"
  local kind="$3"
  local found
  # Git Bash rewrites a scope that starts with /subscriptions. MSYS_NO_PATHCONV keeps it.
  found="$(MSYS_NO_PATHCONV=1 az role assignment list --scope "$VAULT_ID" --assignee-object-id "$principal" --role "$role" --query "[0].id" -o tsv)"
  if [[ -z "$found" ]]; then
    MSYS_NO_PATHCONV=1 az role assignment create \
      --role "$role" \
      --assignee-object-id "$principal" \
      --assignee-principal-type "$kind" \
      --scope "$VAULT_ID" >/dev/null
  fi
}

# The account that runs this script needs this role or secret set is forbidden.
assign_role "Key Vault Secrets Officer" "$USER_ID" "User"

echo "Waiting for the secret role to apply."
for attempt in 1 2 3 4 5 6; do
  if az keyvault secret set --vault-name "$VAULT_NAME" --name "$SECRET_NAME" --value "$SECRET_VALUE" >/dev/null; then
    break
  fi
  if [[ "$attempt" == "6" ]]; then
    echo "The secret role is not active yet. Run this script again in a minute."
    exit 1
  fi
  sleep 10
done

# The function lab can read the secret without a copy of the value in its files.
if az functionapp show --name "$FUNCTION_APP" --resource-group "$FUNCTION_GROUP" >/dev/null 2>&1; then
  PRINCIPAL="$(az functionapp identity assign --name "$FUNCTION_APP" --resource-group "$FUNCTION_GROUP" --query principalId -o tsv)"
  assign_role "Key Vault Secrets User" "$PRINCIPAL" "ServicePrincipal"
  az functionapp config appsettings set \
    --name "$FUNCTION_APP" \
    --resource-group "$FUNCTION_GROUP" \
    --settings "WATCH_API_KEY=@Microsoft.KeyVault(VaultName=${VAULT_NAME};SecretName=${SECRET_NAME})" >/dev/null
  echo "WATCH_API_KEY on $FUNCTION_APP points at $VAULT_NAME. The value stays in the vault."
  echo "Open https://${FUNCTION_APP}.azurewebsites.net/api/health after a minute."
else
  echo "$FUNCTION_APP is not in $FUNCTION_GROUP. The secret is still in the vault."
fi

echo "Vault:  $VAULT_NAME"
echo "Secret: $SECRET_NAME"
echo "Value:  $SECRET_VALUE"
echo "That value is for the lab. It is not a real password."

# Soft delete keeps the vault name for 7 days. Purge frees the name sooner.
# az keyvault delete --name "$VAULT_NAME" --resource-group "$RESOURCE_GROUP"
# az keyvault purge --name "$VAULT_NAME"

# --- Delete the group when the lab is finished -----------------------------
# az group delete --name "$RESOURCE_GROUP" --yes --no-wait
