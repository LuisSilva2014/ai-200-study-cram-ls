# Functions lab — two jobs, no server left running (serverless)

Luis Silva · Oct 17, 2026

This folder is a study lab. It is not one of Christopher Nett's labs. The script is bash, same as the Cosmos and registry labs. Run it from Git Bash. I run it myself.

The academic word is a **function** (Function as a Service). In class, one function is one job. People also call that a microservice. On the exam, say function, and say the host is serverless.

There is no Express app and no server I keep running (serverless). A request arrives, Azure runs that function, then the instance can go back to zero.

Two functions share one function app. Each one does a different job:

| Function | Route | Job |
| --- | --- | --- |
| `health` | `GET /api/health` | Browser check. Open the URL. It does not play a movie. |
| `watch` | `POST /api/watch` | Play the movie. Needs a title and a region. |
| `thumbnail` | `POST /api/thumbnail` | Make a poster line for that title. It does not play the movie. |

## Before I run the script

The script selects the free trial subscription, `Azure subscription 1`, then registers `Microsoft.Storage` and `Microsoft.Web` if either one is missing. A missing storage provider makes Azure say `SubscriptionNotFound`. That message is wrong. The subscription is there. The provider is not.

From this folder:

```bash
bash function-deploy.sh
```

The script creates `rg-func-lab` in East US, a small storage account the Functions host needs, and the function app `silvaswatch-func` on the Linux Consumption plan with Node 22. Application Insights stays off, because Log Analytics is not registered on this trial. Then it zips the function and Azure runs `npm install`.

West Europe is blocked. Do not change the location to `westeurope`.

## After the script

The script prints the URLs. Open this one in a browser:

https://silvaswatch-func.azurewebsites.net/api/health

The page says the function is awake (serverless). The first open after idle can take a few seconds. That wait is the cold start.

```bash
curl -s -X POST https://silvaswatch-func.azurewebsites.net/api/watch -H "Content-Type: application/json" -d "{\"title\":\"Demo\",\"region\":\"eastus\"}"
```

```bash
curl -s -X POST https://silvaswatch-func.azurewebsites.net/api/thumbnail -H "Content-Type: application/json" -d "{\"title\":\"Demo\"}"
```

The play answer says the movie is playing. The poster answer says the thumbnail is ready. Both say no Express server is running (serverless). The first call after the app has been idle can take a few seconds. That wait is the cold start. The next call is faster.

## Check in the portal

1. Open https://portal.azure.com and confirm the directory is the one for `luis@silvassoftware.com`. The subscription is **Azure subscription 1**.
2. Search **Function App** and open `silvaswatch-func` in resource group `rg-func-lab`.
3. **Overview** shows Status Running, the Linux Consumption plan, and the URL `https://silvaswatch-func.azurewebsites.net`.
4. **Functions** in the left menu lists `health`, `watch`, and `thumbnail`. Open `health`. The browser URL is on **Overview**: add `/api/health`.
5. A curl to `/api/watch` or `/api/thumbnail` is the POST check from the shell.

## When I want it to sleep

The Consumption plan already sleeps. After the last call, Azure drops the instance. That is scale to zero. Compute is not billed while the app is idle. The storage account still costs pennies. The next browser open wakes the function. There is no separate hibernate button.

To stop it so a browser open cannot wake it:

```bash
az functionapp stop --name silvaswatch-func --resource-group rg-func-lab
```

Start it again when you want the health page to work:

```bash
az functionapp start --name silvaswatch-func --resource-group rg-func-lab
```

Delete `rg-func-lab` when the lab is finished. Stop is the pause. Delete is the end of the bill.

## What the trigger is

The trigger is the event that starts the function. This demo uses an HTTP trigger. Somebody calls the URL over the internet, and that call starts `watch` or `thumbnail`.

`authLevel` is `anonymous` so the curl works with no key. A real API would use `function` and send the key. The comment is in `watch.js`.

The same function app can start from a different event. The JavaScript registration changes. The Consumption plan (serverless) stays the same.

| Trigger | What starts the function | This lab's version of it |
| --- | --- | --- |
| HTTP | A call to the URL. | `app.http` in `watch.js` and `thumbnail.js`. This is the one that runs. |
| Event Grid | A notice that something already happened. Nobody has to call the URL. | A `SilvasWatch.WatchStarted` notice starts the function, and the function reacts. See the Event Grid notes. |
| Service Bus | A job waiting on a queue. The function is the worker. | A "make the poster" message starts `thumbnail`. See the Service Bus notes. |
| Timer | A clock. | The function runs every morning. No caller. |
| Blob | A new file in a storage container. | A picture lands, and `thumbnail` makes the poster line. |

Commented samples of the Event Grid, Service Bus, and timer registrations are at the bottom of `watch.js`. Leave them commented. An Event Grid or Service Bus trigger also needs that topic or queue to exist, and a connection setting on the function app. HTTP needs only the URL.

## Python or C# instead of Node

The files that run today are JavaScript. The host is Node because of two flags in `function-deploy.sh`:

```bash
--runtime node \
--runtime-version 22 \
```

This CLI also offers Python `3.12` and C# `dotnet-isolated` `10`. To play with one of those:

1. Delete the app if `silvaswatch-func` already exists. The script skips create while that name is still there, so the old Node host would stay.

```bash
az functionapp delete --name silvaswatch-func --resource-group rg-func-lab
```

2. In `function-deploy.sh`, replace the Node pair with one of these pairs.

```bash
--runtime python \
--runtime-version 3.12 \
```

```bash
--runtime dotnet-isolated \
--runtime-version 10 \
```

3. Put that language's files in the zip. A Node host does not run a Python file, and a Python host does not run `watch.js`. Then run `bash function-deploy.sh` again.

Python uses one file, `function_app.py`, and a `requirements.txt` that lists `azure-functions`. The play job looks like this:

```python
import azure.functions as func

app = func.FunctionApp()

@app.route(route="watch", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def watch(req: func.HttpRequest) -> func.HttpResponse:
    body = req.get_json()
    return func.HttpResponse(body["title"] + " is playing (serverless).", status_code=200)
```

C# uses an isolated worker class. The play job looks like this:

```csharp
[Function("watch")]
public HttpResponseData Run(
    [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "watch")] HttpRequestData req)
{
    HttpResponseData response = req.CreateResponse(HttpStatusCode.OK);
    response.WriteString("Playing from the function (serverless).");
    return response;
}
```

The trigger table above is the same in all three languages. Only the registration syntax changes. HTTP is still the one this demo deploys.

## COST APPROX

The Consumption plan includes 1 million executions and 400,000 GB-s each month. A few curls stay inside that. The storage account is a small LRS account, pennies a month, because the host needs it. No Application Insights resource is created.

Delete the group when the look is finished. The other lab groups are separate.

```bash
az group delete --name rg-func-lab --yes --no-wait
```
