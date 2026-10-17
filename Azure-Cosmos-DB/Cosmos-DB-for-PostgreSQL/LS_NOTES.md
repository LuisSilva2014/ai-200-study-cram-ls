# Cosmos DB lab — free trial notes

Luis Silva · Oct 17, 2026

The account is `silvaswatchlab` in `rg-cosmos-pg-lab`. Writes go to East US 2. The read copy is in Southeast Asia. Open `SilvasWatch.sln` in Visual Studio. The source is `SilvasWatch.Api/Program.cs`. `POST /watch` stores a movie under `eastus2` or `southeastasia` and returns a dummy playing message. A watch from two regions is the same kind of problem Netflix has with Cosmos DB: the viewer's region is the key.

A burstable PostgreSQL cluster cannot add a second region, and new PostgreSQL clusters are blocked while that service is retired. Those commands stay commented in `cosmos-postgres.sh`.

## Before I run the script

`Microsoft.DocumentDB` is already registered. From this folder:

```bash
bash cosmos-postgres.sh
```

The script writes `.env`. Do not commit that file.

## After the script

The source stays in `SilvasWatch.Api`. The process that talks to the account is the Release build in `SilvasWatch.Api/bin/Release/net10.0`. .NET 10 is required. The API listens on http://localhost:5080. Portal check and the local run are the two sections below.

## Check in the Cosmos portal

The account, database, and container are already created. I do not need to run `cosmos-postgres.sh` again unless `.env` is missing.

1. Open https://portal.azure.com and search **Azure Cosmos DB**.
2. Open `silvaswatchlab` in resource group `rg-cosmos-pg-lab`.
3. **Overview** shows status Succeeded. The region list has East US 2 as the write region and Southeast Asia as the read region. Free tier is on.
4. **Data Explorer** → database `watches` → container `items`. The settings for that container show partition key `/region`. After I call the API, the same screen shows one document per region.
5. **Replicate data** (under Settings) shows the same two regions. East US 2 is the write region. Southeast Asia is read-only.
6. **Scale** on database `watches` shows 400 RU/s. Leave it there. Two regions make that 800, which is inside the free 1000.

## What I still run locally

Azure is finished. The API has not been called yet. From this folder, with `.env` already written:

```bash
set -a
source .env
set +a
dotnet run --project SilvasWatch.Api -c Release
```

Visual Studio does not read `.env` by itself. Starting `SilvasWatch.Api` from the IDE needs `COSMOS_ENDPOINT` and `COSMOS_KEY` in the environment, or I use the Git Bash commands above.

East US 2:

```bash
curl -s -X POST http://localhost:5080/watch -H "Content-Type: application/json" -d "{\"title\":\"Demo\",\"region\":\"eastus2\"}"
```

Southeast Asia uses `"region":"southeastasia"`. Then refresh Data Explorer. Each region has one document.

## Two regions

The container is `items` in database `watches`. The partition key is `/region`. One watch from East US 2 and one from Southeast Asia are two partitions. The account copies the data to both Azure regions. Southeast Asia is a read region. It is not a second write region.

Git Bash rewrites a path that starts with `/`. The container command keeps `MSYS_NO_PATHCONV=1` so `/region` stays a partition key.

## AUTO-SCALING

This account does not autoscale. It is fixed at 400 RU/s. Two regions count that twice, so the account uses 800 RU/s.

The commented `--max-throughput 1000` line would turn on autoscale. Across two regions that is 2000 RU/s at the top, which is past the free 1000. Leave it commented.

## COST APPROX FOR 2 REGIONS

The free tier covers the first 1000 RU/s and 25 GB on the account. 400 RU/s in two regions is 800, inside that 1000. Do not raise the throughput and do not add a third region.

Deleting `rg-cosmos-pg-lab` removes the account. The AKS group is separate and still bills until that group is deleted.

## If the run fails

1. Canada Central and East US had no Cosmos capacity on this trial. The working pair is East US 2 and Southeast Asia. Do not switch the script back to the regions that failed.
2. A failed account with the same name must be deleted before a new create. The script does that when the state is `Failed`.
3. `MissingSubscriptionRegistration` for `Microsoft.DocumentDB`: register that namespace, wait, and run the script again.

## When I am finished

```bash
az group delete --name rg-cosmos-pg-lab --yes --no-wait
```
