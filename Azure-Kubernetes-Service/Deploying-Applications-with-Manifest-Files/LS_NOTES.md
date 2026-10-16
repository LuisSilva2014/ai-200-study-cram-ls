# AKS lab — free trial notes

Luis Silva · Oct 16, 2026

This lab hosts `hello-web` from `deployment.yaml` and `service.yaml`. The image is public (`mcr.microsoft.com/azuredocs/aks-helloworld:v1`), so there is no registry and Docker Desktop does not need to be running. Resource group `rg-aks-lab`, cluster `aks-lab`, location `eastus`.

This lab does not use the Container Apps environment. `sample-api2` can stay up. Both still bill until I delete their groups.

## Before I run the script

Register AKS once, wait until that command finishes, then run the script. The SSH key message is normal. That registration already succeeded on Oct 16, 2026. I do not need to register again unless a later error says `MissingSubscriptionRegistration`.

```bash
az provider register --namespace Microsoft.ContainerService --wait
bash aks-deploy.sh
```

## What the second run did

The cluster was not created. `rg-aks-lab` is still only an empty group in East US, so it is not billing for nodes. Azure tried the CLI default node size `Standard_D8ads_v5` (8 cores). This trial does not allow that size in East US.

There is no free node size for AKS. The control plane on this script is the free tier. The nodes are the bill.

The script uses two `Standard_D2s_v4` machines (2 cores, 8 GB each) so the three pods can land on different nodes and the Service can balance across them. That size is on the allowed list. The other 2-core sizes East US allows publish at the same pay-as-you-go price, about $0.096 an hour each. AKS will not run its system pool on fewer than 2 cores. Each OS disk is 32 GB. After the site is up, `kubectl get pods -o wide` shows which node each pod is on.

Run the script again:

```bash
bash aks-deploy.sh
```

Leaving `rg-aks-lab` is fine. `az group create` does not move a group, and it does not fail if the group is already there.

## If the next run fails

The script stops at the first error. Do not start a second cluster.

1. West Europe rejects new resources. The script location stays `eastus`.
2. Another `MissingSubscriptionRegistration` means that namespace is off on this trial. Register it the same way, wait, and run the script again. Do not add monitoring. Log Analytics (`Microsoft.OperationalInsights`) is not registered here.
3. Do not remove `--node-vm-size Standard_D2s_v4`. Without it, Azure asks for `Standard_D8ads_v5` again and the create fails the same way. `--node-count 2` stays so the Service can balance across two machines.
4. `QuotaExceeded` means East US does not have enough cores for two `Standard_D2s_v4` nodes (4 cores). Stop. Do not create another cluster to retry.
5. `kubectl: command not found` means the cluster may already exist and is billing. Install kubectl, then continue from the commands below. Do not run `bash aks-deploy.sh` again.

```bash
az aks install-cli
az aks get-credentials --resource-group rg-aks-lab --name aks-lab --overwrite-existing
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl rollout status deployment/hello-web
kubectl get service hello-web --watch
```

Cluster create takes several minutes. Leave it running. If `aks-lab` already exists, skip `az aks create` and use the commands above.

`kubectl get service hello-web --watch` waits for a public IP. Press Ctrl-C once `EXTERNAL-IP` is an address, then open `http://` that address. The site is port 80.

## Scale

`replicas: 3` in `deployment.yaml` is a fixed count. With two nodes, Kubernetes can place those pods on both machines. The Service in `service.yaml` is the load balancer: it sends each request to one of the ready pods. `replicas: 0` stops the pods and does not start one when a request arrives. Scale-to-zero on HTTP is the Container Apps flag `--min-replicas 0`. On AKS the two nodes keep billing while the cluster exists, even if the replica count is 0.

## COST APPROX FOR 2 NODES OR VM

Two `Standard_D2s_v4` nodes left running all month are about $140 for the VMs alone (about $0.096 an hour each). The 32 GB disks and the public load balancer add a smaller charge on top, so plan on about $150 if `rg-aks-lab` stays up for the whole month. The same reminder sits in `aks-deploy.sh` on the commented line under `--node-count 2`. Delete the group when the demo is done.

## When I am finished

```bash
az group delete --name rg-aks-lab --yes --no-wait
```
