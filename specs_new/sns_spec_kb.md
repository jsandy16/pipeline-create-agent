# Amazon SNS -- Complete Knowledge Base

> This document is the plain-English reference for SNS that the pipeline engine
> framework and developer agent can consult when handling any SNS-related request
> in a pipeline. It covers what SNS is, how it works, every feature, integration
> patterns, security, performance, and troubleshooting -- written for an agent
> that needs to reason about SNS in context, not just look up API parameters.

---

## 1. What Is SNS?

Amazon Simple Notification Service (SNS) is a fully managed pub/sub messaging
service. You publish messages to a **topic**, and SNS delivers them to all
**subscribers** of that topic. Subscribers can be SQS queues, Lambda functions,
HTTP/HTTPS endpoints, email addresses, SMS numbers, or Kinesis Firehose streams.

SNS is a **passive** service in our pipeline engine -- it has no execution role
and does not initiate actions on its own. It acts as a message router, receiving
publishes from producer services and fanning out to consumer services.

### Core Concepts
- **Topic**: A named channel for publishing messages. Messages published to a topic are delivered to all confirmed subscribers.
- **Subscription**: A connection between a topic and an endpoint (SQS, Lambda, HTTP, etc.). Each subscription specifies the protocol and endpoint.
- **Publisher**: A service or application that sends messages to a topic.
- **Subscriber**: An endpoint that receives messages from a topic.
- **Message**: A payload (up to 256 KB) with optional attributes and subject line.
- **Filter Policy**: A JSON policy on a subscription that controls which messages the subscriber receives.

### Free Tier
SNS is always-free tier: 1 million publishes/month, 100,000 HTTP/S deliveries,
and 1,000 email deliveries per month.

---

## 2. Topic Types

### Standard Topic (Default)
- **Throughput**: Nearly unlimited (30,000 publishes/second default, adjustable)
- **Ordering**: Best-effort (no ordering guarantee)
- **Delivery**: At-least-once (messages may be delivered more than once)
- **Deduplication**: None
- **Supported protocols**: SQS, Lambda, HTTP/S, email, SMS, mobile push, Firehose
- **Use cases**: Fan-out, event broadcasting, alert notifications

### FIFO Topic
- **Throughput**: 300 messages/second per topic (30,000 per message group with high throughput)
- **Ordering**: Strict FIFO within each message group
- **Delivery**: Exactly-once via deduplication (5-minute window)
- **Deduplication**: Content-based (SHA-256 of body) or explicit (MessageDeduplicationId)
- **Supported protocols**: SQS FIFO queues **only**
- **Topic name**: Must end with `.fifo` suffix

**FIFO constraints:**
- Can ONLY deliver to SQS FIFO queues
- Lambda, HTTP/S, email, SMS CANNOT subscribe to FIFO topics
- S3 event notifications CANNOT publish to FIFO topics
- Every publish must include `MessageGroupId`

---

## 3. Subscriptions

A subscription connects a topic to an endpoint. SNS supports multiple protocols:

| Protocol | Endpoint | Confirmation | Raw Delivery | Cross-Account |
|---|---|---|---|---|
| **sqs** | SQS queue ARN | Automatic | Yes | Yes |
| **lambda** | Lambda function ARN | Automatic | No | Yes |
| **http** | HTTP URL | Manual (confirm endpoint) | Yes | No |
| **https** | HTTPS URL | Manual (confirm endpoint) | Yes | No |
| **email** | Email address | Manual (email link) | No | No |
| **email-json** | Email address | Manual (email link) | No | No |
| **sms** | Phone number (E.164) | Automatic (opt-out) | No | No |
| **application** | Platform endpoint ARN | Automatic | No | No |
| **firehose** | Firehose stream ARN | Automatic | Yes | Yes |

### Raw Message Delivery
By default, SNS wraps the message in a JSON envelope containing metadata
(MessageId, TopicArn, Timestamp, etc.). With **raw message delivery** enabled
(SQS, HTTP/S, Firehose), the subscriber receives the raw message body without
the SNS wrapper.

### Subscription Confirmation
- **Automatic**: SQS, Lambda, Firehose, mobile push, SMS
- **Manual**: HTTP/S endpoints must respond to a confirmation URL. Email recipients must click a confirmation link.

---

## 4. Message Filtering

Filter policies allow subscribers to receive only the messages they care about,
reducing costs and simplifying consumer logic.

### Filter Policy Scopes
1. **MessageAttributes** (default): Filter based on message attributes sent with Publish
2. **MessageBody**: Filter based on the JSON message body content

### Filter Operators

| Operator | Description | Example |
|---|---|---|
| Exact match | Value equals one of the specified values | `{"store": ["example_corp"]}` |
| Prefix | Value starts with prefix | `{"interest": [{"prefix": "bas"}]}` |
| Suffix | Value ends with suffix | `{"file": [{"suffix": ".png"}]}` |
| Anything-but | Value does NOT match | `{"store": [{"anything-but": ["corp"]}]}` |
| Numeric | Numeric comparison (=, >, >=, <, <=, between) | `{"price": [{"numeric": [">=", 100]}]}` |
| Exists | Attribute exists or not | `{"store": [{"exists": true}]}` |
| IP address | CIDR range match | `{"ip": [{"cidr": "10.0.0.0/24"}]}` |

### Filter Logic
- **AND** between different attribute keys
- **OR** between values within the same attribute key
- Unmatched messages are silently discarded (not delivered to that subscriber)

### Limits
- Max 5 attribute keys per filter policy (adjustable to 100)
- Max 150 values per attribute
- Max 256 KB total filter policy size
- Max 200 filter policies per topic (adjustable)

---

## 5. Fan-Out Pattern

The fan-out pattern is SNS's primary use case in our pipeline engine. A single
published message is delivered to multiple subscribers simultaneously.

### SNS -> SQS Fan-Out (Most Common)
One SNS topic fans out to N SQS queues. Each queue gets its own copy of the
message and processes it independently.

**Benefits:**
- Parallel processing without coordination
- Independent failure isolation per consumer
- Message filtering per subscription
- DLQ per queue for failed processing
- Consumers process at their own rate

**Terraform resources:**
1. `aws_sns_topic` -- the fan-out hub
2. `aws_sns_topic_subscription` (protocol: sqs) -- one per queue
3. `aws_sqs_queue_policy` on each queue -- allows sns.amazonaws.com

### SNS -> Lambda Fan-Out
One SNS topic invokes N Lambda functions. Each function processes the message
independently. Simpler than SQS fan-out but no buffering or DLQ on the
SNS-to-Lambda hop.

### S3 -> SNS -> Multiple Consumers
When multiple consumers need S3 event notifications:
1. S3 sends notification to SNS topic (one notification config)
2. SNS fans out to multiple SQS queues and/or Lambda functions
3. Each consumer processes independently

This is preferred over S3's native multi-Lambda notification when you need
buffering or more than a few consumers.

---

## 6. Encryption

### In Transit
All SNS communication uses HTTPS (TLS) by default.

### At Rest (SSE-KMS)
Optional server-side encryption using AWS KMS keys.

- **Terraform attribute**: `kms_master_key_id`
- **Cost**: KMS API charges
- **Publisher needs**: `kms:GenerateDataKey`, `kms:Decrypt`
- **Subscriber needs**: `kms:Decrypt`

**Constraint**: S3 event notifications cannot publish to SSE-KMS encrypted
topics unless using the `aws/sns` managed key. Some AWS services cannot publish
to encrypted topics without additional KMS permissions.

---

## 7. Delivery Retry Policies

SNS retries failed deliveries based on the protocol:

| Protocol | Retry Behavior | Configurable | DLQ Support |
|---|---|---|---|
| SQS | 23 retries over 23 minutes | No | Yes |
| Lambda | 3 retries (0s, 1s, 2s) | No | Yes |
| HTTP/S | Up to 100 retries over 23 days | Yes (delivery policy) | Yes |
| Email | Minimal | No | No |
| SMS | Minimal | No | No |

### Subscription-Level Dead Letter Queue
For SQS, Lambda, and HTTP/S subscriptions, you can configure a DLQ (SQS queue)
to receive messages that SNS cannot deliver after exhausting retries.

```json
{"deadLetterTargetArn": "arn:aws:sqs:REGION:ACCOUNT:my-topic-dlq"}
```

---

## 8. Data Protection Policies

SNS message data protection detects and protects sensitive data (PII, PHI)
in messages using pattern matching.

**Operations:**
- **Audit**: Log matched patterns to CloudWatch, S3, or Firehose
- **De-identify**: Mask sensitive data before delivery
- **Deny**: Block messages containing sensitive data

**Supported data types**: Credit card numbers, SSN, phone numbers, email
addresses, AWS access keys, custom regex patterns.

---

## 9. IAM Permissions Reference

SNS is a passive service -- it does not have an execution role. Permissions
are needed by the **callers** (publishers and subscribers).

### Complete Action List

| Action | Description | Access Level |
|---|---|---|
| `sns:Publish` | Publish message to topic/phone/endpoint | Write |
| `sns:Subscribe` | Create subscription | Write |
| `sns:Unsubscribe` | Remove subscription | Write |
| `sns:ConfirmSubscription` | Confirm pending subscription | Write |
| `sns:CreateTopic` | Create a new topic | Write |
| `sns:DeleteTopic` | Delete topic and all subscriptions | Write |
| `sns:GetTopicAttributes` | Get topic attributes | Read |
| `sns:SetTopicAttributes` | Set topic attributes | Write |
| `sns:GetSubscriptionAttributes` | Get subscription attributes | Read |
| `sns:SetSubscriptionAttributes` | Set subscription attributes | Write |
| `sns:ListTopics` | List all topics | List |
| `sns:ListSubscriptions` | List all subscriptions | List |
| `sns:ListSubscriptionsByTopic` | List subscriptions for a topic | List |
| `sns:ListTagsForResource` | List tags on a topic | Read |
| `sns:AddPermission` | Add statement to topic policy | Permissions |
| `sns:RemovePermission` | Remove statement from topic policy | Permissions |
| `sns:TagResource` | Add tags | Tagging |
| `sns:UntagResource` | Remove tags | Tagging |
| `sns:GetDataProtectionPolicy` | Get data protection policy | Read |
| `sns:PutDataProtectionPolicy` | Set data protection policy | Write |

### Common Permission Sets in Our Pipeline
- **Publisher (Lambda -> SNS)**: `sns:Publish`
- **Subscriber (Lambda receives from SNS)**: `sns:Subscribe`, `sns:Receive`
- **Admin**: All of the above + Create/Delete/Set/Get attributes

### ARN Formats
- Topic: `arn:aws:sns:REGION:ACCOUNT:TOPIC-NAME`
- Subscription: `arn:aws:sns:REGION:ACCOUNT:TOPIC-NAME:SUBSCRIPTION-ID`

---

## 10. Service Quotas

| Quota | Limit |
|---|---|
| Topics per account per region | 100,000 (adjustable) |
| Topic name max length | 256 characters |
| Subscriptions per topic | 12,500,000 (adjustable) |
| Max message size | 256 KB |
| Max message attributes | 10 per message |
| Max filter policies per topic | 200 (adjustable) |
| Max filter policy size | 256 KB |
| Max filter attributes per policy | 5 (adjustable to 100) |
| Standard publish rate | 30,000/second (adjustable) |
| FIFO publish rate | 300/second (30,000 per group with high throughput) |
| Max tags per topic | 50 |
| Data protection policies | 1 per topic |

---

## 11. Integration Patterns in Our Pipeline Engine

### SNS as Message Router (Receives Publishes)

**Lambda -> SNS**:
Lambda calls `sns:Publish` with the topic ARN. Lambda renderer adds IAM
permission and environment variable `{PEER}_TOPIC_ARN`.

**S3 -> SNS**:
S3 renderer creates `aws_s3_bucket_notification` (topic block). Standard
topics only -- FIFO topics not supported.

**EventBridge -> SNS**:
EventBridge renderer creates `aws_cloudwatch_event_target`. SNS topic policy
should allow `events.amazonaws.com` to publish.

**Step Functions -> SNS**:
Step Functions publishes to SNS via SDK integration. Execution role needs
`sns:Publish`.

### SNS as Delivery Hub (Delivers to Subscribers)

**SNS -> SQS**:
SNS renderer creates `aws_sns_topic_subscription` (protocol: sqs). SQS
renderer creates `aws_sqs_queue_policy` allowing `sns.amazonaws.com`.

**SNS -> Lambda**:
SNS renderer creates `aws_sns_topic_subscription` (protocol: lambda). Lambda
receives the message wrapped in an SNS event structure.

### Wiring Ownership Rules
| Wiring | Owned By | Resources Created |
|---|---|---|
| S3 -> SNS notification | S3 fragment | `aws_s3_bucket_notification` (topic block) |
| SNS -> SQS subscription | SNS fragment | `aws_sns_topic_subscription` |
| SNS -> Lambda subscription | SNS fragment | `aws_sns_topic_subscription` |
| SQS queue policy for SNS | SQS fragment | `aws_sqs_queue_policy` |

---

## 12. Terraform Resources

### Always Created by SNS Renderer
1. `aws_sns_topic` -- the topic with name and tags

### Conditionally Created
- `aws_sns_topic_subscription` -- one per outgoing integration (SQS, Lambda)

### Created by Other Renderers
- `aws_s3_bucket_notification` -- S3 renderer (S3 -> SNS)
- `aws_sqs_queue_policy` -- SQS renderer (allows sns.amazonaws.com)
- `aws_cloudwatch_event_target` -- CloudWatch/EventBridge renderer (EventBridge -> SNS)

### Not Currently in Default Renderer
- `aws_sns_topic_policy` -- for custom access control
- `aws_sns_topic_data_protection_policy` -- for PII detection/masking
- `aws_sns_platform_application` -- for mobile push notifications

---

## 13. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `AuthorizationError` | Missing `sns:Publish` permission | Add `sns:Publish` to caller's IAM role |
| `NotFound` / `InvalidParameter` (TopicArn) | Topic does not exist | Verify terraform apply completed |
| `InvalidParameter` (Protocol/Endpoint) | Bad subscription config | Verify protocol and endpoint format |
| `SubscriptionLimitExceeded` | Too many subscriptions | Request limit increase |
| `FilterPolicyLimitExceeded` | Too many filter policies | Consolidate filters or request increase |
| `InvalidSecurity` / KMS error | KMS key issue | Verify key and kms:Decrypt permissions |
| `MessageTooLong` | Message > 256 KB | Reduce size or use claim-check pattern |
| `InvalidParameter` (MessageGroupId) | FIFO topic missing group ID | Include MessageGroupId in Publish |
| `EndpointDisabled` | Subscription endpoint disabled | Re-enable or re-confirm |
| `ThrottledException` | Publish rate exceeded | Exponential backoff, request limit increase |

---

## 14. Security Best Practices

1. **Use topic policies**: Restrict who can publish and subscribe
2. **Enforce HTTPS**: Add `aws:SecureTransport` condition to topic policy
3. **Enable SSE-KMS**: For sensitive message content (with Bucket Key equivalent: consider cost)
4. **Least privilege IAM**: Only grant `sns:Publish` to publishers, `sns:Subscribe` to subscribers
5. **Use filter policies**: Reduce unnecessary message delivery
6. **Configure subscription DLQs**: For SQS, Lambda, HTTP/S subscriptions
7. **Enable data protection**: Detect and mask PII/PHI in messages
8. **Confirm subscriptions**: Verify HTTP/S and email subscriptions are confirmed
9. **Monitor delivery failures**: CloudWatch metrics for failed deliveries
10. **Use raw message delivery**: For SQS and HTTP/S subscribers to reduce overhead

---

## 15. Monitoring in Our Pipeline

SNS has no native CloudWatch Log Group. For pipeline run monitoring, the log
aggregator uses **CloudTrail LookupEvents** filtered by topic ARN. This has a
5-15 minute delivery delay compared to real-time CloudWatch Logs.

### Key CloudWatch Metrics (AWS/SNS namespace)
- `NumberOfMessagesPublished` -- messages published to topic
- `NumberOfNotificationsDelivered` -- successful deliveries
- `NumberOfNotificationsFailed` -- failed deliveries
- `NumberOfNotificationsFilteredOut` -- messages filtered by subscription policies
- `PublishSize` -- size of published messages
- `SMSMonthToDateSpentUSD` -- SMS spending

---

## 16. Message Structure

### Standard Published Message
When publishing, you provide:
- `Message`: The payload (string, max 256 KB)
- `Subject`: Optional, used for email subscriptions (max 100 chars)
- `MessageAttributes`: Optional structured metadata (up to 10)
- `MessageStructure`: Set to "json" for per-protocol message customization

### Per-Protocol Messages
Set `MessageStructure` to "json" and provide a JSON object with protocol-specific messages:
```json
{
  "default": "Default message for all protocols",
  "sqs": "SQS-specific message",
  "lambda": "Lambda-specific message",
  "email": "Email-specific message"
}
```
The `default` key is required when using `MessageStructure: json`.

### SNS Message Envelope (Delivered to Subscribers)
Unless raw message delivery is enabled, subscribers receive a JSON envelope:
```json
{
  "Type": "Notification",
  "MessageId": "uuid",
  "TopicArn": "arn:aws:sns:...",
  "Subject": "optional subject",
  "Message": "the actual message body",
  "Timestamp": "ISO 8601",
  "SignatureVersion": "1",
  "Signature": "base64 signature",
  "SigningCertURL": "https://...",
  "UnsubscribeURL": "https://...",
  "MessageAttributes": { ... }
}
```

---

## 17. Topic Policy vs IAM Policy

SNS uses two types of policies for access control:

### Topic Policy (Resource-Based)
Attached to the topic itself. Controls which AWS accounts, services, or
principals can publish to or subscribe to the topic. Used when S3, EventBridge,
or other accounts need to interact with the topic.

### IAM Policy (Identity-Based)
Attached to the IAM role/user of the caller. Controls which topics the caller
can interact with. Used for Lambda execution roles, Step Functions roles, etc.

Both policies are evaluated together. An explicit Deny in either policy
overrides an Allow.

---

## 18. SNS vs SQS: When to Use Which

| Aspect | SNS | SQS |
|---|---|---|
| Pattern | Pub/sub (fan-out) | Point-to-point (queue) |
| Delivery | Push to subscribers | Pull by consumers |
| Persistence | No (deliver and forget) | Yes (messages stored until consumed) |
| Multiple consumers | Yes (fan-out to all subscribers) | No (one consumer gets each message) |
| Ordering | Best-effort (Standard) or FIFO | Best-effort (Standard) or FIFO |
| Message filtering | Yes (filter policies) | No (consumer processes all messages) |
| DLQ | Subscription-level | Queue-level |
| Retry | Protocol-dependent | Visibility timeout + redrive |

**Common combination**: SNS + SQS for fan-out with buffering. Publish to SNS,
subscribe multiple SQS queues, each with its own consumer and DLQ.
