# Build vs deploy — image in the warehouse

Luis Silva notes for `1. Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR`
Collected on: Oct 16, 2026


This lab only built the image and stored it in the warehouse (Azure Container Registry). It did not deploy it, and it did not host it. No server is running the API, and there is no URL yet.

That matches the old split you already know: build the files first, copy them to IIS later. Here, the copy-to-IIS step has not happened.

## What is in the warehouse

`app.py` is a small Python web API. `docker build` packed the app, Python 3.11, and its libraries into one image. That image is the packaged build, the way a `dotnet publish` folder is the packaged build.

`docker push` stored it in the warehouse under two names:

- `acrlab26178.azurecr.io/sample-api:v1`
- `acrlab26178.azurecr.io/sample-api:latest`

Both names point at the same build. The warehouse is holding the package. It is not serving HTTP.

| Step | .NET on IIS | This lab |
| --- | --- | --- |
| Write | ASP.NET Web API | `app.py` |
| Build | `dotnet publish` | `docker build` |
| Store | Binaries on disk or a file share | `docker push` into the registry |
| Deploy and host | Copy to IIS and start the site | Not done |

## Test on your PC

Docker Desktop must be running. This starts the image on your machine only. `v1` is the tag. Change it to `latest` if you want that name instead.

```bash
docker run --rm -p 8000:8000 acrlab26178.azurecr.io/sample-api:v1
```

Leave that window open. In a browser:

- http://localhost:8000
- http://localhost:8000/health

Ctrl+C stops it. The local test already answered 200 on `/` and `/health`. Nothing in Azure is hosting the API.

## Host one tag that is already in the warehouse

This is the IIS step. You pick a tag that is already built (`v1`) and Azure Container Apps pulls that tag, starts it, and gives you an HTTPS address. The address uses port 443. Azure forwards traffic to port 8000 inside the container.

The first try stopped at the environment. Azure tried to attach a Log Analytics workspace, and this free trial is not registered for that service (`Microsoft.OperationalInsights`). The environment `aca-env` was not created, so the app create and the URL lookup had nothing to find. The registry admin user is already turned on.

Run this from Git Bash. `--logs-destination none` skips Log Analytics. It uses East US and draws on the $200 credit until you delete the group.

```bash
az provider register -n Microsoft.App --wait

ACR_USER=$(az acr credential show --name acrlab26178 --query username -o tsv)
ACR_PASS=$(az acr credential show --name acrlab26178 --query "passwords[0].value" -o tsv)

az containerapp env create \
  --resource-group rg-acr-lab \
  --name aca-env \
  --location eastus \
  --logs-destination none

az containerapp create \
  --resource-group rg-acr-lab \
  --name sample-api \
  --environment aca-env \
  --image acrlab26178.azurecr.io/sample-api:v1 \
  --registry-server acrlab26178.azurecr.io \
  --registry-username "$ACR_USER" \
  --registry-password "$ACR_PASS" \
  --target-port 8000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 1

az containerapp show \
  --resource-group rg-acr-lab \
  --name sample-api \
  --query properties.configuration.ingress.fqdn -o tsv
```

The last command prints the host name. The site is:

- `https://<that-name>`
- `https://<that-name>/health`

To promote a different tag later, run `az containerapp update` with the new image name, for example `acrlab26178.azurecr.io/sample-api:latest`.

When you are finished, delete the group so the registry and the app stop using the credit:

```bash
az group delete --name rg-acr-lab --yes --no-wait
```
