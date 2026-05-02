# Amazon SQS -- Complete Knowledge Base

> This document is the plain-English reference for SQS that the pipeline engine
> framework and developer agent can consult when handling any SQS-related request
> in a pipeline. It covers what SQS is, how it works, every feature, integration
> patterns, security, performance, and troubleshooting -- written for an agent
> that needs to reason about SQS in context, not just look up API parameters.

---

## 1. What Is SQS?

Amazon Simple Queue Service (SQS) is a fully managed message queuing service
that enables you to decouple and scale microservices, distributed systems, and
serverless applications. Messages are stored redundantly across multiple
Availability Zones.

SQS is a **passive** service in our pipeline engine -- it has no execution role
and does not initiate actions. Instead, it acts as a buffer between producers
(services that send messages) and consumers (services that read and process
messages).

### Core Concepts
- **Queue**: A named message buffer. Messages are stored until consumed or expired.
- **Message**: A payload (up to 256 KB) with optional attributes and metadata.
- **Producer**: A service or application that sends messages to the queue.
- **Consumer**: A service or application that receives and processes messages.
- **Receipt Handle**: A token received when reading a message. Required to delete it.
- **Visibility Timeout**: After a message is received, it's hidden from other consumers for this period.
- **Queue URL**: The HTTPS endpoint for the queue (`https://sqs.REGION.amazonaws.com/ACCOUNT/QUEUE-NAME`).

### Free Tier
SQS is always-free tier: 1 million requests/month (Standard and FIFO combined).
Each 64 KB chunk of a message counts as one request.

---

## 2. Queue Types

### Standard Queue (Default)
- **Throughput**: Nearly unlimited messages per second
- **Ordering**: Best-effort ordering (messages may arrive out of order)
- **Delivery**: At-least-once (messages may be delivered more than once)
- **Deduplication**: None (applications must handle duplicates)
- **Use cases**: Decoupling services, buffering, fan-out from SNS, S3 event notifications

### FIFO Queue
- **Throughput**: 300 messages/second per API action (3,000 with batching, 30,000 with high throughput mode per message group)
- **Ordering**: Strict FIFO within each message group
- **Delivery**: Exactly-once processing (5-minute deduplication window)
- **Deduplication**: Content-based (SHA-256 of body) or explicit (MessageDeduplicationId)
- **Use cases**: Order processing, financial transactions, command ordering

**FIFO queue constraints:**
- Queue name MUST end with `.fifo` suffix
- Every message MUST include `MessageGroupId`
- S3 event notifications do NOT support FIFO queues
- SNS FIFO topics can only send to SQS FIFO queues

---

## 3. Visibility Timeout

When a consumer receives a message, SQS hides it from other consumers for the
visibility timeout period. If the consumer deletes the message before the timeout
expires, processing is complete. If not, the message becomes visible again and
can be received by another consumer (or the same one).

**Range**: 0 to 43,200 seconds (12 hours)
**Default**: 30 seconds
**Our pipeline default**: 30 seconds

### Best Practice with Lambda
When SQS triggers Lambda via event source mapping, set the visibility timeout to
**at least 6x the Lambda function timeout**. This prevents duplicate processing
when Lambda retries after a timeout.

Example: Lambda timeout = 30s, SQS visibility timeout should be >= 180s.

### Per-Message Override
Use `ChangeMessageVisibility` to extend the timeout for a specific message if
processing takes longer than expected.

---

## 4. Dead Letter Queues (DLQ)

A DLQ receives messages that fail to be processed after a specified number of
receive attempts (configured by `maxReceiveCount` in the redrive policy).

### Configuration
```json
{
  "deadLetterTargetArn": "arn:aws:sqs:REGION:ACCOUNT:my-queue-dlq",
  "maxReceiveCount": 3
}
```

### Rules
- DLQ must be the **same type** as the source queue (Standard for Standard, FIFO for FIFO)
- DLQ must be in the **same AWS account and region**
- DLQ retention period should be **longer than** the source queue's retention
- `maxReceiveCount` minimum is 1

### Message Move (Redrive)
After fixing the issue that caused processing failures, use `StartMessageMoveTask`
to move messages from the DLQ back to the original source queue for reprocessing.

### Redrive Allow Policy
Controls which source queues can use a specific queue as their DLQ:
- `allowAll`: Any queue can use this as DLQ
- `denyAll`: No queue can use this as DLQ
- `byQueue`: Only specified queue ARNs

---

## 5. Message Attributes

Structured metadata attached to messages. Up to 10 attributes per message.

### Data Types
- **String**: UTF-8 text
- **Number**: Sent as string, interpreted as number (integer, floating-point)
- **Binary**: Base64-encoded binary data
- Custom subtypes: `String.custom`, `Number.custom`, `Binary.custom`

### Size Impact
Attribute names and values count toward the 256 KB total message size limit.

### System Attributes (Read-Only)
- `ApproximateReceiveCount` -- how many times the message has been received
- `ApproximateFirstReceiveTimestamp` -- when the message was first received
- `SenderId` -- IAM identity of the sender
- `SentTimestamp` -- when the message was sent
- `MessageGroupId` -- FIFO queue message group
- `SequenceNumber` -- FIFO queue sequence number
- `DeadLetterQueueSourceArn` -- set when message was moved to DLQ

---

## 6. Encryption

### SSE-SQS (Default)
SQS-managed encryption using AES-256. Free. Enabled by default on all new
queues since 2023. No configuration needed.

### SSE-KMS
AWS KMS-managed encryption. Provides audit trail via CloudTrail and key
rotation control.

**Terraform attributes:**
- `kms_master_key_id`: KMS key alias or ARN
- `kms_data_key_reuse_period_seconds`: How long SQS reuses a data key (60-86,400 seconds, default 300)

**Required KMS permissions:**
- Producer: `kms:GenerateDataKey`, `kms:Decrypt`
- Consumer: `kms:Decrypt`

**Cross-account note**: Cross-account access with SSE-KMS requires the KMS key
policy to explicitly allow the other account's IAM principal.

---

## 7. Long Polling

By default, SQS uses short polling -- `ReceiveMessage` returns immediately, even
if no messages are available. This can result in many empty responses and higher
API costs.

**Long polling** (set `ReceiveMessageWaitTimeSeconds` > 0, max 20) makes the
`ReceiveMessage` call wait until a message arrives or the timeout expires. This:
- Reduces the number of empty responses
- Reduces API call costs
- Queries all SQS servers (short polling queries a subset, which can miss messages)

**Recommended**: Set `receive_wait_time_seconds = 20` for cost optimization.

---

## 8. Delay Queues

Postpone delivery of all new messages to the queue for 0-900 seconds (15 minutes).
Messages are invisible during the delay period.

- **Queue-level delay**: Set via `delay_seconds` attribute
- **Per-message delay**: Override via `DelaySeconds` parameter on `SendMessage` (Standard queues only; FIFO queues do NOT support per-message delay)

---

## 9. Queue Policies (Access Control)

SQS uses resource-based policies (queue policies) to grant other AWS services
permission to send messages to the queue.

### Key Constraint
AWS allows exactly **ONE** `aws_sqs_queue_policy` per queue. If multiple services
need to send to the same queue (e.g., S3 + SNS + EventBridge), all permissions
must be consolidated into a single policy with multiple statements.

Our SQS renderer handles this automatically -- it checks for all source
integrations (S3, SNS, EventBridge/CloudWatch) and builds one consolidated policy.

### Common Policy Patterns

**S3 Notification:**
```json
{
  "Effect": "Allow",
  "Principal": {"Service": "s3.amazonaws.com"},
  "Action": "sqs:SendMessage",
  "Resource": "QUEUE_ARN",
  "Condition": {"ArnEquals": {"aws:SourceArn": "BUCKET_ARN"}}
}
```

**SNS Subscription:**
```json
{
  "Effect": "Allow",
  "Principal": {"Service": "sns.amazonaws.com"},
  "Action": "sqs:SendMessage",
  "Resource": "QUEUE_ARN",
  "Condition": {"ArnEquals": {"aws:SourceArn": "TOPIC_ARN"}}
}
```

**EventBridge Target:**
```json
{
  "Effect": "Allow",
  "Principal": {"Service": "events.amazonaws.com"},
  "Action": "sqs:SendMessage",
  "Resource": "QUEUE_ARN"
}
```

---

## 10. IAM Permissions Reference

SQS is a passive service -- it does not have an execution role. Permissions are
needed by the **callers** (producers and consumers).

### Complete Action List

| Action | Description |
|---|---|
| `sqs:SendMessage` | Send a message (covers SendMessageBatch too) |
| `sqs:ReceiveMessage` | Receive messages from a queue |
| `sqs:DeleteMessage` | Delete a processed message (covers batch) |
| `sqs:ChangeMessageVisibility` | Extend/shorten visibility timeout (covers batch) |
| `sqs:PurgeQueue` | Delete all messages |
| `sqs:CreateQueue` | Create a new queue |
| `sqs:DeleteQueue` | Delete a queue |
| `sqs:GetQueueUrl` | Get queue URL from name |
| `sqs:GetQueueAttributes` | Get queue attributes/metrics |
| `sqs:SetQueueAttributes` | Set queue attributes |
| `sqs:ListQueues` | List queues in account |
| `sqs:ListDeadLetterSourceQueues` | List queues using this as DLQ |
| `sqs:AddPermission` | Add permission to queue policy |
| `sqs:RemovePermission` | Remove permission from queue policy |
| `sqs:TagQueue` | Add tags |
| `sqs:UntagQueue` | Remove tags |
| `sqs:ListQueueTags` | List tags |
| `sqs:StartMessageMoveTask` | Move messages from DLQ |
| `sqs:CancelMessageMoveTask` | Cancel move task |
| `sqs:ListMessageMoveTasks` | List move tasks |

### Common Permission Sets
- **Producer**: `sqs:SendMessage`, `sqs:GetQueueUrl`
- **Consumer (Lambda ESM)**: `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`
- **Full access**: All of the above + `sqs:ChangeMessageVisibility`

### ARN Format
`arn:aws:sqs:REGION:ACCOUNT:QUEUE-NAME`

---

## 11. Service Quotas

| Quota | Limit |
|---|---|
| Max queues per account per region | 1,000,000 |
| Queue name max length | 80 characters |
| Max message size | 256 KB |
| Max message attributes | 10 per message |
| Message retention | 60 seconds to 14 days |
| Visibility timeout | 0 to 43,200 seconds (12 hours) |
| Delay seconds | 0 to 900 seconds (15 minutes) |
| Long polling wait time | 0 to 20 seconds |
| Max batch size | 10 messages |
| Max receive per call | 10 messages |
| In-flight messages (Standard) | 120,000 per queue |
| In-flight messages (FIFO) | 20,000 per queue |
| FIFO throughput | 300 msg/s (3,000 batched, 30,000 high throughput) |
| FIFO deduplication window | 5 minutes |
| Max tags per queue | 50 |

---

## 12. Integration Patterns in Our Pipeline Engine

### SQS as Message Buffer (Receives Messages)

**S3 -> SQS**:
S3 renderer creates `aws_s3_bucket_notification` (queue block). SQS renderer
creates `aws_sqs_queue_policy` allowing `s3.amazonaws.com`. Standard queues
only -- FIFO queues do NOT support S3 notifications.

**SNS -> SQS**:
SNS renderer creates `aws_sns_topic_subscription` (protocol: sqs). SQS
renderer creates `aws_sqs_queue_policy` allowing `sns.amazonaws.com`.

**EventBridge/CloudWatch -> SQS**:
EventBridge renderer creates `aws_cloudwatch_event_target`. SQS renderer
creates `aws_sqs_queue_policy` allowing `events.amazonaws.com`.

**Lambda -> SQS**:
Lambda sends messages via `sqs:SendMessage`. Lambda renderer adds IAM
permissions. Environment variable `{PEER}_QUEUE_URL` auto-wired.

### SQS as Event Source (Triggers Processing)

**SQS -> Lambda**:
Lambda renderer creates `aws_lambda_event_source_mapping` with batch_size=10.
Lambda execution role gets `sqs:ReceiveMessage`, `sqs:DeleteMessage`,
`sqs:GetQueueAttributes`.

### Common Pipeline Pattern: S3 -> SQS -> Lambda
This is the most common buffering pattern:
1. S3 sends object creation notification to SQS
2. SQS buffers the events
3. Lambda polls SQS and processes events in batches

Benefits over direct S3 -> Lambda:
- SQS buffers during Lambda throttling
- DLQ catches failed messages for retry
- Batch processing (up to 10 messages per invocation)
- Decouples S3 event rate from Lambda concurrency

### Common Pipeline Pattern: SNS -> SQS (Fan-Out)
One SNS topic fans out to multiple SQS queues, each processed by a different
consumer. This decouples the fan-out from the processing rate.

---

## 13. Terraform Resources

### Always Created by SQS Renderer
1. `aws_sqs_queue` -- the queue with visibility timeout, retention, and tags

### Conditionally Created
- `aws_sqs_queue_policy` -- when S3, SNS, or EventBridge sends to this queue
  (consolidated single policy with multiple statements)

### Created by Other Renderers
- `aws_s3_bucket_notification` -- S3 renderer (S3 -> SQS)
- `aws_sns_topic_subscription` -- SNS renderer (SNS -> SQS)
- `aws_cloudwatch_event_target` -- CloudWatch/EventBridge renderer
- `aws_lambda_event_source_mapping` -- Lambda renderer (SQS -> Lambda)

---

## 14. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `QueueDoesNotExist` | Queue not found | Verify terraform apply completed |
| `InvalidMessageContents` / `MessageTooLong` | Message > 256 KB | Use claim-check pattern (store in S3, reference in SQS) |
| `OverLimit` / `TooManyEntriesInBatchRequest` | Batch > 10 entries | Split into chunks of 10 |
| `AccessDenied` | Missing IAM permission | Add sqs:SendMessage/ReceiveMessage/DeleteMessage |
| `QueueDeletedRecently` | Recreating within 60s of delete | Wait 60 seconds |
| `PurgeQueueInProgress` | Purge already running | Wait 60 seconds |
| `KmsAccessDenied` | KMS key issue | Verify key and kms:GenerateDataKey/kms:Decrypt permissions |
| `InvalidParameterValue` (MessageGroupId) | FIFO requires MessageGroupId | Include MessageGroupId in SendMessage |
| `ReceiptHandleIsInvalid` | Handle expired or message deleted | Increase visibility timeout or handle error |
| `InvalidAttributeName` | Bad attribute name/value | Check attribute name spelling and value range |

---

## 15. Security Best Practices

1. **Enable encryption**: SSE-SQS is free and on by default. Use SSE-KMS for audit trail.
2. **Use queue policies**: Restrict which services/accounts can send messages.
3. **Enforce HTTPS**: Use `aws:SecureTransport` condition in queue policy.
4. **Least privilege IAM**: Only grant specific sqs: actions on specific queue ARNs.
5. **Configure DLQ**: Catch and investigate failed messages instead of losing them.
6. **Set appropriate retention**: Don't keep messages longer than needed.
7. **Use long polling**: Reduces costs and false-empty responses.
8. **Monitor queue depth**: CloudWatch `ApproximateNumberOfMessages` metric.
9. **Set visibility timeout correctly**: At least 6x Lambda timeout for ESM triggers.
10. **Use FIFO for ordering requirements**: Don't rely on Standard queue ordering.

---

## 16. Monitoring in Our Pipeline

SQS has no native CloudWatch Log Group. For pipeline run monitoring, the log
aggregator uses **CloudTrail LookupEvents** filtered by queue ARN. This has a
5-15 minute delivery delay compared to real-time CloudWatch Logs.

### Key CloudWatch Metrics (AWS/SQS namespace)
- `ApproximateNumberOfMessagesVisible` -- messages available to receive
- `ApproximateNumberOfMessagesNotVisible` -- messages being processed (in-flight)
- `ApproximateNumberOfMessagesDelayed` -- messages in delay period
- `NumberOfMessagesSent` -- messages sent to queue
- `NumberOfMessagesReceived` -- messages received from queue
- `NumberOfMessagesDeleted` -- messages deleted
- `ApproximateAgeOfOldestMessage` -- age of oldest message (useful for DLQ monitoring)
- `SentMessageSize` -- size of messages sent

---

## 17. Queue URL Format

The queue URL is the primary identifier used in all SQS API calls:

```
https://sqs.REGION.amazonaws.com/ACCOUNT-ID/QUEUE-NAME
```

In Terraform, the queue URL is available as `aws_sqs_queue.LABEL.url` or
`aws_sqs_queue.LABEL.id` (both return the URL).

---

## 18. Message Lifecycle

1. **Producer sends message** to queue (message becomes "available")
2. **Consumer receives message** (message becomes "in-flight", visibility timeout starts)
3. **Consumer processes message** (business logic)
4. **Consumer deletes message** (message removed from queue)
5. If consumer fails/times out, visibility timeout expires and message becomes "available" again
6. After `maxReceiveCount` failures, message moves to DLQ (if configured)
7. After retention period expires, message is automatically deleted

---

## 19. Large Message Pattern (Claim Check)

For messages larger than 256 KB, use the claim-check pattern:
1. Store the large payload in S3
2. Send a small SQS message containing the S3 bucket and key
3. Consumer reads the SQS message, then fetches the full payload from S3

AWS provides the `amazon-sqs-java-extended-client-lib` for Java and similar
libraries for other languages that automate this pattern.
