#!/usr/bin/env bash
# Create a small AKS cluster and deploy a sample app from manifest files.
#
# The flow: create a resource group, create the cluster, point kubectl at it,
# then apply the Deployment and Service. The app image is public, so no registry
# is involved. Run from this folder (the one holding deployment.yaml and
# service.yaml).
set -euo pipefail

RESOURCE_GROUP="rg-aks-lab"
LOCATION="westeurope"
CLUSTER_NAME="aks-lab"

# --- 1. Resource group ------------------------------------------------------
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# --- 2. Cluster -------------------------------------------------------------
# Two nodes are enough to watch pods spread across a cluster. --generate-ssh-keys
# creates an SSH key pair for the nodes if you do not have one already. AKS
# creates a managed identity for the cluster by default.
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --node-count 2 \
  --generate-ssh-keys

# --- 3. Point kubectl at the cluster ----------------------------------------
# Merges the cluster's credentials into your kubeconfig and makes it current, so
# every later kubectl command targets this cluster.
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

# --- 4. Deploy the manifests ------------------------------------------------
# apply is declarative: it creates the objects, and re-running it after an edit
# updates them in place to match the file.
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# --- 5. Wait for the rollout, then for the public IP ------------------------
kubectl rollout status deployment/hello-web

echo "Waiting for the load balancer to assign an external IP (press Ctrl-C once EXTERNAL-IP is set)..."
kubectl get service hello-web --watch

# --- Clean up when you are finished -----------------------------------------
# az group delete --name "$RESOURCE_GROUP" --yes --no-wait
