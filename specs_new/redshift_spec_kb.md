# Redshift Knowledge Base

## What Is Amazon Redshift

Amazon Redshift is a fully managed, petabyte-scale data warehouse service. It uses columnar storage, massively parallel processing (MPP), and result caching to deliver fast query performance on datasets ranging from gigabytes to petabytes. Redshift supports standard SQL and integrates with popular business intelligence tools.

Redshift is never part of the perpetual AWS Free Tier. There is a 2-month free trial for dc2.large nodes.

## Cluster Architecture

### Leader Node
The leader node receives client queries, parses SQL, develops execution plans, coordinates parallel execution across compute nodes, aggregates intermediate results, and returns final results to the client. In multi-node clusters, the leader is a separate node (same type as compute nodes). You are not billed for the leader node.

### Compute Nodes
Compute nodes execute query plans in parallel, exchange data among themselves, and send intermediate results to the leader node. Each compute node is divided into slices (2-16 depending on node type) for further parallel processing. In multi-node clusters, data is mirrored across compute nodes for fault tolerance.

### Single-Node vs Multi-Node
A single-node cluster has one node serving as both leader and compute. This is not recommended for production. Multi-node clusters have a separate leader node and 2 or more compute nodes.

## Node Types

### RA3 (Managed Storage) -- Recommended
RA3 nodes separate compute from storage. Local high-performance SSDs serve as cache, with Amazon S3 providing long-term durable storage. Data automatically tiers between SSD and S3 based on usage patterns.

| Node Type | vCPU | RAM | Slices | Storage/Node | Nodes |
|-----------|------|-----|--------|-------------|-------|
| ra3.xlplus | 4 | 32 GiB | 2 | 32 TB (multi) | 1-32 |
| ra3.4xlarge | 12 | 96 GiB | 4 | 128 TB | 2-64 |
| ra3.16xlarge | 48 | 384 GiB | 16 | 128 TB | 2-128 |

### DC2 (Dense Compute)
DC2 nodes use local NVMe-SSD storage. Best for datasets under 1 TB compressed. Storage grows only by adding compute nodes.

| Node Type | vCPU | RAM | Slices | Storage/Node | Nodes |
|-----------|------|-----|--------|-------------|-------|
| dc2.large | 2 | 15 GiB | 2 | 160 GB | 1-32 |
| dc2.8xlarge | 32 | 244 GiB | 16 | 2.56 TB | 2-128 |

### DS2 -- Deprecated
No longer available for new clusters.

### Recommendation
Use RA3 for growing data and independent compute/storage scaling. Use DC2 for small, fixed datasets with highest price/performance.

## Redshift Spectrum

Spectrum allows querying data directly in Amazon S3 using external tables, without loading data into Redshift. It uses a separate Spectrum compute layer and charges per TB of data scanned.

Requirements:
- Cluster must have an IAM role with S3 read and Glue Data Catalog permissions
- External schema registered in AWS Glue Data Catalog or Hive metastore
- S3 data must be in the same region as the Redshift cluster

Supported formats: Parquet, ORC, JSON, CSV, Avro, Ion, Text, Grok, OpenCSV, Regex.

Limits: max 1,600 columns per external table, max 16 KB string values for ION/JSON.

## Redshift Serverless

Redshift Serverless provides automatic resource provisioning with intelligent scaling. Pay per RPU-hour with no charges when idle.

- Capacity unit: RPU (Redshift Processing Unit), min 8, max 512
- Storage: 32 TB (4 RPU) or 128 TB (8+ RPU)
- Max 25 workgroups and 25 namespaces per account
- Max 200,000 tables, 2,000 connections, 100 databases per namespace

Terraform resources: `aws_redshiftserverless_namespace`, `aws_redshiftserverless_workgroup`.

## Data Operations

### COPY Command
Bulk loads data from S3, DynamoDB, EMR (HDFS), or remote hosts into Redshift tables. This is the primary data loading mechanism.

```sql
COPY table FROM 's3://bucket/prefix' IAM_ROLE 'arn:...' FORMAT AS PARQUET;
```

Best practices: split files into multiples of the number of slices, use compressed files, use manifest files for precise control. Max row size: 4 MB.

### UNLOAD Command
Exports query results from Redshift to S3 in CSV, JSON, or Parquet format.

```sql
UNLOAD ('SELECT ...') TO 's3://bucket/prefix' IAM_ROLE 'arn:...' PARQUET;
```

Best practices: use PARALLEL ON for faster exports, use PARTITION BY for Hive-compatible partitioning.

### Redshift Data API
Execute SQL via HTTP without persistent connections. Ideal for Lambda, Step Functions, and event-driven architectures. Operations are asynchronous: execute_statement returns an ID, then poll describe_statement until FINISHED, then call get_statement_result.

Rate limits: execute_statement 30 TPS, batch_execute_statement 20 TPS, get_statement_result 20 TPS, describe_statement 100 TPS.

## Concurrency Scaling

Automatically adds transient clusters (up to 10) to handle bursts of read queries. One hour of free concurrency scaling per day per main cluster, then per-second billing. Write queries always go to the main cluster.

## Workload Management (WLM)

Controls query prioritization, memory allocation, and concurrency.

- **Automatic WLM** (recommended): Redshift manages memory and concurrency automatically
- **Manual WLM**: User defines queues with concurrency, memory, and timeout settings; max 50 concurrent queries

Configured via parameter group (wlm_json_configuration parameter).

## Snapshots

### Automated Snapshots
Automatic incremental snapshots, retained 1-35 days (default 1 day). Taken approximately every 8 hours or 5 GB of data changes.

### Manual Snapshots
User-initiated snapshots, retained until deleted. Maximum 700 per account per region.

### Cross-Region Snapshots
Copy snapshots to another region for disaster recovery. Re-encrypted with the destination region KMS key.

### Restore
Restore creates a new cluster from a snapshot. Can restore to a different node type (slice count may change).

## Encryption

### At Rest
Encrypt cluster data, snapshots, and backups. Key options: AWS-managed KMS key, customer-managed CMK, or HSM (CloudHSM). Can enable/disable encryption on existing clusters (causes brief unavailability).

### In Transit
SSL/TLS for client connections. Enabled by default. Enforce via parameter group: `require_ssl = true`.

### Key Rotation
Automatic key rotation managed by KMS key rotation policy. Cluster shows `rotating-keys` status during rotation.

## VPC Configuration

Redshift clusters run in VPC (required for all current node types).

### Enhanced VPC Routing
Forces all COPY and UNLOAD traffic through the VPC instead of the public internet. Use when security compliance requires all traffic to stay within the VPC network. Terraform attribute: `enhanced_vpc_routing`.

### Subnet Groups
Required for VPC deployment. Define which subnets the cluster can use.

### Endpoint Access
Redshift-managed VPC endpoints allow cross-VPC access. Up to 30 per cluster.

### Port
Default port: 5439. Configurable via the `port` terraform attribute.

## Integration Patterns with Pipeline Services

### S3
- COPY: Load data from S3 into Redshift tables (cluster IAM role needs s3:GetObject, s3:ListBucket)
- UNLOAD: Export query results to S3 (needs s3:PutObject, s3:ListBucket, s3:AbortMultipartUpload)
- Spectrum: Query S3 data via external tables (needs s3:GetObject, s3:ListBucket + glue:GetDatabase, glue:GetTable, glue:GetPartition)

### Lambda
Lambda queries Redshift via the Data API (redshift-data). Needs redshift-data:ExecuteStatement, DescribeStatement, GetStatementResult. Also needs redshift:GetClusterCredentials for authentication.

### Step Functions
SDK integration with Data API for direct SQL execution from state machine tasks.

### Glue
Glue ETL jobs read/write Redshift via JDBC connections. Requires VPC connectivity and security group access. Needs redshift:DescribeClusters, redshift:GetClusterCredentials.

### EMR
EMR reads/writes Redshift via JDBC. Same requirements as Glue.

### Kinesis Firehose
Firehose delivers records to Redshift by first writing to an S3 staging area, then issuing a COPY command.

### DMS
DMS uses Redshift as a target for data migration. Writes via S3 staging + COPY command.

### Aurora (Zero-ETL)
Zero-ETL integration provides continuous replication from Aurora to Redshift without building ETL pipelines.

### DynamoDB (Zero-ETL)
Zero-ETL integration for running analytics on DynamoDB data in Redshift.

## Terraform Resources

The Redshift renderer creates:
- `aws_cloudwatch_log_group` (always): Log group for Redshift audit logs (pattern: `/aws/redshift/cluster/CLUSTER-NAME`)
- `aws_iam_role` (always): IAM role for Spectrum/COPY/UNLOAD (trust: redshift.amazonaws.com)
- `aws_iam_role_policy` (always): IAM policy attached to the role
- `random_password` (always): Random master password
- `aws_redshift_cluster` (always): The cluster with logging to CloudWatch enabled

Conditional resources:
- `aws_redshift_subnet_group`: VPC subnet group
- `aws_redshift_parameter_group`: Custom parameter settings
- `aws_redshift_snapshot_schedule`: Custom snapshot schedules
- `aws_redshift_scheduled_action`: Scheduled pause/resume or resize
- `aws_redshift_endpoint_access`: Cross-VPC endpoint access

Serverless resources:
- `aws_redshiftserverless_namespace`: Namespace (database, users, schemas)
- `aws_redshiftserverless_workgroup`: Workgroup (compute, networking)

## IAM Patterns

Redshift is a principal service (is_principal: true) -- it has an IAM execution role for Spectrum, COPY, and UNLOAD operations. The role is attached to the cluster via the `iam_roles` attribute.

The role always needs: logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents, glue:GetDatabase, glue:GetTable, glue:GetPartition (for Spectrum).

Key IAM actions by category:
- Cluster management: redshift:CreateCluster, ModifyCluster, DescribeClusters, ResizeCluster, PauseCluster, ResumeCluster
- Data API: redshift-data:ExecuteStatement, BatchExecuteStatement, DescribeStatement, GetStatementResult
- Credentials: redshift:GetClusterCredentials, GetClusterCredentialsWithIAM
- Snapshots: redshift:CreateClusterSnapshot, RestoreFromClusterSnapshot

ARN formats:
- Cluster: `arn:aws:redshift:REGION:ACCOUNT:cluster:CLUSTER-NAME`
- Database: `arn:aws:redshift:REGION:ACCOUNT:dbname:CLUSTER-NAME/DB-NAME`
- User: `arn:aws:redshift:REGION:ACCOUNT:dbuser:CLUSTER-NAME/DB-USER`
- Snapshot: `arn:aws:redshift:REGION:ACCOUNT:snapshot:CLUSTER-NAME/SNAPSHOT-NAME`

## Common Errors and Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| ClusterNotFound | Cluster not found or not available | Verify cluster ID and region; check status |
| InsufficientClusterCapacity | Node type/count not available in AZ | Try different node type or AZ |
| InvalidClusterState | Cluster not in available state | Wait for cluster to become available |
| ClusterAlreadyExists | Cluster ID already in use | Choose different identifier |
| NumberOfNodesQuotaExceeded | Node quota exceeded | Request quota increase |
| COPY Permission denied | IAM role lacks S3 read | Add s3:GetObject, s3:ListBucket to role |
| S3ServiceException Forbidden | Bucket policy blocks access | Check role and bucket policy |
| disk full / storage-full | Cluster storage full | Resize, add nodes, delete data, or use RA3 |
| Connection timed out | Security group blocks port 5439 | Add inbound TCP 5439 rule |

## Security Best Practices

1. Always encrypt at rest (use customer-managed CMK for regulated workloads)
2. Enforce SSL for all connections via parameter group (require_ssl = true)
3. Use enhanced VPC routing to keep COPY/UNLOAD traffic within VPC
4. Place clusters in private subnets (publicly_accessible = false)
5. Use IAM-based authentication (GetClusterCredentials) instead of static passwords
6. Enable audit logging (connectionlog, useractivitylog, userlog)
7. Use VPC security groups to restrict access to port 5439
8. Enable automated snapshots with appropriate retention
9. Use usage limits to control costs
10. Rotate encryption keys regularly

## Monitoring

Redshift publishes CloudWatch metrics under the AWS/Redshift namespace. Key metrics: CPUUtilization, PercentageDiskSpaceUsed, DatabaseConnections, QueryDuration, ReadIOPS, WriteIOPS, ReadLatency, WriteLatency, WLMQueueLength, ConcurrencyScalingSeconds.

Audit logging exports to CloudWatch Logs: connectionlog (connection attempts), useractivitylog (SQL statements), userlog (user changes). Log group pattern: `/aws/redshift/cluster/CLUSTER-NAME`.

For the pipeline run monitor, Redshift uses CloudWatch Logs via the audit logging configuration.

## Quotas Summary

| Resource | Limit |
|----------|-------|
| Nodes per account per region | 200 (adjustable) |
| DC2/RA3 nodes per cluster | 128 (adjustable) |
| Databases per cluster | 60 |
| Schemas per database | 9,900 |
| Tables (dc2.large) | 9,900 |
| Tables (ra3.4xlarge+) | 200,000 |
| Connections (dc2.large) | 500 |
| Connections (RA3/dc2.8xl) | 2,000 |
| Concurrent queries (manual WLM) | 50 |
| Snapshots per account/region | 700 (adjustable) |
| Parameter groups | 20 |
| Subnet groups | 50 (adjustable) |
| IAM roles per cluster | 50 |
| Concurrency scaling clusters | 10 |
| Spectrum columns/table | 1,600 |
| Max row size (COPY) | 4 MB |
| Tags per resource | 50 |
| Serverless workgroups | 25 (adjustable) |
| Data API execute TPS | 30 |
