# Event Grid — a notice that something happened

Luis Silva · Oct 17, 2026

This folder is study notes. It is not one of Christopher Nett's labs. There is no application and no script here.

Event Grid lives in Azure. One application publishes a small notice. Event Grid delivers that notice to every application that asked to hear it. Those applications then react. Event Grid does not tell them to finish a job, and it does not wait to see if they did.

The pair to read with this file is `Azure-Service-Bus/Understanding-Queues/LS_NOTES.md`. Service Bus carries a job. Event Grid carries a notice.

## A real case

The watch API in East US 2 saves a movie. A second application in Southeast Asia keeps a cache. A third application writes an audit row.

The watch API does not call those two applications. It publishes one notice: `SilvasWatch.WatchStarted`, subject `/region/eastus2/items/demo`. Event Grid pushes a copy to each subscriber whose filter matches. The cache refreshes. The audit row is written. The watch API has already moved on.

If a subscriber is down, Event Grid retries the delivery. The notice is not a job sitting in a mailbox for one worker.

## The pieces

| Piece | What it is |
| --- | --- |
| Topic | The place a publisher posts notices. A custom topic is for your own notices. A system topic is for notices Azure writes itself, such as `Microsoft.Storage.BlobCreated` when a file lands in a storage account. |
| Event | The notice. It has an id, an event type, a subject, a time, and a small data payload. |
| Subscription | A filter plus a destination. The filter picks event type and subject. The destination is the application or Azure service that should react. |
| Handler | The application that receives the notice and decides what to do. Event Grid is not the handler. |

One notice can match more than one subscription. Each match gets its own copy. That is fan-out. The listeners do not compete for a single copy.

A notice with no matching subscription is accepted and then dropped. Nothing is called.

## What moves, and what stays where it is

The notice is small. A title, a region, an id. The movie file, the Cosmos document, and the picture stay in their own stores. The notice says what happened and where to look. Event Grid is not a file transfer.

## Event Grid and Service Bus

| | Event Grid | Service Bus |
| --- | --- | --- |
| The message means | This already happened. | Please do this job. |
| Who receives it | Every subscriber that matches. | One worker. A second worker does not get the same job. |
| The sender | Does not wait for the reaction. | Does not wait for the worker. The job waits in the queue until a worker takes it. |
| If the receiver fails | Event Grid retries the notice. | The job goes back in the queue for another try. |

Use Event Grid when other applications only need to hear the fact and react on their own. Use Service Bus when one application must complete a piece of work. See the Service Bus notes for the queue, the lock, and the dead-letter bin.

## COST APPROX

Nothing in this folder creates a resource. A topic on the basic tier includes the first 100,000 operations each month. Publishing a notice counts. Each delivery attempt counts. A filter on event type, and a filter on "subject begins with", do not count as advanced filtering. A filter on a field inside the data payload does.

Do not create a topic until you decide to. West Europe is blocked on this trial. Use `eastus`. Delete that resource group when you are finished looking. The Cosmos, AKS, Container Apps, and registry groups are separate.

Source: https://learn.microsoft.com/en-us/azure/event-grid/concepts and https://azure.microsoft.com/en-us/pricing/details/event-grid/
