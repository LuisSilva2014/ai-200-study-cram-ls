# Service Bus — a job for one application

Luis Silva · Oct 17, 2026

This folder is study notes. It is not one of Christopher Nett's labs. There is no application and no script here.

Service Bus lives in Azure. One application puts a job in a queue. Another application takes that job and does the work. The job waits until a worker takes it. Service Bus does not do the work.

The pair to read with this file is `Azure-Event-Grid/Understanding-Push-Delivery/LS_NOTES.md`. Event Grid carries a notice. Service Bus carries a job.

## A real case

The watch API accepts "Play Demo" for East US 2. Making the thumbnail is slow. The API should not do that work inside the request.

The API puts one message on a queue: make the thumbnail for Demo, the picture is at this blob path. A worker application pulls the message and makes the thumbnail. A second worker does not get that same message. When the worker finishes, it completes the message and the message is removed.

The picture stays in Blob Storage. The queue carries the instruction and the path. Service Bus is not a file transfer.

## The pieces

| Piece | What it is |
| --- | --- |
| Namespace | The post office. The host name looks like `name.servicebus.windows.net`. |
| Queue | One mailbox. Messages wait here. Basic tier has queues. |
| Message | The job. A small body, plus a few properties such as the region. |
| Sender | The application that posts the job. It does not wait for the worker. |
| Receiver | The worker that takes one job and does it. |

## Lock, complete, and give it back

The worker locks the message. While the lock is held, no other worker can see it.

- Complete means the job is done. The message is removed.
- Abandon means the worker failed. The message goes back to the queue. The delivery count goes up.
- After too many tries, Service Bus moves the message to the dead-letter queue. A poison job stops blocking the mailbox. A person can read it there.

That mode is called peek-lock, and it is the default. Receive-and-delete removes the message the moment it is read. If the worker crashes after that read, the job is gone. Use peek-lock when the job must not be lost.

Two workers on the same queue are competing consumers. Each message goes to one of them. This is the opposite of Event Grid, where every matching subscriber gets a copy.

## Queue and topic

A queue is the normal choice for two applications: one sends work, one does work.

A topic is for when several different kinds of worker each need their own copy of the same message. Each subscription is its own mailbox with its own workers. Topics start on the Standard tier. A queue on the Basic tier is enough for the thumbnail case above.

## Service Bus and Event Grid

| | Service Bus | Event Grid |
| --- | --- | --- |
| The message means | Please do this job. | This already happened. |
| Who receives it | One worker. | Every subscriber that matches. |
| The message waits | Until a worker takes it, or until it expires or is dead-lettered. | Event Grid pushes it. It is not a job waiting for one worker. |
| A failed receiver | The job goes back in the queue. | Event Grid retries the notice. |

Use Service Bus when you are handing work to an application. Use Event Grid when you are telling applications that something already happened, and each of them reacts on its own.

## COST APPROX

Nothing in this folder creates a resource.

Basic is the queue tier. It bills per million operations. A few messages are a fraction of a cent. Standard adds topics, sessions, transactions, and duplicate detection, and it adds a base charge billed once per subscription for the month, about $10. Premium is a dedicated unit billed every hour. Do not pick Premium for a study namespace.

Confirm the numbers at https://azure.microsoft.com/en-us/pricing/details/service-bus/ before creating anything. West Europe is blocked on this trial. Use `eastus`. Delete that resource group when you are finished looking. The other lab groups are separate and still bill on their own.
