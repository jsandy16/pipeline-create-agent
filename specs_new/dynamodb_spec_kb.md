# DynamoDB Knowledge Base

## What Is DynamoDB

Amazon DynamoDB is a serverless, fully managed NoSQL database that provides single-digit millisecond performance at any scale. It stores data as items (rows) within tables, where each item is a collection of attributes (columns). Data is automatically replicated across three Availability Zones for durability and high availability (99.99% SLA, 99.999% with global tables).

DynamoDB supports two data models: key-value and document. Unlike relational databases, DynamoDB is schemaless -- only the primary key attributes must be defined at table creation. Each item can have a different set of attributes.

## Core Concepts

### Tables, Items, and Attributes

A DynamoDB table is a collection of items. Each item is uniquely identified by its primary key and can be up to 400 KB in size. Attributes can be scalar (string, number, binary, boolean, null), document (list, map), or set (string set, number set, binary set). Nesting is supported up to 32 levels deep.

### Primary Keys

DynamoDB supports two types of primary keys:

1. **Partition Key (simple primary key)**: A single attribute. DynamoDB hashes this value to determine which partition stores the item. Every item must have a unique partition key. Maximum size: 2048 bytes.

2. **Partition Key + Sort Key (composite primary key)**: Two attributes. Items can share a partition key but must have a unique sort key within that partition. This enables range queries on the sort key. Partition key max: 2048 bytes, sort key max: 1024 bytes.

Primary key attributes must be of type String (S), Number (N), or Binary (B).

### Secondary Indexes

Secondary indexes allow querying on attributes other than the primary key.

**Global Secondary Index (GSI):**
- Can have a different partition key and sort key from the base table
- Spans all partitions (global scope)
- Has its own provisioned throughput (separate from table)
- Supports only eventually consistent reads
- Can be created and deleted after table creation
- Maximum 20 per table (adjustable)

**Local Secondary Index (LSI):**
- Must use the same partition key as the base table, with a different sort key
- Scoped to items sharing the same partition key
- Shares throughput with the base table
- Supports strongly consistent and eventually consistent reads
- Must be created at table creation time (cannot add later)
- Maximum 5 per table (hard limit)
- Imposes a 10 GB item collection size limit per partition key value

Both index types support projection types: ALL (all attributes), KEYS_ONLY (just key attributes), or INCLUDE (specific attributes, max 100 across all indexes).

## Capacity Modes

### Provisioned Mode

You pre-allocate Read Capacity Units (RCU) and Write Capacity Units (WCU). One RCU provides one strongly consistent read per second for items up to 4 KB. One WCU provides one write per second for items up to 1 KB. This mode is included in the AWS Free Tier (25 RCU + 25 WCU forever, handling approximately 200 million requests per month).

Auto-scaling is available via Application Auto Scaling to adjust capacity based on utilization. You can decrease provisioned capacity up to 27 times per day (4 at start of day plus 1 per hour).

### On-Demand Mode (PAY_PER_REQUEST)

Pay per read/write request with no capacity planning. DynamoDB instantly scales up and down, including scaling to zero with no cold starts. This mode is not included in the free tier. Best for unpredictable or spiky workloads.

Maximum throughput per table: 40,000 read/write request units per second (adjustable).

## DynamoDB Streams

DynamoDB Streams captures an ordered, near-real-time sequence of item-level changes. Each stream record contains the table name, event timestamp, and item data. Records are retained for 24 hours.

Stream view types:
- KEYS_ONLY: Only key attributes of the modified item
- NEW_IMAGE: The entire item after modification
- OLD_IMAGE: The entire item before modification
- NEW_AND_OLD_IMAGES: Both before and after images

Common use case: triggering AWS Lambda functions on item changes (event-driven architecture). Lambda creates an event source mapping that polls the stream. Maximum 2 concurrent readers per shard (1 recommended for global tables).

Alternative: Route change data to Amazon Kinesis Data Streams for longer retention (up to 365 days), multiple consumers, and integration with Kinesis Analytics and Firehose.

## Time to Live (TTL)

TTL lets you define a per-item expiration timestamp (Unix epoch, Number type). DynamoDB automatically deletes expired items within 48 hours at no write capacity cost. Deletions appear in DynamoDB Streams if enabled. Only one TTL attribute per table. Use cases include session management, temporary data, and regulatory compliance.

## Global Tables

Global tables provide multi-region, multi-active replication with a 99.999% availability SLA. There is no primary table -- all replicas accept reads and writes with single-digit millisecond latency. Conflict resolution uses last-writer-wins semantics.

Requirements: DynamoDB Streams enabled with NEW_AND_OLD_IMAGES view type; PAY_PER_REQUEST billing or auto-scaling provisioned mode. Maximum 400 global tables per account.

## Backups and Restore

**On-demand backups**: Full table backups retained until explicitly deleted. No impact on table performance. Supports any table size.

**Point-in-Time Recovery (PITR)**: Continuous backups with per-second granularity. Restore to any point within a 1-35 day retention window. No impact on performance.

**AWS Backup integration**: Scheduled backups, cross-account/cross-region copying, lifecycle management, cold storage transitions.

## Transactions

DynamoDB supports ACID transactions across multiple items and tables. TransactWriteItems supports up to 100 items (Put, Update, Delete, ConditionCheck) atomically. TransactGetItems reads up to 100 items atomically. Maximum transaction size: 4 MB. Transactions consume 2x normal capacity (both reads and writes).

## DAX (DynamoDB Accelerator)

DAX is a fully managed, in-memory cache that sits in front of DynamoDB. It provides microsecond response times (10x improvement) and handles millions of requests per second. DAX is API-compatible with DynamoDB (drop-in replacement in most cases). It manages cache invalidation, data population, and cluster management automatically. DAX requires VPC placement and is not included in the free tier.

## Encryption

**At rest**: All DynamoDB data is encrypted at rest by default (since 2018). Three key options: AWS-owned key (free, default), AWS-managed key (aws/dynamodb, KMS charges), or customer-managed CMK (full control). Encryption is transparent with no impact on latency.

**In transit**: All API calls use HTTPS/TLS automatically.

**Client-side**: Optional via the AWS Database Encryption SDK for end-to-end encryption.

## Integration Patterns with Pipeline Services

### Lambda
- Lambda reads/writes DynamoDB items via SDK (needs dynamodb:GetItem, PutItem, etc.)
- DynamoDB Streams triggers Lambda via event source mapping (needs dynamodb:DescribeStream, GetRecords, GetShardIterator, ListStreams)
- The DynamoDB renderer enables streams when a Lambda target is detected in integrations

### Step Functions
- SDK integration for GetItem, PutItem, UpdateItem, DeleteItem, Query, Scan
- Needs corresponding dynamodb:* permissions on the Step Functions role

### Glue
- Reads DynamoDB via DynamoDB connector in Glue ETL jobs
- Needs dynamodb:DescribeTable, Scan, GetItem, BatchGetItem

### EMR
- Reads/writes via Hive DynamoDB connector
- Needs full CRUD permissions on the table

### DMS
- DynamoDB as source or target endpoint for database migration
- Needs Scan, PutItem, UpdateItem, DeleteItem, BatchWriteItem

### S3
- Export: DynamoDB exports table data to S3 (full or incremental)
- Import: Load S3 data into a new DynamoDB table
- Both are native DynamoDB features, not wiring between services

### Redshift
- Zero-ETL integration for running complex analytics on DynamoDB data without impacting production

## Terraform Resources

The DynamoDB renderer creates:
- `aws_dynamodb_table` (always): The table with key schema, billing mode, capacity, optional streams, optional TTL
- DynamoDB Streams are enabled inline when a Lambda target is detected

Related resources created by other renderers:
- `aws_lambda_event_source_mapping` (Lambda renderer): Maps DynamoDB stream to Lambda
- `aws_appautoscaling_target` + `aws_appautoscaling_policy`: For auto-scaling provisioned capacity
- `aws_dax_cluster`, `aws_dax_parameter_group`, `aws_dax_subnet_group`: For DAX caching
- `aws_dynamodb_table_replica`: For global table replicas

## IAM Patterns

DynamoDB is a passive service (is_principal: false) -- it has no execution role. Callers (Lambda, Step Functions, Glue, etc.) need permissions on their own roles to access DynamoDB.

Key IAM actions by category:
- Item CRUD: dynamodb:GetItem, PutItem, UpdateItem, DeleteItem, BatchGetItem, BatchWriteItem, Query, Scan
- Streams: dynamodb:DescribeStream, GetRecords, GetShardIterator, ListStreams
- Table management: dynamodb:CreateTable, DeleteTable, UpdateTable, DescribeTable
- Backups: dynamodb:CreateBackup, RestoreTableFromBackup, UpdateContinuousBackups

ARN formats:
- Table: `arn:aws:dynamodb:REGION:ACCOUNT:table/TABLE-NAME`
- Index: `arn:aws:dynamodb:REGION:ACCOUNT:table/TABLE-NAME/index/INDEX-NAME`
- Stream: `arn:aws:dynamodb:REGION:ACCOUNT:table/TABLE-NAME/stream/STREAM-LABEL`

## Common Errors and Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| ResourceNotFoundException | Table does not exist or wrong region | Verify table name and region |
| ProvisionedThroughputExceededException | Capacity exhausted | Increase RCU/WCU or switch to PAY_PER_REQUEST |
| ConditionalCheckFailedException | Condition expression failed | Re-read item and retry |
| ItemCollectionSizeLimitExceededException | >10 GB per partition key (LSI) | Redistribute data or remove LSI |
| TransactionConflictException | Concurrent transaction conflict | Retry with backoff |
| ValidationException (KeySchema) | Cannot change primary key | Create new table and migrate |
| LimitExceededException | Account quota reached | Request quota increase |

## Security Best Practices

1. Use IAM policies with least privilege -- scope to specific tables and actions
2. Use condition keys like dynamodb:LeadingKeys to restrict access to specific partition keys
3. Use dynamodb:FullTableScan condition key to prevent expensive scan operations
4. Enable encryption with customer-managed CMK for regulated workloads
5. Enable PITR for disaster recovery
6. Use VPC endpoints (gateway type) to keep traffic within the AWS network
7. Enable DynamoDB Streams for audit trails and change tracking
8. Use resource-based policies for cross-account access control

## Monitoring

DynamoDB publishes CloudWatch metrics under the AWS/DynamoDB namespace. Key metrics: ConsumedReadCapacityUnits, ConsumedWriteCapacityUnits, ThrottledRequests, SystemErrors, UserErrors, ConditionalCheckFailedRequests. For the pipeline run monitor, DynamoDB uses CloudTrail LookupEvents (not CloudWatch Logs) since it has no native log group.

## Quotas Summary

| Resource | Limit |
|----------|-------|
| Tables per region | 2,500 (max 10,000) |
| Max item size | 400 KB |
| Max GSI per table | 20 |
| Max LSI per table | 5 |
| Max RCU per table | 40,000 (adjustable) |
| Max WCU per table | 40,000 (adjustable) |
| Batch write items | 25 |
| Batch get items | 100 |
| Transaction items | 100 |
| Stream record retention | 24 hours |
| Max nested depth | 32 levels |
| Tags per resource | 50 |
