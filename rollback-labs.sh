#!/usr/bin/env bash
# Remove the study labs. Skip a group that is already gone.
# Does not touch deaf-assistant-speech or NetworkWatcherRG.
# Run from the repo root: bash rollback-labs.sh
set -euo pipefail

SUBSCRIPTION_NAME="Azure subscription 1"
VAULT_NAME="silvaswatchkv"
AKS_GROUP="rg-aks-lab"
AKS_NODES="MC_rg-aks-lab_aks-lab_eastus"

# Do not name this array GROUPS. Git Bash already uses that name for Windows group ids.
LAB_GROUPS=(
  "rg-acr-lab"
  "rg-aca-lab"
  "rg-aks-lab"
  "rg-cosmos-pg-lab"
  "rg-func-lab"
  "rg-keyvault-lab"
)

az account set --subscription "$SUBSCRIPTION_NAME"
echo "Subscription: $SUBSCRIPTION_NAME"

group_exists() {
  local name="$1"
  local found
  found="$(az group exists --name "$name" -o tsv)"
  [[ "$found" == "true" ]]
}

delete_group() {
  local name="$1"
  if ! group_exists "$name"; then
    echo "Skip $name. It is not there."
    return 0
  fi
  echo "Deleting $name"
  if ! az group delete --name "$name" --yes --no-wait; then
    if group_exists "$name"; then
      echo "Delete of $name did not start."
      return 1
    fi
    echo "Skip $name. It disappeared during delete."
  fi
}

for name in "${LAB_GROUPS[@]}"; do
  delete_group "$name"
done

echo "Waiting until the lab groups are gone."
for ((attempt=1; attempt<=60; attempt++)); do
  still=0
  for name in "${LAB_GROUPS[@]}"; do
    if group_exists "$name"; then
      echo "Still deleting $name"
      still=1
    fi
  done

  if group_exists "$AKS_NODES"; then
    if group_exists "$AKS_GROUP"; then
      echo "Still deleting $AKS_NODES with the AKS group"
    else
      delete_group "$AKS_NODES"
    fi
    still=1
  fi

  if [[ "$still" == "0" ]]; then
    break
  fi
  if [[ "$attempt" == "60" ]]; then
    echo "A lab group is still deleting. Run this script again."
    exit 1
  fi
  sleep 30
done

for attempt in 1 2 3 4 5 6 7 8 9 10; do
  deleted="$(az keyvault list-deleted --query "[?name=='${VAULT_NAME}'].name" -o tsv || true)"
  if [[ "$deleted" == "$VAULT_NAME" ]]; then
    echo "Purging soft-deleted vault $VAULT_NAME"
    az keyvault purge --name "$VAULT_NAME" || echo "Vault purge was already finished."
    break
  fi
  if ! group_exists "rg-keyvault-lab"; then
    echo "Skip vault purge. $VAULT_NAME is not in the soft-delete list."
    break
  fi
  if [[ "$attempt" == "10" ]]; then
    echo "Skip vault purge. $VAULT_NAME is not in the soft-delete list."
  else
    sleep 15
  fi
done

echo "Lab groups are gone."
