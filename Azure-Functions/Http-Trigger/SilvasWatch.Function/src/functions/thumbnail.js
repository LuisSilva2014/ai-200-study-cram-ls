const { app } = require("@azure/functions");

// A second function in the same app. This job makes a poster line.
// It does not play the movie. watch.js does that job.
app.http("thumbnail", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "thumbnail",
  handler: async (request) => {
    const body = await request.json().catch(() => null);
    const title = body && body.title ? body.title : "";

    if (!title) {
      return {
        status: 400,
        jsonBody: { message: "Send title." }
      };
    }

    return {
      status: 200,
      jsonBody: {
        status: "ready",
        title: title,
        poster: title + " — now playing",
        message: "Poster made by the thumbnail function. No Express server is running (serverless)."
      }
    };
  }
});
