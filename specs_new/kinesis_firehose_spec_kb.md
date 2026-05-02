# Amazon Kinesis Data Firehose -- Complete Knowledge Base

> This document is the plain-English reference for Kinesis Data Firehose that the
> pipeline engine framework and developer agent can consult when handling any
> Firehose-related request in a pipeline. It covers what Firehose is, how it
> works, every feature, integration patterns, security, performance, and
> troubleshooting.

---

## 1. What Is Kinesis Data Firehose?

Amazon Kinesis Data Firehose is a fully managed service for loading streaming
data into data stores and analytics services. Unlike Kinesis Data Streams (where
you write consumer code), Firehose handles the delivery automatically. You send
records to a delivery stream, and Firehose buffers, optionally transforms and
compresses them, then delivers to the configured destination.

Think of Firehose as the "last mile" of a streaming pipeline: it takes a stream
of records and reliably lands them in S3, Redshift, OpenSearch, Splunk, or any
HTTP endpoint.

### Core Concepts

- **Delivery Stream**: A named pipeline that receives records and delivers them
  to a destination. Has a source (Direct PUT or Kinesis Stream or MSK) and
  exactly one destination.
- **Buffer**: Firehose accumulates records until a size threshold OR time
  interval is reached, then delivers a batch. This reduces the number of API
  calls to the destination.
- **Destination**: Where records go (S3, Redshift, OpenSearch, HTTP endpoint,
  Splunk, etc.).
- **Transformation**: Optional Lambda function that transforms each record
  before delivery.
- **Compression**: GZIP, ZIP, Snappy, or HADOOP_SNAPPY applied before delivery.
- **Error Output**: Failed records go to a backup S3 prefix for later analysis.

### NOT Free Tier

Firehose is never free tier eligible. ~$0.029/GB for the first 500 TB/month
ingested (S3 destination). Additional charges for Lambda transformation,
format conversion, and dynamic partitioning.

---

## 2. Source Types

A delivery stream has exactly one source type, chosen at creation time. You
cannot change the source type after creation.

### Direct PUT (Default)

Applications write directly to Firehose via `PutRecord` / `PutRecordBatch`.
This is the default and most common source type. Compatible with:
- Any application using the Firehose SDK
- Kinesis Agent (file tailing agent)
- CloudWatch Logs subscription filters
- CloudWatch Metrics streams
- AWS IoT rules
- EventBridge rules
- Amazon Pinpoint

### Kinesis Data Streams Source

Firehose reads from an existing Kinesis Data Stream. Useful when you already
have a Kinesis stream and want to add S3 archival or Redshift loading without
modifying producers.

In Terraform, this is the `kinesis_source_configuration` block:
```hcl
kinesis_source_configuration {
  kinesis_stream_arn = aws_kinesis_stream.input.arn
  role_arn           = aws_iam_role.firehose_role.arn
}
```

**Constraint**: A delivery stream with a Kinesis stream source cannot also
receive Direct PUT calls.

### MSK Source

Firehose reads from an MSK (Kafka) topic. Available since 2023. In Terraform,
this is the `msk_source_configuration` block.

---

## 3. Destinations

### Extended S3 (Primary)

The most common destination. Firehose delivers batched, optionally compressed
and transformed records to S3. "Extended S3" means the full-featured S3
destination with support for:

- **Buffering**: Size (1-128 MB) and interval (0-900 seconds). Delivery happens
  when either threshold is reached. Set interval to 0 for near-real-time.
- **Compression**: GZIP (default in our engine), ZIP, Snappy, HADOOP_SNAPPY, or UNCOMPRESSED.
- **Encryption**: Uses the bucket's default encryption (SSE-S3 or SSE-KMS).
- **Dynamic Partitioning**: Automatically partition data into S3 prefixes based
  on record content (e.g., year/month/day or customer_id).
- **Format Conversion**: Convert JSON to Parquet or ORC using a Glue Data Catalog
  schema. Parquet is ideal for Athena/Redshift Spectrum queries.
- **Error Output Prefix**: Failed records go to a separate S3 prefix.
- **CloudWatch Logging**: Delivery errors logged to a CloudWatch Log Group.

The pipeline engine renderer always creates the CloudWatch Log Group and Log
Stream for error logging.

### Redshift

Firehose delivers to Redshift by first writing to an intermediate S3 bucket,
then issuing a COPY command. You provide the JDBC URL, credentials, and table
name. Firehose handles the COPY automatically.

**Important**: The intermediate S3 bucket is required even if the final
destination is Redshift. Firehose always goes through S3 first.

### OpenSearch

Firehose indexes records into an OpenSearch domain. Supports buffering,
retry, and automatic S3 backup for failed documents. If the OpenSearch domain
is in a VPC, Firehose needs VPC configuration.

### HTTP Endpoint

Generic HTTP destination for services like Datadog, New Relic, Sumo Logic, or
custom endpoints. Firehose retries for up to 24 hours with exponential backoff.
Backup S3 bucket is required for failed deliveries.

### Splunk

Delivers to Splunk via HTTP Event Collector (HEC). Requires HEC endpoint URL
and token.

---

## 4. Buffering

Firehose buffers incoming records and delivers them in batches. Delivery happens
when EITHER the buffer size OR buffer interval is reached (whichever comes
first).

| Destination | Min Buffer Size | Max Buffer Size | Min Interval | Max Interval |
|---|---|---|---|---|
| S3 | 1 MB | 128 MB | 0 sec | 900 sec |
| Redshift | 1 MB | 128 MB | 0 sec | 900 sec |
| OpenSearch | 1 MB | 100 MB | 0 sec | 900 sec |
| HTTP Endpoint | 1 MB | 64 MB | 0 sec | 900 sec |

**Zero-buffer delivery** (interval = 0) is available for S3 destinations since
2023, enabling near-real-time delivery. Buffer size is measured BEFORE
compression, so actual S3 objects may be smaller.

Our engine defaults: 5 MB size, 60 second interval, GZIP compression. This
provides a good balance of latency and cost.

---

## 5. Data Transformation with Lambda

Firehose can invoke a Lambda function to transform each record before delivery.
This is configured in the `processing_configuration` block.

### How It Works

1. Firehose buffers records up to 3 MB or 1 minute
2. Invokes Lambda with a batch of records (base64-encoded)
3. Lambda processes each record and returns a status:
   - `Ok`: Record delivered to destination
   - `Dropped`: Record discarded (not an error)
   - `ProcessingFailed`: Record goes to error output prefix
4. Firehose delivers transformed records to the destination

### Lambda Function Contract

Input:
```json
{
  "invocationId": "...",
  "deliveryStreamArn": "arn:aws:firehose:...",
  "records": [
    {
      "recordId": "unique-id",
      "data": "base64-encoded-data",
      "approximateArrivalTimestamp": 1234567890
    }
  ]
}
```

Output:
```json
{
  "records": [
    {
      "recordId": "unique-id",
      "result": "Ok",
      "data": "base64-encoded-transformed-data"
    }
  ]
}
```

### Constraints

- Lambda invocation payload max 6 MB
- Lambda must return within timeout (default 60s, max 900s)
- Lambda must be in the same region as the delivery stream
- Each record's `recordId` in the output must match the input

### Common Transformation Use Cases

- JSON parsing and field extraction
- Data enrichment (add timestamp, region, etc.)
- Filtering (drop irrelevant records)
- Format normalization
- PII masking

---

## 6. Format Conversion (JSON to Parquet/ORC)

Firehose can convert JSON input to Apache Parquet or Apache ORC columnar format.
This is critical for analytics performance -- Athena and Redshift Spectrum
queries on Parquet are 3-5x faster and use 30-50% less data scanning.

### Requirements

- Input must be JSON
- You need a Glue Data Catalog table defining the schema
- Destination must be S3 (Extended S3)
- Cannot use compression with format conversion (Parquet/ORC have built-in compression)

In Terraform:
```hcl
data_format_conversion_configuration {
  input_format_configuration {
    deserializer {
      open_x_json_ser_de {}
    }
  }
  output_format_configuration {
    serializer {
      parquet_ser_de {}
    }
  }
  schema_configuration {
    database_name = aws_glue_catalog_database.db.name
    table_name    = aws_glue_catalog_table.table.name
    role_arn      = aws_iam_role.firehose_role.arn
  }
}
```

---

## 7. Dynamic Partitioning

Dynamic partitioning automatically routes records to different S3 prefixes
based on record content. Without it, all records land under the same prefix.

### How It Works

1. Extract partition keys from records using:
   - **JQ expressions**: Parse JSON fields (`!{partitionKeyFromQuery:year}`)
   - **Lambda transformation**: Add partition keys in the transformation output
2. Use partition keys in the S3 prefix:
   `year=!{partitionKeyFromQuery:year}/month=!{partitionKeyFromQuery:month}/`
3. Each unique partition key combination creates a separate S3 prefix

### Cost

Dynamic partitioning costs $0.020/GB (additional to base delivery cost). Worth
it when you query data by partition keys in Athena/Redshift Spectrum.

---

## 8. Error Handling

### Error Output Prefix

When delivery to the primary destination fails (or Lambda transformation
returns `ProcessingFailed`), records go to the `error_output_prefix` in S3.
The error prefix should be different from the success prefix so you can
monitor and reprocess failed records.

### Retry Policy

- **S3**: Retries indefinitely (no retry duration concept)
- **Redshift/OpenSearch/HTTP/Splunk**: Retries for 0-7200 seconds (default
  varies by destination). After exhausting retries, records go to backup S3.

### CloudWatch Error Logging

Firehose logs delivery errors to CloudWatch Logs:
- Log Group: `/aws/kinesisfirehose/{delivery_stream_name}`
- Log Stream: `DestinationDelivery`

Common error types: S3 permission errors, Redshift COPY failures, Lambda
transformation errors, format conversion errors.

---

## 9. Integration Patterns in the Pipeline Engine

### Firehose as a Destination (Records Flow In)

| Source | How It Connects | Terraform |
|---|---|---|
| **Direct PUT** | SDK call | None (default source) |
| **Kinesis Streams** | Source config | `kinesis_source_configuration` block |
| **MSK** | Source config | `msk_source_configuration` block |
| **Lambda** | boto3 firehose.put_record | IAM permission on Lambda |
| **EC2** | SDK or Kinesis Agent | IAM permission on EC2 |
| **EventBridge** | Rule target | `aws_cloudwatch_event_target` |
| **CloudWatch Logs** | Subscription filter | `aws_cloudwatch_log_subscription_filter` |
| **Kinesis Analytics** | Output config | Output block in analytics app |
| **Step Functions** | SDK integration | IAM permission |

### Firehose as a Source (Records Flow Out)

| Destination | Terraform Block | Key Config |
|---|---|---|
| **S3** | `extended_s3_configuration` | bucket_arn, prefix, compression |
| **Redshift** | `redshift_configuration` | jdbcurl, table, S3 intermediate |
| **OpenSearch** | `opensearch_configuration` | domain_arn, index_name |
| **HTTP** | `http_endpoint_configuration` | url, access_key |
| **Splunk** | `splunk_configuration` | hec_endpoint, hec_token |

### Wiring Ownership

The Firehose renderer (`_render_kinesis_firehose`) owns:
- The delivery stream itself
- The CloudWatch Log Group and Log Stream
- The IAM role and policy
- The kinesis_source_configuration (when sourcing from Kinesis Streams)
- The S3/Redshift/etc. destination configuration

The Lambda renderer owns:
- `aws_lambda_event_source_mapping` when Lambda reads from the delivery stream (rare)
- IAM permissions on Lambda to write to Firehose

---

## 10. Terraform Pattern in the Pipeline Engine

The `_render_kinesis_firehose` function generates:

1. **CloudWatch Log Group** (`/aws/kinesisfirehose/{name}`) for error logs
2. **CloudWatch Log Stream** (`DestinationDelivery`) for delivery errors
3. **IAM Role** (trust: firehose.amazonaws.com) with permissions for the destination
4. **Delivery Stream** with:
   - Destination configuration (Extended S3 by default)
   - Kinesis source configuration (if sourcing from Kinesis Streams)
   - CloudWatch logging options pointing to the log group/stream

If no S3 destination is found in the integration graph, the renderer uses a
placeholder bucket ARN that must be updated before deployment.

---

## 11. Encryption

### Server-Side Encryption (Buffer)

Firehose can encrypt data in its internal buffer using KMS. Two key types:
- `AWS_OWNED_CMK`: AWS-managed key (default, free)
- `CUSTOMER_MANAGED_CMK`: Customer-managed KMS key

### Destination Encryption

- **S3**: Uses the bucket's default encryption settings
- **Redshift**: Uses the cluster's encryption settings
- **OpenSearch**: Uses the domain's encryption settings

### In Transit

All Firehose API calls use HTTPS. Delivery to S3 uses AWS internal network.

---

## 12. Common Error Patterns and Fixes

### AccessDenied to S3

**Cause**: Firehose role lacks S3 permissions.

**Fix**: Add these actions to the Firehose role:
- `s3:PutObject`
- `s3:GetBucketLocation`
- `s3:ListBucket`
- `s3:AbortMultipartUpload`
- `s3:ListBucketMultipartUploads`
- `s3:GetObject` (for error handling)

### Lambda Transformation Timeout

**Cause**: Lambda function takes too long to process records.

**Fix**: Increase Lambda timeout (max 900s). Optimize transformation code.
Reduce buffer size to send smaller batches.

### ConcurrentModificationException

**Cause**: Two `update_destination` calls happening simultaneously.

**Fix**: Get the latest `VersionId` from `describe_delivery_stream`, then retry.

### Buffer Configuration Errors

**Cause**: Buffer size or interval out of range.

**Fix**: S3: size 1-128 MB, interval 0-900s. HTTP: size 1-64 MB.

---

## 13. Best Practices

1. **Use GZIP compression** for S3 destinations. It reduces storage cost and
   improves Athena query performance.

2. **Enable CloudWatch error logging**. The pipeline engine does this
   automatically. Check `/aws/kinesisfirehose/{name}` for delivery errors.

3. **Set up an error output prefix**. Failed records should go to a separate
   S3 path for monitoring and reprocessing.

4. **Use format conversion** when the downstream consumer is Athena or
   Redshift Spectrum. Parquet reduces query cost by 30-50%.

5. **Use dynamic partitioning** when you query data by specific dimensions
   (date, customer, region). The $0.020/GB cost is offset by query savings.

6. **Keep Lambda transformation simple**. Complex transformations increase
   latency and failure rate. For heavy ETL, use Glue instead.

7. **Monitor delivery lag**. If `DeliveryToS3.DataFreshness` increases,
   increase buffer size or check for delivery errors.

8. **Cannot change destination type** after creation. If you need to switch
   from S3 to Redshift, you must create a new delivery stream.

---

## 14. Firehose vs Kinesis Streams vs Direct S3

| Feature | Firehose | Kinesis Streams | Direct S3 PUT |
|---|---|---|---|
| **Managed delivery** | Yes (automatic) | No (you code consumers) | No |
| **Buffering** | Built-in | None | None |
| **Transformation** | Lambda | You code it | None |
| **Compression** | Built-in | None | You code it |
| **Format conversion** | JSON to Parquet/ORC | None | None |
| **Multiple consumers** | No (one destination) | Yes (many) | N/A |
| **Replay** | No | Yes | N/A |
| **Ordering** | Approximate | Per-shard | N/A |
| **Cost** | Per GB ingested | Per shard-hour | Per request |

**Common pattern**: Kinesis Streams (ingestion) -> Kinesis Firehose (delivery to S3)
-> Athena (query). This gives you both real-time consumers on the stream AND
durable S3 storage via Firehose.

---

## 15. Developer Agent Patterns

**Writing data to Firehose**:
```python
firehose = boto3.client('firehose')

# Single record
firehose.put_record(
    DeliveryStreamName='my-stream',
    Record={'Data': json.dumps({'key': 'value'}).encode()}
)

# Batch (up to 500 records or 4 MB)
firehose.put_record_batch(
    DeliveryStreamName='my-stream',
    Records=[{'Data': json.dumps(r).encode()} for r in records]
)
```

**Checking delivery stream status**:
```python
response = firehose.describe_delivery_stream(DeliveryStreamName='my-stream')
status = response['DeliveryStreamDescription']['DeliveryStreamStatus']
version = response['DeliveryStreamDescription']['VersionId']
```

**Updating buffer settings**:
```python
firehose.update_destination(
    DeliveryStreamName='my-stream',
    CurrentDeliveryStreamVersionId=version,
    DestinationId='destinationId-000000000001',
    ExtendedS3DestinationUpdate={
        'BufferingHints': {'SizeInMBs': 64, 'IntervalInSeconds': 300},
        'CompressionFormat': 'GZIP'
    }
)
```
