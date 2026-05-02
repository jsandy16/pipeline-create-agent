# AWS Database Migration Service (DMS) -- Complete Knowledge Base

> This document is the plain-English reference for DMS that the pipeline engine
> framework and developer agent can consult when handling any DMS-related request
> in a pipeline. It covers what DMS is, how it works, every feature, integration
> patterns, security, performance, and troubleshooting -- written for an agent
> that needs to reason about DMS in context, not just look up API parameters.

---

## 1. What Is DMS?

AWS Database Migration Service (DMS) migrates data between databases with minimal
downtime. It uses a **replication instance** (a managed EC2 instance) that
connects to a **source endpoint** and a **target endpoint**, executing a
**replication task** that moves data between them.

DMS supports:
- **Homogeneous migrations**: Same engine type (e.g. MySQL to MySQL)
- **Heterogeneous migrations**: Different engine types (e.g. Oracle to Aurora PostgreSQL)
- **Continuous replication**: Ongoing change data capture (CDC) after initial load

### Core Concepts
- **Replication Instance**: A managed EC2 instance running the DMS engine. Performs the actual data replication.
- **Source Endpoint**: Connection to the database you are migrating FROM.
- **Target Endpoint**: Connection to the database you are migrating TO.
- **Replication Task**: Defines what data to migrate and how (full load, CDC, or both).
- **Table Mappings**: JSON rules specifying which tables to include/exclude and how to transform them.
- **Task Settings**: JSON configuration controlling logging, error handling, LOB settings, etc.

### Free Tier
DMS offers a 6-month free trial: 750 hours/month of dms.t2.micro single-AZ
instance with 50 GB included storage. After the trial, the smallest instance
(dms.t2.micro) costs approximately $0.018/hour.

---

## 2. Architecture

```
Source Database
     |
     v
[Source Endpoint] --> [Replication Instance] --> [Target Endpoint]
     |                       |                        |
     |                  DMS Engine                    |
     |              (reads + transforms              |
     |               + writes data)                  |
     v                                               v
Source DB                                       Target DB/S3/etc.
```

The replication instance runs in a VPC with a subnet group spanning at least
2 AZs. It needs network access to both source and target endpoints.

---

## 3. Replication Instances

### Instance Classes

| Class | vCPUs | Memory | Use Case |
|---|---|---|---|
| dms.t2.micro | 1 | 1 GB | Free trial, dev/test |
| dms.t3.medium | 2 | 4 GB | Small migrations |
| dms.c5.large | 2 | 4 GB | Medium workloads |
| dms.c5.xlarge | 4 | 8 GB | Large migrations |
| dms.r5.large | 2 | 16 GB | LOB-heavy migrations |
| dms.r5.xlarge | 4 | 32 GB | Very large LOB data |

The pipeline engine defaults to `dms.t2.micro` for cost optimization.

### Storage
- GP2 SSD storage, 5 GB to 6 TB
- Used for log files and cached changes during CDC
- Default: 20 GB (pipeline engine) / 50 GB (AWS default)
- Monitor FreeStorageSpace metric -- full storage causes task failure

### Multi-AZ
- Standby replica in a different AZ for automatic failover
- Failover typically under 1 minute
- Costs approximately 2x single-AZ
- Recommended for production CDC tasks

---

## 4. Endpoints

Endpoints define the source and target connections. DMS supports a wide range
of database engines and data stores.

### Supported Source Engines
| Engine | CDC Support | Method |
|---|---|---|
| Oracle | Yes | LogMiner or Binary Reader |
| MySQL / MariaDB | Yes | Binary log (binlog) |
| PostgreSQL | Yes | Logical replication (pglogical / test_decoding) |
| SQL Server | Yes | MS-CDC or MS-Replication |
| Aurora MySQL | Yes | Binary log |
| Aurora PostgreSQL | Yes | Logical replication |
| MongoDB | Yes | Change streams (4.0+) / oplog |
| DocumentDB | Yes | Change streams |
| IBM Db2 | Yes | ASN Capture |
| SAP ASE | Yes | Replication Server |
| S3 | Limited | Reads CSV/Parquet files |

### Supported Target Engines
All source engines (for homogeneous migration) plus:
- Amazon S3 (CSV/Parquet output)
- Amazon Redshift (via intermediate S3 COPY)
- Amazon DynamoDB
- Amazon Kinesis Data Streams
- Apache Kafka / Amazon MSK
- Amazon OpenSearch Service
- Amazon Neptune

### Connection Configuration
Common parameters:
- `server_name`: Database hostname or IP
- `port`: Database port
- `database_name`: Database name
- `username` / `password`: Credentials (prefer Secrets Manager)
- `ssl_mode`: none, require, verify-ca, verify-full

**Best practice**: Use AWS Secrets Manager for credentials instead of plaintext
in Terraform state. Set `secrets_manager_arn` on the endpoint.

---

## 5. Migration Types

### Full Load
One-time migration of all existing data:
- Reads all rows from source tables
- Creates tables on target (DROP_AND_CREATE by default)
- Task completes when all data is migrated
- Source can remain active, but changes during migration may be missed
- Best for: one-time data loads, initial seed

### CDC (Change Data Capture)
Ongoing replication of changes only:
- Captures INSERT, UPDATE, DELETE from source
- Applies changes to target in near real-time (seconds to minutes latency)
- Runs continuously until stopped
- Requires source database to support change capture
- Best for: ongoing replication after initial load is done

### Full Load + CDC (Recommended)
Complete migration with minimal downtime:
1. **Phase 1 (Full Load)**: Migrates all existing data
2. **Phase 2 (Cached Changes)**: Applies changes that occurred during full load
3. **Phase 3 (Ongoing CDC)**: Continuous replication

This is the most common type for production migrations.

---

## 6. CDC Prerequisites by Engine

### MySQL / Aurora MySQL
```sql
-- Required binary log settings
binlog_format = ROW
binlog_row_image = FULL
expire_logs_days = 3  -- or higher
-- DMS user needs:
GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'dms_user';
```

### PostgreSQL / Aurora PostgreSQL
```sql
-- Required WAL settings
wal_level = logical
max_replication_slots = 5  -- at least 1 for DMS
max_wal_senders = 5        -- at least 1 for DMS
-- DMS user needs:
GRANT rds_replication TO dms_user;  -- for RDS/Aurora
-- or CREATE ROLE dms_user REPLICATION; for self-managed
```

### Oracle
- ARCHIVELOG mode enabled
- Supplemental logging enabled at database level
- Table-level supplemental logging for replicated tables
- LogMiner (default, no additional software) or Binary Reader (requires Oracle DMS component)

### SQL Server
```sql
EXEC sys.sp_cdc_enable_db;  -- enable CDC on database
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'my_table', @role_name = NULL;
-- SQL Server Agent must be running
```

---

## 7. Table Mappings

Table mappings are a JSON document that controls which tables are migrated and
how they are transformed.

### Selection Rules
Include or exclude schemas/tables using wildcards:
```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-action": "include",
      "object-locator": {
        "schema-name": "public",
        "table-name": "%"
      }
    },
    {
      "rule-type": "selection",
      "rule-id": "2",
      "rule-action": "exclude",
      "object-locator": {
        "schema-name": "public",
        "table-name": "temp_%"
      }
    }
  ]
}
```

### Transformation Rules
Rename schemas, tables, or columns:
```json
{
  "rule-type": "transformation",
  "rule-id": "3",
  "rule-action": "rename",
  "rule-target": "schema",
  "object-locator": {"schema-name": "legacy"},
  "value": "migrated"
}
```

Available actions: rename, remove-column, convert-lowercase, convert-uppercase,
add-prefix, remove-prefix, add-suffix, remove-suffix.

### Wildcards
- `%` matches zero or more characters
- `_` matches a single character
- `\` escape character

---

## 8. Task Settings

Task settings control the behavior of a replication task. Key sections:

### Full Load Settings
- `TargetTablePrepMode`: DROP_AND_CREATE (default), TRUNCATE_BEFORE_LOAD, DO_NOTHING
- `MaxFullLoadSubTasks`: Parallel threads for full load (default 8)
- `CommitRate`: Rows per commit (default 10000)

### LOB Settings
- `SupportLobs`: true/false
- LOB modes:
  - **Limited mode** (default): LOBs truncated at `LobMaxSize` (default 32 KB). Fast.
  - **Full mode**: All LOB data migrated. Slow -- each LOB requires individual lookup.
  - **Inline mode**: LOBs up to `InlineLobMaxSize` handled inline; larger ones use full mode.
- Common error: "LOB_DATA_EXCEEDS_MAX_SIZE" when limited mode truncates data

### Error Handling
- `DataErrorPolicy`: LOG_ERROR (default), SUSPEND_TABLE, STOP_TASK, IGNORE
- `TableErrorPolicy`: SUSPEND_TABLE (default)
- `RecoverableErrorCount`: -1 (unlimited retries, default)
- `RecoverableErrorInterval`: 5 seconds between retries

### Logging
- `EnableLogging`: true (recommended)
- Log components: SOURCE_UNLOAD, SOURCE_CAPTURE, TARGET_LOAD, TARGET_APPLY, TASK_MANAGER
- Severity: DEFAULT, DEBUG, DETAILED_DEBUG

---

## 9. S3 as DMS Target

DMS can write migrated data to S3 in CSV or Parquet format. This is useful for
data lake ingestion pipelines.

### Output Format
- **CSV**: Default delimiter comma, row delimiter newline
- **Parquet**: Columnar format, efficient for analytics

### Output Structure
- Full load: `s3://bucket/folder/schema/table/LOAD00000001.csv`
- CDC: `s3://bucket/folder/schema/table/YYYYMMDD-HHmmss-nnn.csv`

### CDC to S3
Each batch of changes creates a new file. Files contain operation type
(I=insert, U=update, D=delete) and column values.

### Compression
Options: none, gzip. GZIP recommended for cost savings on storage.

---

## 10. S3 as DMS Source

DMS can read data from S3 CSV/Parquet files. Requires an external table
definition (JSON) specifying the schema of the files.

Requirements:
- Data files in consistent format
- External table definition mapping columns to data types
- Files organized by table name in the bucket

---

## 11. Data Validation

DMS can validate migrated data by comparing source and target row-by-row:

- **Row count validation**: Compares total rows per table
- **Value comparison**: Compares actual column values
- Results stored in `awsdms_validation_failures_v1` table on target
- Runs in parallel with migration (adds overhead)

### Premigration Assessment
Run before starting migration to identify potential issues:
- Source/target connectivity
- Table structure compatibility
- Data type mapping issues
- LOB column handling
- CDC prerequisite checks

---

## 12. Encryption

### At Rest
- Replication instance storage encrypted with KMS by default
- Default key: `aws/dms` (AWS-managed)
- Custom KMS key for compliance requirements

### In Transit (SSL/TLS)
Modes:
- `none`: No encryption (not recommended)
- `require`: Encrypted, no certificate verification
- `verify-ca`: Encrypted, verify CA certificate
- `verify-full`: Encrypted, verify CA + hostname

Upload custom CA certificates via `aws_dms_certificate` Terraform resource.

---

## 13. Networking

### VPC and Subnet Groups
DMS always runs in a VPC. The replication instance uses a subnet group with
subnets in at least 2 AZs.

The pipeline engine creates a subnet group using default VPC subnets:
```hcl
resource "aws_dms_replication_subnet_group" "example_subnet_grp" {
  replication_subnet_group_id          = "example-subnet-grp"
  replication_subnet_group_description = "DMS subnet group"
  subnet_ids                            = data.aws_subnets.default.ids
}
```

### Connectivity Requirements
- Replication instance needs network access to BOTH source and target
- For on-premises databases: VPN or Direct Connect required
- Security groups must allow outbound to source/target ports
- Set `publicly_accessible = false` (default in pipeline engine)

### VPC Triggers
DMS requires VPC configuration when integrated with Aurora or Redshift
(to be in the same VPC for direct connectivity).

---

## 14. Monitoring

### CloudWatch Metrics
Namespace: `AWS/DMS`

**Instance metrics**: CPUUtilization, FreeableMemory, FreeStorageSpace, WriteIOPS,
ReadIOPS, SwapUsage

**Task metrics**: CDCLatencySource, CDCLatencyTarget, CDCIncomingChanges,
CDCThroughputRowsSource, CDCThroughputRowsTarget, FullLoadThroughputRowsTarget

### Task Logging
Detailed logs in CloudWatch Logs:
- Log group: `dms-tasks-{replication_instance_id}`
- Components: SOURCE_UNLOAD, SOURCE_CAPTURE, TARGET_LOAD, TARGET_APPLY, TASK_MANAGER
- Set severity to DEBUG or DETAILED_DEBUG for troubleshooting

### Event Subscriptions
SNS notifications for DMS events:
- Instance: creation, deletion, maintenance, failover, failure, low storage
- Task: creation, deletion, state change, failure

---

## 15. IAM for DMS

### Service Role
DMS uses a service role with `dms.amazonaws.com` as the trusted principal.
The pipeline engine creates:
1. IAM Role with DMS trust policy
2. IAM Policy with permissions computed from integrations

### Integration Permissions

| Integration | Permissions on DMS Role |
|---|---|
| Aurora (source) | rds:DescribeDBClusters, rds:DescribeDBInstances |
| S3 (source) | s3:GetObject, s3:ListBucket, s3:GetBucketLocation |
| S3 (target) | s3:PutObject, s3:DeleteObject, s3:ListBucket, s3:GetObject, s3:GetBucketLocation |
| DynamoDB (target) | dynamodb:PutItem, BatchWriteItem, DeleteItem, DescribeTable |
| Redshift (target) | redshift:DescribeClusters, GetClusterCredentials, ModifyCluster |
| Aurora (target) | rds:DescribeDBClusters, DescribeDBInstances, ModifyDBCluster |
| Kinesis (target) | kinesis:PutRecord, PutRecords, DescribeStream |

**Always included**: logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents

### Service-Linked Role
DMS automatically creates `AWSServiceRoleForDMS` for managing VPC resources.

---

## 16. Terraform Resources Created

The DMS renderer in `engine/hcl_renderer.py` creates:

1. `aws_cloudwatch_log_group` -- log group for task logs (`dms-tasks-{name}`)
2. `aws_iam_role` -- trust policy for dms.amazonaws.com
3. `aws_iam_role_policy` -- inline policy with computed permissions
4. `aws_dms_replication_subnet_group` -- VPC subnet group
5. `aws_dms_replication_instance` -- the replication instance

**Not created by default** (can be added post-deployment):
- `aws_dms_endpoint` (source and target)
- `aws_dms_replication_task`
- `aws_dms_certificate`
- `aws_dms_event_subscription`

---

## 17. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `TestConnectionFailed` | Cannot reach source/target | Check VPC, security groups, credentials |
| `AccessDenied` / `InsufficientPrivileges` | Missing IAM permissions | Add permissions to DMS role |
| `StorageFull` | Instance storage exhausted | Increase allocated_storage |
| `TASK_FAILED` | Task-level error | Check CloudWatch logs for details |
| `CDC_SLOT_NOT_FOUND` | PostgreSQL replication slot dropped | Verify wal_level=logical, recreate slot |
| `binlog not found` | MySQL binlogs purged | Increase expire_logs_days, restart with full-load-and-cdc |
| `LOB_DATA_EXCEEDS_MAX_SIZE` | LOB too large for limited mode | Increase LobMaxSize or use full LOB mode |
| `TABLE_ERROR` | Data type mismatch or constraint violation | Check table_statistics, fix mappings |
| `REPLICATION_INSTANCE_NOT_FOUND` | Instance deleted | Re-run terraform apply |
| `ENDPOINT_NOT_FOUND` | Endpoint deleted | Check endpoint ARN, recreate |

### Troubleshooting Steps
1. Check task status: `dms.describe_replication_tasks()`
2. Check table statistics: `dms.describe_table_statistics(ReplicationTaskArn=arn)`
3. Check CloudWatch logs for `dms-tasks-*` log group
4. Test connectivity: `dms.test_connection(ReplicationInstanceArn=ri, EndpointArn=ep)`
5. Check replication instance metrics (CPU, memory, storage)

---

## 18. Developer Agent Operations

### Finding DMS Resources
```python
dms = boto3.client('dms', region_name=region)

# Find replication tasks
tasks = dms.describe_replication_tasks()['ReplicationTasks']
task = next(t for t in tasks if resource_name in t['ReplicationTaskIdentifier'])

# Find replication instances
instances = dms.describe_replication_instances()['ReplicationInstances']

# Find endpoints
endpoints = dms.describe_endpoints()['Endpoints']
```

### Modifying Table Mappings
```python
# MUST stop task first
dms.stop_replication_task(ReplicationTaskArn=task_arn)
# Wait for 'stopped' status
dms.modify_replication_task(
    ReplicationTaskArn=task_arn,
    TableMappings=json.dumps(new_mappings)
)
# Restart
dms.start_replication_task(
    ReplicationTaskArn=task_arn,
    StartReplicationTaskType='resume-processing'
)
```

### Checking Migration Progress
```python
stats = dms.describe_table_statistics(ReplicationTaskArn=task_arn)
for table in stats['TableStatistics']:
    print(f"{table['TableName']}: {table['FullLoadRows']} rows loaded, "
          f"{table['Inserts']} inserts, {table['Updates']} updates, "
          f"{table['Deletes']} deletes, state={table['TableState']}")
```

---

## 19. Best Practices

1. **Use full-load-and-cdc** for production migrations -- minimizes downtime
2. **Test connectivity first** -- run `test_connection` before creating tasks
3. **Run premigration assessment** -- catches issues before they cause failures
4. **Monitor storage** -- FreeStorageSpace metric; full storage = task failure
5. **Use Secrets Manager** for endpoint credentials
6. **Enable logging** at DEBUG level during initial migration
7. **Set appropriate LOB mode** -- limited mode for speed, full mode for completeness
8. **Configure error handling** -- LOG_ERROR for development, SUSPEND_TABLE for production
9. **Use multi-AZ** for production CDC tasks
10. **Right-size the instance** -- t2.micro for dev, c5/r5 for production
11. **Set up event subscriptions** for task failure notifications
12. **Use compression** (GZIP) when writing to S3 target

---

## 20. Service Quotas

| Quota | Limit |
|---|---|
| Replication instances per account | 60 (adjustable) |
| Total storage across all instances | 30 TB (adjustable) |
| Endpoints per account | 1,000 (adjustable) |
| Replication tasks per instance | 200 (adjustable) |
| Replication tasks per account | 600 (adjustable) |
| Subnet groups | 100 |
| Subnets per subnet group | 60 |
| Event subscriptions | 100 |
| Certificates | 100 |
| Default LOB max size (limited mode) | 64 KB |
