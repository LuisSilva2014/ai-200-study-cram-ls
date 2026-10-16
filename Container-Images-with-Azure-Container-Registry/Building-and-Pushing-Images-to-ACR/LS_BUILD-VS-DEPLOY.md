# Build vs deploy — image in the warehouse

Luis Silva notes for `1. Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR`
Collected on: Oct 16, 2026


This lab only built the image and stored it in the warehouse (Azure Container Registry). Hosting came later. I then started tag `v1` on Container Apps, and Azure gave me a URL.

## How I used to ship, and how this ships

When I built web APIs in .NET, I published the binaries, then I copied that folder onto IIS or onto a shared hosting server and started the site. I did the copy by hand.

The same work is now split into CI and CD.

- **CI** is the build. A pipeline packs the app into an image and stores it in the warehouse under a tag, such as `v1`.
- **CD** is the hosting step. A pipeline takes one tag that is already stored and starts it on Container Apps, AKS, or another host. That is when I get a URL.

The lab script stopped at CI. I later did the CD step by hand: Container Apps pulled `v1` and started it.

## What is in the warehouse

`app.py` is a small Python web API. `docker build` packed the app, Python 3.11, and its libraries into one image. That image is the packaged build, the way a `dotnet publish` folder is the packaged build.

`docker push` stored it in the warehouse under two names:

- `acrlabapi1.azurecr.io/sample-api:v1`
- `acrlabapi1.azurecr.io/sample-api:latest`

Both names point at the same build. The warehouse is holding the package. It is not serving HTTP.

| Step | .NET on IIS | This lab |
| --- | --- | --- |
| Write | ASP.NET Web API | `app.py` |
| Build | `dotnet publish` | `docker build` |
| Store | Binaries on disk or a file share | `docker push` into the registry. This is the CI side. |
| Deploy and host | I copied the folder onto IIS or a shared hosting server by hand | Done after the lab. Container Apps hosts `v1`. |

## Test on your PC

Docker Desktop must be running. This starts the image on your machine only. `v1` is the tag. Change it to `latest` if you want that name instead.

```bash
docker run --rm -p 8000:8000 acrlabapi1.azurecr.io/sample-api:v1
```

Leave that window open. In a browser:

- http://localhost:8000
- http://localhost:8000/health

Ctrl+C stops it. The local test already answered 200 on `/` and `/health`. Nothing in Azure is hosting the API.

## Host one tag that is already in the warehouse

`acr-build.sh` does not run this block. The app name here is `sample-api` only. This trial allows only one Container Apps environment. Before these commands, delete `sample-api2` if it is hosted:

```bash
az containerapp delete --name sample-api2 --resource-group rg-aca-lab --yes
az containerapp env delete --name aca-env --resource-group rg-aca-lab --yes
```

`acr-build.sh` creates `rg-acr-lab` again if you deleted it. Run that first so `acrlabapi1` exists. Then run this block.

This is the IIS step. You pick a tag that is already built (`v1`) and Azure Container Apps pulls that tag, starts it, and gives you an HTTPS address. The address uses port 443. Azure forwards traffic to port 8000 inside the container.

The first try stopped at the environment. Azure tried to attach a Log Analytics workspace, and this free trial is not registered for that service (`Microsoft.OperationalInsights`). The environment `aca-env` was not created, so the app create and the URL lookup had nothing to find. The registry admin user is already turned on.

Run this from Git Bash. `--logs-destination none` skips Log Analytics. It uses East US and draws on the $200 credit until you delete the group.

Lines that start with `#` are comments. Bash skips them. This block is the normal path: Azure makes the address. You do not buy a domain for it.

```bash
# Normal path. Azure's own address. No domain purchase.
az provider register -n Microsoft.App --wait

ACR_USER=$(az acr credential show --name acrlabapi1 --query username -o tsv)
ACR_PASS=$(az acr credential show --name acrlabapi1 --query "passwords[0].value" -o tsv)

az containerapp env create \
  --resource-group rg-acr-lab \
  --name aca-env \
  --location eastus \
  --logs-destination none

# --ingress external is what publishes HTTPS on Azure's domain.
# A name you bought is a later step. Do not add it here.
az containerapp create \
  --resource-group rg-acr-lab \
  --name sample-api \
  --environment aca-env \
  --image acrlabapi1.azurecr.io/sample-api:v1 \
  --registry-server acrlabapi1.azurecr.io \
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

Own domain, only after the app above already exists. Buy the domain from a registrar first (Namecheap, GoDaddy, Cloudflare, or similar). Until you own it and the DNS records below are in place, leave this block commented. Uncommenting it early fails.

```bash
# Own domain. Buy it first, then point DNS at the app, then run these.
# Replace api.example.com with the name you bought.
# MY_DOMAIN=api.example.com
#
# At the registrar, create both records before the bind command:
#   CNAME  api      -> sample-api.politerock-fb7995fa.eastus.azurecontainerapps.io
#   TXT    asuid.api -> the id printed by the show command below
#
# az containerapp show \
#   --resource-group rg-acr-lab \
#   --name sample-api \
#   --query properties.customDomainVerificationId -o tsv
#
# az containerapp hostname add \
#   --resource-group rg-acr-lab \
#   --name sample-api \
#   --hostname "$MY_DOMAIN"
#
# az containerapp hostname bind \
#   --resource-group rg-acr-lab \
#   --name sample-api \
#   --hostname "$MY_DOMAIN" \
#   --environment aca-env \
#   --validation-method CNAME
```

The last command prints the host name. Mine came back as:

`sample-api.politerock-fb7995fa.eastus.azurecontainerapps.io`

Open it with `https`. Do not add `:8000`. Azure forwards public HTTPS to port 8000 inside the container.

- https://sample-api.politerock-fb7995fa.eastus.azurecontainerapps.io
- https://sample-api.politerock-fb7995fa.eastus.azurecontainerapps.io/health

That address is already secured. Microsoft supplies the certificate for `azurecontainerapps.io`. I did not buy or upload a certificate.

The shape is `https://<app>.<generated-name>.<region>.azurecontainerapps.io`.

- `sample-api` is the app name I chose.
- `politerock-fb7995fa` is a name Azure made up for this environment. A new environment gets a different middle name.
- `eastus` is the region, because I created the environment there.

A name I own, such as `api.example.com`, shows up only if I already attached that domain. This deploy did not. A custom domain can use a certificate I bring, or one Azure manages. The default `azurecontainerapps.io` address stays HTTPS either way.

## Check it in the portal

1. Open https://portal.azure.com and sign in with the same account as `az login`.
2. In the top search box, type **Container Apps** and open that list.
3. Open **sample-api**. The resource group is `rg-acr-lab` and the region is East US.
4. On **Overview**, check two things: the status is Running, and Application Url is `https://sample-api.politerock-fb7995fa.eastus.azurecontainerapps.io`.
5. Click that URL, then add `/health`. Both should answer.
6. In the left menu, open **Revisions** (or **Containers**) and confirm the image is `acrlabapi1.azurecr.io/sample-api:v1`.

The same resource group also holds the warehouse. Search **Container registries**, open `acrlabapi1`, then **Repositories** → `sample-api`. The tags `v1` and `latest` are the stored build. The registry page does not host the site. The Container App page does.

To promote a different tag later, run `az containerapp update` with the new image name, for example `acrlabapi1.azurecr.io/sample-api:latest`.

When you are finished, delete the group so the registry and the app stop using the credit:

```bash
az group delete --name rg-acr-lab --yes --no-wait
```
