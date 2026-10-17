#!/usr/bin/env bash
# Two-region Cosmos DB account on the free tier, for the SilvasWatch demo.
#
# PostgreSQL cannot do this cheaply: a burstable cluster cannot have a read
# replica, and a new PostgreSQL cluster is on the retirement block list.
# The free NoSQL account covers 1000 RU/s and 25 GB. This script provisions
# 400 RU/s. Two regions count that twice (800), which stays inside the 1000.
# Run from this folder.
set -euo pipefail

RESOURCE_GROUP="rg-cosmos-pg-lab"
# The pair this trial accepted: East US 2 writes, Southeast Asia reads.
LOCATION="eastus2"
REPLICA_LOCATION="southeastasia"
ACCOUNT_NAME="silvaswatchlab"
DATABASE_NAME="watches"
CONTAINER_NAME="items"

# Do not pass --location if the group already exists. A second location moves nothing
# and the command fails. The account regions are the --locations flags below.
if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
fi

create_account() {
  local write_region="$1"
  local read_region="$2"
  az cosmosdb create \
    --name "$ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --kind GlobalDocumentDB \
    --locations regionName="$write_region" failoverPriority=0 isZoneRedundant=false \
    --locations regionName="$read_region" failoverPriority=1 isZoneRedundant=false \
    --default-consistency-level Session \
    --enable-free-tier true \
    --enable-automatic-failover true \
    --enable-multiple-write-locations false
}

# A failed first try leaves the name reserved. Delete that before creating again.
ACCOUNT_STATE="$(az cosmosdb show --name "$ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --query provisioningState -o tsv 2>/dev/null || true)"
if [[ "$ACCOUNT_STATE" == "Failed" ]]; then
  az cosmosdb delete --name "$ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --yes
  ACCOUNT_STATE=""
fi

# --- Account: East US 2 writes, Southeast Asia reads ------------------------
if [[ -z "$ACCOUNT_STATE" ]]; then
  PAIRS=(
    "eastus2 southeastasia"
    "centralus southeastasia"
    "westus2 southeastasia"
    "southeastasia eastasia"
    "northeurope uksouth"
  )
  for pair in "${PAIRS[@]}"; do
    read -r LOCATION REPLICA_LOCATION <<< "$pair"
    echo "Trying $LOCATION and $REPLICA_LOCATION"
    if create_account "$LOCATION" "$REPLICA_LOCATION"; then
      break
    fi
    echo "$LOCATION and $REPLICA_LOCATION were rejected."
    az cosmosdb delete --name "$ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --yes >/dev/null 2>&1 || true
    LOCATION=""
    REPLICA_LOCATION=""
  done
  if [[ -z "$LOCATION" ]]; then
    echo "No region pair could be created."
    exit 1
  fi
fi

if ! az cosmosdb sql database show \
  --account-name "$ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DATABASE_NAME" >/dev/null 2>&1; then
  az cosmosdb sql database create \
    --account-name "$ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DATABASE_NAME" \
    --throughput 400 >/dev/null
fi

if ! az cosmosdb sql container show \
  --account-name "$ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --database-name "$DATABASE_NAME" \
  --name "$CONTAINER_NAME" >/dev/null 2>&1; then
  # Git Bash would rewrite /region into a Windows path. MSYS_NO_PATHCONV keeps it.
  MSYS_NO_PATHCONV=1 az cosmosdb sql container create \
    --account-name "$ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --database-name "$DATABASE_NAME" \
    --name "$CONTAINER_NAME" \
    --partition-key-path "/region" >/dev/null
fi

ENDPOINT="$(az cosmosdb show \
  --name "$ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query documentEndpoint -o tsv)"
KEY="$(az cosmosdb keys list \
  --name "$ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --type keys \
  --query primaryMasterKey -o tsv)"

cat > .env << EOF
COSMOS_ENDPOINT=$ENDPOINT
COSMOS_KEY=$KEY
COSMOS_WRITE_REGION=$LOCATION
COSMOS_READ_REGION=$REPLICA_LOCATION
EOF

echo "Account:    $ACCOUNT_NAME"
echo "Regions:    $LOCATION (writes) and $REPLICA_LOCATION (reads)"
echo "Database:   $DATABASE_NAME    Container: $CONTAINER_NAME    400 RU/s"
echo "Wrote .env. Do not commit it."
echo "Open SilvasWatch.sln in Visual Studio, configuration Release."
echo "Or: dotnet run --project SilvasWatch.Api -c Release"

# --- PostgreSQL path. Leave commented. It cannot do two regions this cheaply.
# Burstable compute does not allow a read replica. A second region needs a
# larger node and about another $21 a month, and new PostgreSQL clusters are
# blocked while that service is retired.
# az provider register --namespace Microsoft.DBforPostgreSQL --wait
# az cosmosdb postgres cluster create \
#   --name ls-citus-lab \
#   --resource-group "$RESOURCE_GROUP" \
#   --location "$LOCATION" \
#   --coordinator-v-cores 1 \
#   --coordinator-server-edition BurstableMemoryOptimized \
#   --coordinator-storage 32768 \
#   --coord-public-ip-access true \
#   --node-count 0 \
#   --enable-shards-on-coord true \
#   --enable-ha false \
#   --administrator-login-password "$PG_PASSWORD"

# Do not raise throughput above 400. Two regions make that 800 RU/s.
# The free tier stops at 1000 RU/s. Autoscale at 1000 would be 2000 across two
# regions and would start billing.
# --max-throughput 1000

# --- Delete the group when the lab is finished -----------------------------
# az group delete --name "$RESOURCE_GROUP" --yes --no-wait
