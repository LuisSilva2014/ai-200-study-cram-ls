# Key Vault lab — one demo secret

Luis Silva · Oct 17, 2026

This folder is a study lab. It is not one of Christopher Nett's labs. The script is bash. Run it from Git Bash, in this folder.

Key Vault is the place a secret lives. A connection string, a key, or a password stays there. Another lab does not copy the secret into its source file. It receives permission to read the secret at run time.

This demo stores one value, `demo-play-key`, under the name `watch-api-key`, in the vault `silvaswatchkv`. That value is fake. Do not put a real Cosmos key or a real password in the script.

## Before I run the script

From this folder:

```bash
bash keyvault.sh
```

The script selects **Azure subscription 1**, registers `Microsoft.KeyVault` if it is missing, and creates `rg-keyvault-lab` in East US. The vault is Standard. West Europe is blocked.

If `silvaswatch-func` is still in `rg-func-lab`, the script gives that function app an identity, grants it **Key Vault Secrets User**, and sets the app setting `WATCH_API_KEY` to the vault reference. The setting stores the vault name and the secret name. It does not store `demo-play-key`.

## After the script

Read the secret back from this machine:

```bash
az keyvault secret show --vault-name silvaswatchkv --name watch-api-key --query value -o tsv
```

The answer is `demo-play-key`.

Open https://silvaswatch-func.azurewebsites.net/api/health in a browser. After the function wakes, the page says a Key Vault secret is loaded. The page does not print the value.

## Check in the portal

1. Open https://portal.azure.com. The subscription is **Azure subscription 1**.
2. Search **Key vaults** and open `silvaswatchkv` in `rg-keyvault-lab`.
3. **Secrets** shows `watch-api-key`. Open it, then the current version, then **Show Secret Value**. The value is `demo-play-key`.
4. **Access control (IAM)** shows your user as Key Vault Secrets Officer, and the function app as Key Vault Secrets User.
5. On the function app `silvaswatch-func`, **Settings** → **Environment variables** shows `WATCH_API_KEY`. The value begins with `@Microsoft.KeyVault`. That is the reference, not the secret.

## COST APPROX

Standard has no monthly fee for a secret sitting in the vault. Operations are about $0.03 per 10,000. A create and a few reads are a fraction of a cent. Premium adds HSM keys and a monthly charge per key. Do not switch this vault to Premium.

Soft delete keeps the name `silvaswatchkv` for 7 days after a delete. The script's purge commands free the name sooner. They are commented.

Delete `rg-keyvault-lab` when the look is finished. The function group is separate.

```bash
az group delete --name rg-keyvault-lab --yes --no-wait
```

Source: https://azure.microsoft.com/en-us/pricing/details/key-vault/
