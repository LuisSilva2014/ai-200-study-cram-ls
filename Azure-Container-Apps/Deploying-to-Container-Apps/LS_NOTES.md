# Container Apps lab — free trial notes

Luis Silva · Oct 16, 2026

This trial allows separate resource groups. It allows only one Container Apps environment at a time. This lab is `sample-api2` in `rg-aca-lab`, registry `acalab26852`. The other lab is `sample-api` in `rg-acr-lab`, registry `acrlabapi1`.

`deploy-container-app.sh` creates `rg-aca-lab` if I deleted it. The registry name in the script is hardcoded to `acalab26852`. The `$RANDOM` line is commented, so I can switch to a new name later without the script doing that on its own.

## Before I run this lab

If `sample-api` is hosted, delete that app and its environment first. Then run the script. Docker Desktop must be running.

```bash
az containerapp delete --name sample-api --resource-group rg-acr-lab --yes
az containerapp env delete --name aca-env --resource-group rg-acr-lab --yes
bash deploy-container-app.sh
```

`acr-build.sh` only stores `sample-api`. It does not create an environment, so I can run it while `sample-api2` is hosted.

## Before I host sample-api instead

Delete this lab's app and environment, then use the host block in the registry lab notes. That block names the app `sample-api`, not `sample-api2`.

```bash
az containerapp delete --name sample-api2 --resource-group rg-aca-lab --yes
az containerapp env delete --name aca-env --resource-group rg-aca-lab --yes
```

## Limits that changed the script

1. West Europe rejected a new registry. Location is `eastus`.
2. `az acr build` is blocked. Docker Desktop builds and pushes.
3. Log Analytics is not registered. The environment uses `--logs-destination none`.
4. A second environment is rejected in every region.

Live site from the last run: https://sample-api2.bluebay-78368cb3.eastus.azurecontainerapps.io

A new environment gets a new middle name. The address stays `https://sample-api2.<generated>.eastus.azurecontainerapps.io` and is already secured.

When I am finished with this lab:

```bash
az group delete --name rg-aca-lab --yes --no-wait
```
