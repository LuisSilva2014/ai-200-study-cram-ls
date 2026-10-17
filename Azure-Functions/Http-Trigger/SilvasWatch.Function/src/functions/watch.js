const { app } = require("@azure/functions");

// One function (Function as a Service): POST /api/watch. This job plays the movie.
// authLevel anonymous is for this demo, so curl works with no key.
// A real API would use authLevel "function" and require the function key.
app.http("watch", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "watch",
  handler: async (request) => {
    const body = await request.json().catch(() => null);
    const title = body && body.title ? body.title : "";
    const region = body && body.region ? body.region : "";

    if (!title || !region) {
      return {
        status: 400,
        jsonBody: { message: "Send title and region." }
      };
    }

    return {
      status: 200,
      jsonBody: {
        status: "playing",
        title: title,
        region: region,
        message: "Playing from the function. No Express server is running (serverless)."
      }
    };
  }
});

// Other triggers. Leave these commented. The HTTP block above is the one that runs.
// Event Grid starts this function when a notice arrives. Nobody calls the URL.
// app.eventGrid("watchNotice", {
//   handler: async (event) => {
//     console.log(event.eventType);
//   }
// });
//
// Service Bus starts this function when a job is waiting on a queue.
// app.serviceBusQueue("makePoster", {
//   connection: "SERVICE_BUS_CONNECTION",
//   queueName: "posters",
//   handler: async (message) => {
//     console.log(message);
//   }
// });
//
// A timer starts this function on a clock. This schedule is 08:00 UTC every day.
// app.timer("morning", {
//   schedule: "0 0 8 * * *",
//   handler: async () => {
//     console.log("morning run");
//   }
// });
