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

The script uses two `Standard_D2s_v4` machines (2 cores, 8 GB each) so the three pods can land on different nodes and the Service can balance across them. That size is on the allowed list. The other 2-core sizes East US allows publish at the same pay-as-you-go price, about $0.096 an hour each. AKS will not run its system pool on fewer than 2 cores. Each OS disk is 32 GB, set with `--node-osdisk-size 32`. `--node-osdisk-size-gb` is not a real argument, and the create stops before a cluster exists. After the site is up, `kubectl get pods -o wide` shows which node each pod is on.

Run the script again:

```bash
bash aks-deploy.sh
```

## After the script

The rollout line `deployment "hello-web" successfully rolled out` means the three copies are running. The next table is the load balancer. When `EXTERNAL-IP` changes from `<pending>` to an address, press Ctrl-C and paste that address into a browser as `http://`, for example `http://52.149.246.128`. Do not add a port. Do not use `https://`. Nothing is listening on 443, so the browser waits and then says the address took too long to respond. Port 80 answers. On the successful run that address returned the sample page.

Portal check, in this order:

1. Open https://portal.azure.com and search **Kubernetes services**. Open `aks-lab` in `rg-aks-lab`, East US.
2. **Workloads** shows deployment `hello-web` with 3 pods ready.
3. **Services and ingresses** shows `hello-web`, type Load balancer, and the same external IP.
4. **Resource groups** → `rg-aks-lab` also lists the public IP and the two node VMs.

`kubectl get nodes` shows both machines. `kubectl get pods -o wide` shows which machine each copy is on. The copies are small, so they can all sit on one node even when both nodes are Ready.

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

`kubectl get service hello-web --watch` waits for a public IP. Press Ctrl-C once `EXTERNAL-IP` is an address, then open `http://` that address. `https://` times out. The site is port 80.

## Scale

`replicas: 3` in `deployment.yaml` is how many copies of the pod template are running. With two nodes, Kubernetes can place those copies on both machines. The Service in `service.yaml` sends each request to one ready copy. That number stays 3 until I turn on autoscaling below. `replicas: 0` stops every copy and does not start one when a request arrives. The two nodes keep billing either way.

## AUTO-SCALING: HPA OR KEDA

Pod autoscaling changes the replica count. It does not add or remove the two VMs. Adding a VM is a different switch (cluster autoscaler), and this lab leaves that off so the monthly cost stays the two-node figure below.

This demo keeps both options commented in `aks-deploy.sh`. I turn on only one. After either one is on, I delete the `replicas: 3` line. The next `kubectl apply -f deployment.yaml` would set the count back to 3 and fight the autoscaler.

**HPA (horizontal pod autoscaler).** Built in. AKS already runs metrics-server. The container needs the cpu request already in the template (`50m`), because 70% is 70% of that request. Uncomment this line in `aks-deploy.sh`:

```bash
kubectl autoscale deployment hello-web --cpu-percent=70 --min=1 --max=6
```

CPU over 70% adds pods, up to 6. CPU under that removes pods, down to 1. It cannot go to 0, and a new HTTP request does not create a pod. The same thing as a file:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hello-web
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hello-web
  minReplicas: 1
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**KEDA.** Not built in. Uncomment this once in `aks-deploy.sh`:

```bash
az aks update --resource-group rg-aks-lab --name aks-lab --enable-keda
```

Then apply a ScaledObject. KEDA creates the HPA itself, so I do not also run `kubectl autoscale`. `minReplicaCount: 0` is allowed. A CPU trigger still does not wake on the first HTTP request, because at 0 there is no pod reporting CPU. Waking on a request needs the KEDA HTTP add-on in front of the Service. That is the AKS version of Container Apps `--min-replicas 0`.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: hello-web
spec:
  scaleTargetRef:
    name: hello-web
  minReplicaCount: 1
  maxReplicaCount: 6
  triggers:
    - type: cpu
      metricType: Utilization
      metadata:
        value: "70"
```

## COST APPROX FOR 2 NODES OR VM

Two `Standard_D2s_v4` nodes left running all month are about $140 for the VMs alone (about $0.096 an hour each). The 32 GB disks and the public load balancer add a smaller charge on top, so plan on about $150 if `rg-aks-lab` stays up for the whole month. The same reminder sits in `aks-deploy.sh` on the commented line under `--node-count 2`. Delete the group when the demo is done.

## When I am finished

```bash
az group delete --name rg-aks-lab --yes --no-wait
```
