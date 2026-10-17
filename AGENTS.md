# AGENTS.md

Study copy of the three labs from Christopher Nett's Microsoft AI-200 Study Cram, plus Luis Silva's notes. Credit the labs to https://www.youtube.com/@christophernett and to Microsoft, his employer. Do not present the labs as Luis's work. His notes are the files named `LS_*.md`.

## Spend less

- Read this file, then `README.md`. Do not open every lab file.
- Open only the lab folder the user is in.
- Keep new personal notes inside that lab folder, as `LS_*.md`. Do not put them at the repo root.
- Do not run lab scripts, `az` creates, or deletes unless the user asks. They run the commands.
- Do not re-run `acr-build.sh`. The registry name uses `$RANDOM`, so a new run creates another Basic registry.

## Already in Azure (free trial, $200 credit)

- `az acr build` is blocked: `TasksOperationsNotAllowed`. The credit does not turn ACR Tasks on.
- West Europe rejects new resources on this subscription. Use `eastus`.
- Resource group `rg-acr-lab` is in East US. Registry `acrlab26178`. Image `sample-api:v1` and `sample-api:latest` are the same build, stored only. The warehouse is not hosting HTTP.
- A local `docker run` of that image returned 200 on `/` and `/health`.
- Container Apps was not created. Environment create failed because Log Analytics (`Microsoft.OperationalInsights`) is not registered. Next commands are in `LS_BUILD-VS-DEPLOY.md` (`--logs-destination none`).
- Delete resource groups only when the user asks. AKS and Container Apps bill until then.

## Map

| Path | Job |
| --- | --- |
| `Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR` | Build the image and store it. Notes: `LS_NOTES.md`, `LS_BUILD-VS-DEPLOY.md`. |
| `Azure-Container-Apps/Deploying-to-Container-Apps` | Host a container and print a URL. Creates its own registry. Script location is still `westeurope`. |
| `Azure-Kubernetes-Service/Deploying-Applications-with-Manifest-Files` | Host from Kubernetes files. Public image, two nodes. Script location is still `westeurope`. |
| `Azure-Cosmos-DB/Cosmos-DB-for-PostgreSQL` | Free-tier Cosmos account `silvaswatchlab`: East US 2 writes, Southeast Asia reads, 400 RU/s. C# API `SilvasWatch.Api`. Do not add regions or raise throughput. Notes: `LS_NOTES.md`. |
| `Azure-Event-Grid/Understanding-Push-Delivery` | Notes only. Event Grid notifies listeners that something happened. No script and no sample app. |
| `Azure-Service-Bus/Understanding-Queues` | Notes only. Service Bus hands one job to one worker. No script and no sample app. |
| `Azure-Functions/Http-Trigger` | Two JavaScript HTTP functions, `watch` and `thumbnail`. Script: `function-deploy.sh`. Consumption plan, East US, no Application Insights. Do not run it unless Luis asks. |

## Words

Plain English. Call Azure Container Registry the warehouse. Building and storing an image is not deploying or hosting it.
