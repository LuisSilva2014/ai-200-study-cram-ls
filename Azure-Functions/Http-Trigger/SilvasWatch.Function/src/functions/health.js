const { app } = require("@azure/functions");

// GET /api/health opens in a browser. It does not play a movie and it does not make a poster.
app.http("health", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "health",
  handler: async () => {
    const secretLoaded = process.env.WATCH_API_KEY
      ? "A Key Vault secret is loaded. The value is not shown on this page."
      : "No Key Vault secret is loaded yet.";

    return {
      status: 200,
      headers: { "Content-Type": "text/html; charset=utf-8" },
      body: [
        "<!DOCTYPE html>",
        "<html><body>",
        "<p>SilvasWatch function is awake (serverless). No Express server is running.</p>",
        "<p>" + secretLoaded + "</p>",
        "</body></html>"
      ].join("")
    };
  }
});
