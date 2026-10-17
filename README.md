# AI-200 Study Cram Files

I collected these files so I can study the labs hands-on, and I added my own notes. The labs are not my work.

I am grateful to Christopher Nett for the practical lab examples in these folders. He teaches the Microsoft AI-200 Study Cram on his channel, and he works at Microsoft.

I also recommend Jaspal Singh (Tech with Jaspal). His playlist is a full AI-200 course, separate from these lab files.

- Christopher Nett: https://www.youtube.com/@christophernett
- Jaspal Singh: https://www.youtube.com/@TechwithJaspal
- Jaspal's AI-200 playlist: https://www.youtube.com/playlist?list=PLL1ih-rtU13sKhRG67UX9_IiVguLkUXTe
- Practice scenarios I use for study: https://www.youtube.com/playlist?list=PLLkhfwhmGXxE
- © Christopher Nett for the lab files here. Provided for personal training use.

I keep my notes inside the lab they belong to, under names that start with `LS_`. For the registry lab, those files are `LS_NOTES.md` and `LS_BUILD-VS-DEPLOY.md`.

The code for the three labs is kept in the folders the labs use. Each folder stands on its own. Work them in the order the video covers them.

Requirements: the Azure CLI and an Azure subscription you can create a resource group in. The Kubernetes lab also needs kubectl. On Windows, run the scripts from Git Bash, WSL, or the Azure Cloud Shell. Edit the settings at the top of each script before running it.

The scripts build in the cloud with `az acr build`, so they do not ask for Docker. On my free trial, West Europe rejected a new registry, and `az acr build` was blocked. I finished the registry lab by building with Docker Desktop and pushing the image. Notes for that path are in `Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR/LS_BUILD-VS-DEPLOY.md` and `LS_NOTES.md`.

## How the folders fit

Each folder has one job. They also line up as one path: pack the app, store it, then host it.

| Folder | Its own job | How it complements the others |
| --- | --- | --- |
| Container Registry | Build the image and store it in the warehouse. Does not host it. | Produces the package the other two labs can run. |
| Container Apps | Host a container and give it a public URL. Also passes settings in from outside the image. | The hosting step for the image in the warehouse. Its script builds a second image so it can run alone. |
| AKS | Host a workload from Kubernetes files and wait for a public IP. | Another way to host. Its script uses a public sample image, so it does not need the warehouse. |
| Cosmos DB | Free-tier account in East US 2 and Southeast Asia. | A C# watch API stores a movie by region. |
| Event Grid | Notes on a notice that something already happened. | Every matching listener gets a copy and reacts. No script and no sample app. |
| Service Bus | Notes on a job handed to one worker. | The job waits in a queue until one application finishes it. No script and no sample app. |
| Functions | JavaScript functions. No server left running (serverless). | `GET /api/health` opens in a browser. `watch` plays a movie. `thumbnail` makes a poster line. |
| Key Vault | A bash script stores one demo secret. | The function app can be granted read access. The secret value stays in the vault. |

1. **Build and store.** `docker build` / `az acr build`, then push. The image sits in the registry. No URL yet.
2. **Host with Container Apps.** Azure pulls a tag and serves HTTPS. Closest to copying a published .NET app onto IIS.
3. **Host with AKS.** You apply manifest files. Azure gives the service a public IP.

## 1. Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR

Build a container image and push it to your own private registry.

- `Dockerfile`: a small FastAPI image on a slim Python base. Dependencies go in their own cached layer. The app runs as a normal user, not root.
- `app.py`: the sample API. The root address returns the service name and version. `/health` is there for probes.
- `requirements.txt`: the two pinned dependencies.
- `acr-build.sh`: creates the resource group and a Basic registry, builds and pushes the image, then lists the repository and its tags.

## 2. Azure-Container-Apps/Deploying-to-Container-Apps

Run a container on a managed host and see configuration reach it from outside the image.

- `Dockerfile`, `app.py`, `requirements.txt`: the same shape as the registry lab, with one difference. This `app.py` reads two values from the environment and echoes them back, so the same image behaves differently per deployment.
- `deploy-container-app.sh`: builds the image, creates the Container Apps environment, and creates the app with one plain environment variable and one value held as a secret. It prints the public URL at the end.
- `.env.example`: the same two values for running the app on your own machine. Copy it to `.env` and run `uvicorn app:app --env-file .env`.

Run this folder's script on its own. It creates its own registry, so the registry lab is not required. To host the image you already pushed, use the commands in `Container-Images-with-Azure-Container-Registry/Building-and-Pushing-Images-to-ACR/LS_BUILD-VS-DEPLOY.md`.

## 3. Azure-Kubernetes-Service/Deploying-Applications-with-Manifest-Files

Deploy the same kind of workload to Kubernetes from manifest files.

- `deployment.yaml`: three replicas of a public sample web app, with the labels the Service selects on, CPU and memory requests and limits, and readiness and liveness probes.
- `service.yaml`: a LoadBalancer Service. AKS asks Azure for a public load balancer and an external IP.
- `aks-deploy.sh`: creates the cluster, points kubectl at it, applies both files, waits for the rollout, then watches the Service until the external IP appears. Press Ctrl+C once `EXTERNAL-IP` is set.

The image here is public, so this folder does not use the registry.

## 4. Azure-Cosmos-DB/Cosmos-DB-for-PostgreSQL

- `cosmos-postgres.sh`: creates the free-tier account `silvaswatchlab` with writes in East US 2 and a read copy in Southeast Asia, then the `watches` database and `items` container.
- `SilvasWatch.sln`: the Visual Studio solution. The source is `SilvasWatch.Api`. Build Release. `POST /watch` stores a movie for `eastus2` or `southeastasia` and returns a dummy playing message.
- `.env.example`: the script writes the real endpoint and key into `.env`.
- `LS_NOTES.md`: the two regions, the free-tier limit, and how to call the API.

## 5. Azure-Event-Grid/Understanding-Push-Delivery

Study notes for Event Grid. This one is not one of Christopher Nett's labs. There is no script and no sample app. A script can create an empty topic, but nothing is delivered until a publisher and a listener exist. The notes are the lab.

- `LS_NOTES.md`: a notice that something already happened, who receives a copy, and how that differs from a Service Bus job.

## 6. Azure-Service-Bus/Understanding-Queues

Study notes for Service Bus. This one is not one of Christopher Nett's labs. There is no script and no sample app. A script can create an empty queue, but the queue only matters once one application posts a job and another application does it.

- `LS_NOTES.md`: one job for one worker, what happens when the worker fails, and how that differs from an Event Grid notice.

## 7. Azure-Functions/Http-Trigger

One HTTP function on the Consumption plan. This one is a study lab, not one of Christopher Nett's labs.

- `SilvasWatch.Function/src/functions/health.js`: `GET /api/health`. Open this URL in a browser.
- `SilvasWatch.Function/src/functions/watch.js`: `POST /api/watch`. This function plays the movie.
- `SilvasWatch.Function/src/functions/thumbnail.js`: `POST /api/thumbnail`. This function makes a poster line. Same app, different job. No server left running (serverless).
- `function-deploy.sh`: creates the resource group, the storage account the host needs, and the function app in East US, then deploys the zip. Run it from Git Bash.
- `LS_NOTES.md`: the trigger, the cold start, how the plan sleeps, and the free monthly grant.

## 8. Azure-Key-Vault/Storing-a-Secret

A study lab for one secret. This one is not one of Christopher Nett's labs.

- `keyvault.sh`: creates a Standard vault in East US, stores `watch-api-key`, and, if the function app exists, lets that app read the secret without copying the value into the function files.
- `LS_NOTES.md`: the portal path, the app setting reference, and the operations cost.

## Clean up

Every lab script ends with a commented-out resource group delete. From the repo root, `bash rollback-labs.sh` deletes the lab groups that are still there. It skips a group that is already gone. It does not delete `deaf-assistant-speech` or `NetworkWatcherRG`.

Lab files: Christopher Nett (https://www.youtube.com/@christophernett) and Microsoft, his employer. © Christopher Nett. Provided for personal training use. AI-200 course playlist by Jaspal Singh, Tech with Jaspal: https://www.youtube.com/playlist?list=PLL1ih-rtU13sKhRG67UX9_IiVguLkUXTe. Practice scenarios I use for study: https://www.youtube.com/playlist?list=PLLkhfwhmGXxE. My personal study notes.
