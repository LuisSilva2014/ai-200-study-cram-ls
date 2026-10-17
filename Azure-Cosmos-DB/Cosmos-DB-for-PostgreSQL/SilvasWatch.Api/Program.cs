using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.Cosmos;
using Newtonsoft.Json;

namespace SilvasWatch.Api
{
    public class Program
    {
        private const string WriteRegion = "East US 2";
        private const string ReadRegion = "Southeast Asia";

        public static void Main(string[] args)
        {
            WebApplication app = WebApplication.CreateBuilder(args).Build();
            Container container = CreateContainer();

            app.MapPost("/watch", async (WatchRequest watch) =>
            {
                return await SaveWatch(container, watch);
            });

            app.Run("http://localhost:5080");
        }

        private static Container CreateContainer()
        {
            string endpoint = Require("COSMOS_ENDPOINT");
            string key = Require("COSMOS_KEY");
            CosmosClientOptions options = new CosmosClientOptions();
            options.ApplicationPreferredRegions = new System.Collections.Generic.List<string>
            {
                WriteRegion,
                ReadRegion
            };

            CosmosClient client = new CosmosClient(endpoint, key, options);
            return client.GetContainer("watches", "items");
        }

        private static async Task<IResult> SaveWatch(Container container, WatchRequest watch)
        {
            string region = watch.Region == null ? "" : watch.Region.Trim().ToLowerInvariant();
            if (region != "eastus2" && region != "southeastasia")
            {
                return Results.BadRequest(new { message = "Use eastus2 or southeastasia." });
            }

            if (string.IsNullOrWhiteSpace(watch.Title))
            {
                return Results.BadRequest(new { message = "Title is required." });
            }

            string title = watch.Title.Trim();
            WatchItem item = new WatchItem();
            item.Id = "now";
            item.Region = region;
            item.Title = title;
            await container.UpsertItemAsync(item, new PartitionKey(region));

            string from = region == "eastus2" ? "East US 2" : "Southeast Asia";
            return Results.Ok(new
            {
                status = "playing",
                title = title,
                region = region,
                writeRegion = WriteRegion,
                readRegion = ReadRegion,
                message = "Playing from " + from + "."
            });
        }

        private static string Require(string name)
        {
            string value = System.Environment.GetEnvironmentVariable(name) ?? "";
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new System.InvalidOperationException("Set " + name + ".");
            }

            return value;
        }
    }

    public class WatchRequest
    {
        public string Title { get; set; } = "";
        public string Region { get; set; } = "";
    }

    public class WatchItem
    {
        [JsonProperty("id")]
        public string Id { get; set; } = "";

        [JsonProperty("region")]
        public string Region { get; set; } = "";

        [JsonProperty("title")]
        public string Title { get; set; } = "";
    }
}
