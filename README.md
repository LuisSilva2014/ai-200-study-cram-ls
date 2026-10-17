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

## Clean up

Every script ends with a commented-out resource group delete. Nothing here deletes itself. An AKS cluster and a Container Apps environment both bill while they exist, so delete the resource groups when you are finished.

Lab files: Christopher Nett (https://www.youtube.com/@christophernett) and Microsoft, his employer. © Christopher Nett. Provided for personal training use. AI-200 course playlist by Jaspal Singh, Tech with Jaspal: https://www.youtube.com/playlist?list=PLL1ih-rtU13sKhRG67UX9_IiVguLkUXTe. Practice scenarios I use for study: https://www.youtube.com/playlist?list=PLLkhfwhmGXxE. My personal study notes.
