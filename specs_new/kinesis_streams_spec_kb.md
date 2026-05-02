# Amazon Kinesis Data Streams -- Complete Knowledge Base

> This document is the plain-English reference for Kinesis Data Streams that the
> pipeline engine framework and developer agent can consult when handling any
> Kinesis Streams-related request in a pipeline. It covers what Kinesis Streams
> is, how it works, every feature, integration patterns, security, performance,
> and troubleshooting -- written for an agent that needs to reason about Kinesis
> Streams in context, not just look up API parameters.

---

## 1. What Is Kinesis Data Streams?

Amazon Kinesis Data Streams is a real-time data streaming service. You send data
records into a **stream**, and one or more consumers read those records within
seconds (or milliseconds with Enhanced Fan-Out). Unlike SQS (where a message is
consumed once and deleted), Kinesis records persist for a configurable retention
period (24 hours to 365 days) and can be read by multiple independent consumers.

Kinesis Streams is the "front door" for real-time pipelines. It sits between
producers (applications, IoT devices, log agents, etc.) and consumers (Lambda,
Kinesis Analytics, Kinesis Firehose, EMR, custom KCL applications on EC2).

### Core Concepts

- **Stream**: A named, ordered sequence of data records. Contains one or more
  shards.
- **Shard**: The base throughput unit. Each shard supports 1 MB/s write and
  2 MB/s read. Records are distributed across shards by partition key hash.
- **Record**: A blob of data (up to 1 MB) with a partition key, sequence number,
  and timestamp.
- **Partition Key**: A string that determines which shard receives the record.
  Kinesis hashes the key (MD5) to map it to a shard's hash key range.
- **Sequence Number**: A unique, monotonically increasing identifier assigned to
  each record within a shard.
- **Retention Period**: How long records stay in the stream (24h-8760h). Records
  are immutable and cannot be deleted individually.

### NOT Free Tier

Kinesis Streams is never free tier eligible. Costs depend on capacity mode:
- **ON_DEMAND**: ~$0.08/GB ingested + $0.04/shard-hour (auto-scaled)
- **PROVISIONED**: ~$0.015/shard-hour + $0.014/million PUT payload units
- Enhanced Fan-Out adds $0.013/shard-hour/consumer + $0.013/GB retrieved

---

## 2. Capacity Modes

### ON_DEMAND (Recommended for Most Use Cases)

ON_DEMAND mode auto-scales shard count based on throughput. No capacity planning
is needed. The stream starts at 4 MB/s write capacity (equivalent to 4 shards)
and can scale to 200 MB/s. AWS handles shard splits and merges automatically.

When to use ON_DEMAND:
- New streams with unknown traffic patterns
- Bursty or variable workloads
- When simplicity matters more than cost optimization

In Terraform, when `stream_mode = "ON_DEMAND"`, the `shard_count` attribute is
ignored -- AWS manages it.

### PROVISIONED

PROVISIONED mode gives you a fixed number of shards that you manage. You must
call `update_shard_count` (or change Terraform `shard_count`) to scale up or
down. Lower per-GB cost for predictable, steady workloads.

**Scaling constraint**: You cannot more than double or halve the shard count in
a single operation. To go from 10 to 100 shards, you need multiple steps:
10 -> 20 -> 40 -> 80 -> 100. Each step requires the stream to be ACTIVE first.

### Switching Between Modes

You can switch between ON_DEMAND and PROVISIONED at any time, but only twice
in 24 hours. The switch takes effect immediately.

---

## 3. The Shard Model

Each shard provides:
- **Write**: 1 MB/s or 1000 records/s (whichever limit is hit first)
- **Read (shared)**: 2 MB/s shared across ALL GetRecords consumers
- **Read (Enhanced Fan-Out)**: 2 MB/s dedicated per consumer per shard

### Partition Key Design

Good partition key design is critical for even distribution. If all records use
the same partition key, they all go to one shard, creating a "hot shard" that
throttles while other shards sit idle.

**Good keys**: Device ID, user ID, UUID, session ID (high cardinality)
**Bad keys**: Date, region name, "default" (low cardinality)

For precise control, use `ExplicitHashKey` to bypass the partition key hash and
target a specific shard directly.

### Resharding

- **Split**: Divide a shard into two child shards (doubles capacity for that
  hash range)
- **Merge**: Combine two adjacent shards (halves capacity)
- **Update Shard Count**: Change the total shard count. Uses `UNIFORM_SCALING`
  to redistribute hash ranges evenly.

After resharding, parent shards become read-only. Consumers must finish reading
the parent before switching to children. KCL handles this automatically.

---

## 4. Consumers

### Shared Throughput (GetRecords)

The default consumption mode. Consumers poll `GetRecords` in a loop:
1. Call `get_shard_iterator` with a starting position
2. Call `get_records` with the iterator (returns up to 10 MB or 10000 records)
3. Use `NextShardIterator` from the response for the next call
4. Repeat

**Limits**: 5 GetRecords calls per shard per second. 2 MB/s read throughput
shared across all consumers. The iterator expires after 5 minutes of inactivity
(ExpiredIteratorException -- just get a new one).

**Starting positions**:
- `TRIM_HORIZON`: Start from the oldest record
- `LATEST`: Start from the newest record (skip history)
- `AT_TIMESTAMP`: Start from a specific time
- `AT_SEQUENCE_NUMBER` / `AFTER_SEQUENCE_NUMBER`: Start from a specific record

### Enhanced Fan-Out (SubscribeToShard)

Dedicated 2 MB/s per consumer per shard. Data is pushed via HTTP/2 -- no
polling. ~70ms average latency (vs ~200ms for GetRecords).

Each stream supports up to 20 Enhanced Fan-Out consumers. Each consumer must
be registered first (`register_stream_consumer`), then subscribe
(`subscribe_to_shard`). Each subscription lasts 5 minutes; the consumer must
re-subscribe.

**When to use EFO**: Multiple consumers on the same stream, low-latency
requirements, or more than 2 consumers. The extra cost ($0.013/shard-hour/consumer)
is justified by dedicated throughput and lower latency.

---

## 5. Retention

Records persist in the stream for the retention period. The default is 24 hours,
minimum is 24 hours, maximum is 8760 hours (365 days).

- Records are immutable: you cannot update or delete individual records
- Records are automatically purged after the retention period
- Extended retention (>24h) costs extra: $0.023/shard-hour for up to 7 days,
  $0.012/GB for long-term retention (>7 days)

If you need to reprocess data, replay from any point using `AT_TIMESTAMP` or
`TRIM_HORIZON` iterator types. This is a key advantage over SQS.

---

## 6. Encryption

### At Rest

Server-side encryption using KMS. Set `encryption_type = "KMS"` in Terraform.
By default, uses the AWS-managed key `alias/aws/kinesis`. You can specify a
customer-managed KMS key via `kms_key_id`.

When encryption is enabled:
- Producers need `kms:GenerateDataKey` permission
- Consumers need `kms:Decrypt` permission

### In Transit

All Kinesis API calls use HTTPS (TLS). There is no option to disable encryption
in transit.

---

## 7. Integration Patterns in the Pipeline Engine

### Kinesis Streams as Input Source

| Consumer | How It Connects | Terraform Resource |
|---|---|---|
| **Lambda** | Event source mapping (polling) | `aws_lambda_event_source_mapping` |
| **Kinesis Firehose** | Source configuration | `kinesis_source_configuration` block |
| **Kinesis Analytics** | Input configuration | `inputs` block with `kinesis_streams_input` |
| **EMR** | Spark/Flink Kinesis connector | None (code-level) |
| **EC2** | KCL or SDK | None (code-level) |
| **EventBridge Pipes** | Pipe source | `aws_pipes_pipe` |

### Kinesis Streams as Output Target

| Producer | How It Writes | API |
|---|---|---|
| **Lambda** | boto3 kinesis.put_record(s) | PutRecord / PutRecords |
| **EC2** | SDK or Kinesis Agent | PutRecord / PutRecords |
| **Kinesis Analytics** | Output configuration | SQL output or Flink Kinesis sink |
| **Step Functions** | SDK integration | PutRecord / PutRecords |
| **DMS** | Target endpoint | PutRecord |
| **CloudWatch Logs** | Subscription filter | Internal |

### Lambda Event Source Mapping

The most common consumer pattern. Lambda automatically polls the stream, invokes
your function with batches of records, and manages checkpointing.

Key configuration:
- `batch_size`: Records per invocation (1-10000, default 100)
- `starting_position`: TRIM_HORIZON or LATEST
- `parallelization_factor`: 1-10 concurrent Lambda invocations per shard
- `bisect_batch_on_error`: true (retry each half of a failed batch)
- `maximum_retry_attempts`: 0-10000 (default 10000 = retry indefinitely)
- `maximum_record_age_in_seconds`: Skip records older than this (604800s max)

The Lambda renderer creates the `aws_lambda_event_source_mapping` resource and
adds the required IAM permissions (`kinesis:GetRecords`, `kinesis:GetShardIterator`,
`kinesis:DescribeStream`, `kinesis:ListShards`, `kinesis:ListStreams`).

---

## 8. Monitoring

### CloudWatch Metrics (AWS/Kinesis namespace)

Key metrics to watch:
- `IncomingBytes` / `IncomingRecords`: Write throughput
- `GetRecords.Bytes` / `GetRecords.Records`: Read throughput
- `GetRecords.IteratorAgeMilliseconds`: Consumer lag (higher = falling behind)
- `ReadProvisionedThroughputExceeded`: Hot shard reads
- `WriteProvisionedThroughputExceeded`: Hot shard writes
- `SubscribeToShard.RateExceeded`: EFO subscription limit

### Pipeline Run Monitor

Kinesis Streams is monitored via **CloudTrail** in the pipeline run monitor
(not CloudWatch Logs). The log aggregator looks for CloudTrail events on the
stream ARN. This means log events have a 5-15 minute delivery delay.

---

## 9. Common Error Patterns and Fixes

### ProvisionedThroughputExceededException

**Cause**: A shard's throughput limit was exceeded. Common when partition keys
have poor distribution (hot shard).

**Fix**:
1. Check partition key distribution -- are most records going to one shard?
2. If yes, redesign the partition key for higher cardinality
3. If no, increase shard count: `update_shard_count(TargetShardCount=current*2)`
4. Consider switching to ON_DEMAND mode

### ExpiredIteratorException

**Cause**: GetRecords iterator expired after 5 minutes of inactivity.

**Fix**: Just call `get_shard_iterator` again. This is normal -- iterators are
designed to be short-lived. If using KCL, this is handled automatically.

### ResourceInUseException

**Cause**: Stream is being created, deleted, or scaled -- cannot modify.

**Fix**: Wait for stream status to become ACTIVE, then retry.

### KMS Access Issues

**Cause**: Consumer/producer IAM role lacks KMS permissions on encrypted stream.

**Fix**: Add `kms:Decrypt` (consumers) or `kms:GenerateDataKey` (producers) to
the IAM role, with the stream's KMS key as the resource.

---

## 10. Terraform Pattern in the Pipeline Engine

The `_render_kinesis_streams` function in `hcl_renderer.py` generates a minimal
Kinesis stream resource:

```hcl
resource "aws_kinesis_stream" "LABEL" {
  name             = "NAME"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = { ... }
}
```

Key points:
- The stream has NO CloudWatch Log Group (Kinesis Streams does not support
  native CW Logs). It is monitored via CloudTrail in the pipeline run monitor.
- The `shard_count` is set to 1 but ignored when `stream_mode = "ON_DEMAND"`.
- The stream itself has no IAM role (it is passive). IAM is on the consumers
  and producers.
- Tags are mandatory via `_tags_block(bp)`.

---

## 11. Best Practices

1. **Start with ON_DEMAND** unless you know your throughput precisely. You can
   always switch to PROVISIONED later for cost optimization.

2. **Design partition keys carefully**. High-cardinality keys (UUID, device ID)
   distribute evenly. Low-cardinality keys (date, region) create hot shards.

3. **Use Enhanced Fan-Out** when you have multiple consumers on the same stream
   or need sub-100ms latency.

4. **Set appropriate retention**. 24 hours is usually sufficient. Extended
   retention is expensive. If you need long-term storage, use Kinesis Firehose
   to deliver to S3.

5. **Monitor `IteratorAgeMilliseconds`**. If this metric increases over time,
   your consumer is falling behind and you need more shards or parallelism.

6. **Handle partial failures in batch puts**. `put_records` can have partial
   failures -- check `FailedRecordCount` and retry only the failed records with
   exponential backoff.

7. **Use batch operations**. `put_records` (up to 500 records / 5 MB) is much
   more efficient than calling `put_record` in a loop.

---

## 12. Kinesis Streams vs SQS vs SNS

| Feature | Kinesis Streams | SQS | SNS |
|---|---|---|---|
| **Model** | Ordered log | Message queue | Pub/sub |
| **Retention** | 24h-365d | 4d-14d | No retention |
| **Consumers** | Multiple (parallel) | Single (competing) | Multiple (fan-out) |
| **Ordering** | Per-shard (by partition key) | FIFO only | None |
| **Replay** | Yes (from any point) | No | No |
| **Throughput** | 1 MB/s/shard write | 3000 msg/s (FIFO) | Unlimited |
| **Cost** | Per shard-hour + data | Per request | Per publish + delivery |
| **Best for** | Real-time analytics, log ingestion | Task queues, decoupling | Notifications, fan-out |

Choose Kinesis Streams when you need ordered, replayable, multi-consumer data
streaming. Choose SQS when you need a simple work queue. Choose SNS when you
need to broadcast messages to multiple subscribers.

---

## 13. Developer Agent Patterns

When working with Kinesis Streams via the developer agent:

**Writing data**:
```python
kinesis = boto3.client('kinesis')
kinesis.put_record(
    StreamName='my-stream',
    Data=json.dumps({'key': 'value'}).encode(),
    PartitionKey='device-123'
)
```

**Reading data** (low-level -- prefer Lambda event source mapping):
```python
shard_iterator = kinesis.get_shard_iterator(
    StreamName='my-stream',
    ShardId='shardId-000000000000',
    ShardIteratorType='TRIM_HORIZON'
)['ShardIterator']

response = kinesis.get_records(ShardIterator=shard_iterator, Limit=100)
for record in response['Records']:
    data = json.loads(record['Data'])
```

**Checking stream status**:
```python
summary = kinesis.describe_stream_summary(StreamName='my-stream')
print(summary['StreamDescriptionSummary']['StreamStatus'])
print(summary['StreamDescriptionSummary']['OpenShardCount'])
```

**Scaling** (PROVISIONED mode):
```python
kinesis.update_shard_count(
    StreamName='my-stream',
    TargetShardCount=4,
    ScalingType='UNIFORM_SCALING'
)
```
