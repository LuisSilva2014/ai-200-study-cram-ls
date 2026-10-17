#
#!/usr/bin/env bash
# Create a small AKS cluster and deploy a sample app from manifest files.
#
# The flow: create a resource group, create the cluster, point kubectl at it,
# then apply the Deployment and Service. The app image is public, so no registry
# is involved. Run from this folder (the one holding deployment.yaml and
# service.yaml).
set -euo pipefail

RESOURCE_GROUP="rg-aks-lab"
LOCATION="eastus"
CLUSTER_NAME="aks-lab"

# --- 1. Resource group ------------------------------------------------------
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# --- 2. Cluster -------------------------------------------------------------
# Trial: register AKS once before this script. See LS_NOTES.md.
# az provider register --namespace Microsoft.ContainerService --wait
# Two nodes so the pods can land on different machines and the Service can
# balance across them. AKS has no free node. The control plane is free.
# This trial rejects the CLI default Standard_D8ads_v5 (8 cores). Standard_D2s_v4
# is a 2-core size East US allows, at the same published price as the other
# 2-core sizes on the allowed list. The 32 GB disk is the small OS disk.
# See LS_NOTES.md. --generate-ssh-keys creates a key pair if you do not have one.
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --node-count 2 \
  --node-vm-size Standard_D2s_v4 \
  --node-osdisk-size 32 \
  --generate-ssh-keys
  # --node-count 2 \  # two nodes left running all month cost about $150. Delete rg-aks-lab when the demo is done.

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

# --- Optional autoscaling. Leave commented. See LS_NOTES.md. ----------------
# replicas: 3 stays fixed until one of these is turned on. Do not turn on both.
# HPA (built in). Scales the pod count on CPU. Min is 1, so it cannot go to 0.
# kubectl autoscale deployment hello-web --cpu-percent=70 --min=1 --max=6
# KEDA (install once). A ScaledObject can use min 0. CPU at 0 does not wake on
# HTTP. Waking on a request needs the KEDA HTTP add-on.
# az aks update --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --enable-keda

# --- 5. Wait for the rollout, then for the public IP ------------------------
kubectl rollout status deployment/hello-web

echo "Waiting for the load balancer to assign an external IP (press Ctrl-C once EXTERNAL-IP is set)..."
kubectl get service hello-web --watch

# --- Clean up when you are finished -----------------------------------------
# az group delete --name "$RESOURCE_GROUP" --yes --no-wait
