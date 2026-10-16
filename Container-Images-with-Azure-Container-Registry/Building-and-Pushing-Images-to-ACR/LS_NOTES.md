# Azure Container Registry — portal or CLI

Luis Silva notes for `1. Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR`
Collected on: Oct 16, 2026

The same steps can be done in the Azure portal:

https://portal.azure.com/#browse/Microsoft.ContainerRegistry%2Fregistries

I used the Azure CLI and a bash script instead, so the steps can be reused later.

## Before running the script

1. Install the Azure CLI. Without it, Bash reports `az: command not found`.
   - All platforms: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
   - Windows 64-bit installer: https://aka.ms/installazurecliwindowsx64
2. Sign in: `az login`
3. Run the bash script.

## Free trial ($200 credit) — ACR lab

The credit pays for the registry. It does not enable ACR Tasks. `az acr build` fails with `TasksOperationsNotAllowed`. West Europe also rejected a new registry, so the script uses East US.

Registry already created: `acrlab26178` in `rg-acr-lab`. Do not re-run `acr-build.sh`. It creates another registry and fails the same way.

## Build the image with Docker Desktop

1. Open **Docker Desktop** from the Start menu.
2. Wait until the whale icon says **Engine running**. If `docker build` reports `dockerDesktopLinuxEngine` or `cannot find the file specified`, the engine is still starting.
3. In Git Bash, go to the folder that holds the Dockerfile:

```bash
cd Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR
```

4. Sign the Docker client in to the registry, build, and push:

```bash
az acr login --name acrlab26178
docker build -t acrlab26178.azurecr.io/sample-api:v1 -t acrlab26178.azurecr.io/sample-api:latest .
docker push acrlab26178.azurecr.io/sample-api:v1
docker push acrlab26178.azurecr.io/sample-api:latest
az acr repository show-tags --name acrlab26178 --repository sample-api --output table
```

## When finished

Stop the charge against the $200 credit:

```bash
az group delete --name rg-acr-lab --yes --no-wait
```

## Interview memo — shelf vs runner

A resource group is the folder. Deleting it removes everything inside. The registry is a shelf in that folder. Container Apps and Functions are runners: they pull one tag off the shelf and execute it.

```text
Subscription
└── Resource group
    ├── Container Registry          stores images, does not run them
    │   └── sample-api              one app
    │       ├── v1                  one build
    │       └── latest              another label on a build
    ├── Container Apps environment  shared boundary: network and logs
    │   └── Container App           pulls one tag and serves traffic
    └── Function App                starts on an event, then can stop
        └── functions               HTTP, timer, queue
```

- **Container Registry.** Private Docker registry. A repository is one app. A tag is one build (`sample-api:v1`). Pushing an image does not start the app.
- **Container Apps.** A service host. The environment is the shared folder; each Container App is one running service inside it. It always runs a container, usually pulled from the registry. It can scale, including down to zero.
- **Functions.** Event host. A request, a timer, or a queue message starts the work. The usual deploy is code, not an image. The registry is involved only when that function is packaged as a custom container.
- **Same image, different host.** Container Apps for a service, Functions for an event, AKS when you run the cluster yourself. The registry does not change.
