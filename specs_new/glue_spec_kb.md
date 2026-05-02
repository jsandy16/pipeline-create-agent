# AWS Glue -- Complete Knowledge Base

> This document is the plain-English reference for AWS Glue that the pipeline
> engine framework and developer agent can consult when handling any Glue-related
> request in a pipeline. It covers what Glue is, how crawlers/jobs/catalog work,
> all integration patterns, security, performance, and troubleshooting.

---

## 1. What Is AWS Glue?

AWS Glue is a fully managed extract, transform, and load (ETL) service. It has
four main components:

1. **Glue Data Catalog** -- a Hive-compatible metadata repository (databases,
   tables, schemas, partitions). Acts as the central schema store for Athena,
   EMR, Redshift Spectrum, and Lake Formation.
2. **Glue Crawlers** -- automated schema discovery agents that scan S3, JDBC
   databases, DynamoDB, Delta Lake, Iceberg, and Hudi tables, then populate the
   Data Catalog with table definitions.
3. **Glue ETL Jobs** -- Apache Spark or Python Shell scripts that read, transform,
   and write data. Support PySpark, Scala, and plain Python.
4. **Glue Triggers & Workflows** -- scheduling and orchestration primitives for
   chaining jobs and crawlers into DAGs.

Additional features: Data Quality (DQDL rules), Schema Registry, Connections
(JDBC, Kafka, MongoDB), Security Configurations (encryption), and Dev Endpoints.

### Free Tier

The Glue Data Catalog is always-free for the first 1 million objects stored and
1 million requests per month. Crawlers and ETL jobs are **not** free tier --
they are billed per DPU-hour:
- Spark jobs: $0.44 per DPU-hour
- Python Shell: $0.0625 per DPU-hour (1/16 DPU minimum)

---

## 2. Crawlers

A crawler connects to a data store, scans the data, infers schema (column names,
types, partitions), and writes table definitions to the Glue Data Catalog.

### How Crawlers Work

1. Crawler reads data from one or more **targets** (S3 paths, JDBC tables, etc.)
2. Uses built-in or custom **classifiers** to determine format (CSV, JSON,
   Parquet, ORC, Avro, XML, etc.)
3. Groups files with compatible schemas into a single catalog **table**
4. Detects partition structure from S3 key patterns (e.g., `year=2024/month=01/`)
5. Updates the Data Catalog according to the **schema change policy**

### Supported Targets

| Target Type | Description |
|---|---|
| S3 | Crawl S3 paths for files in any supported format |
| JDBC | Crawl RDS, Redshift, or external databases via JDBC |
| DynamoDB | Crawl DynamoDB tables |
| Catalog | Re-crawl existing Glue Catalog tables |
| Delta Lake | Crawl Delta Lake tables on S3 |
| Apache Iceberg | Crawl Iceberg tables on S3 |
| Apache Hudi | Crawl Hudi tables on S3 |

### Schema Change Policy

When a crawler detects schema changes on subsequent runs:
- **UPDATE_IN_DATABASE** (default): Merge new columns into existing table schema
- **LOG**: Record the change but do not modify the table
- **DELETE_FROM_DATABASE**: Remove tables whose data no longer exists
- **DEPRECATE_IN_DATABASE**: Mark tables as deprecated

### Recrawl Policy

- **CRAWL_EVERYTHING**: Re-scan all data on every run (default)
- **CRAWL_NEW_FOLDERS_ONLY**: Only scan new S3 folders since last crawl (faster)
- **CRAWL_EVENT_MODE**: Crawl based on S3 event notifications (most efficient)

### Scheduling

Crawlers can run on a cron schedule:
```
cron(0 * * * ? *)     -- every hour
cron(0 6 * * ? *)     -- daily at 6 AM UTC
cron(0 0 ? * MON *)   -- every Monday
```

---

## 3. ETL Jobs

### Job Types

| Type | Command Name | Engine | Min Workers | Best For |
|---|---|---|---|---|
| **Spark ETL** | `glueetl` | Apache Spark | 2 | Large-scale batch ETL |
| **Python Shell** | `pythonshell` | Pure Python | N/A (DPU) | Small tasks, API calls |
| **Streaming** | `gluestreaming` | Spark Streaming | 2 | Real-time ETL from Kinesis/Kafka |
| **Ray** | `glueray` | Ray | 2 | Distributed ML workloads |

### Worker Types

| Worker | vCPU | Memory | Disk | Cost |
|---|---|---|---|---|
| G.025X | 2 | 4 GB | 64 GB | $0.44/DPU-hr |
| G.1X | 4 | 16 GB | 64 GB | $0.44/DPU-hr |
| G.2X | 8 | 32 GB | 128 GB | $0.44/DPU-hr |
| G.4X | 16 | 64 GB | 256 GB | $0.44/DPU-hr |
| G.8X | 32 | 128 GB | 512 GB | $0.44/DPU-hr |
| Z.2X | 8 | 64 GB | 128 GB | Ray only |

### Glue Versions

- **Glue 4.0** (recommended): Spark 3.3, Python 3.10, optimized shuffle
- **Glue 3.0**: Spark 3.1, Python 3.7, auto-scaling
- **Glue 2.0**: Spark 2.4, Python 3.7, reduced startup time

### Job Bookmarks

Job bookmarks track which data has already been processed, enabling incremental
ETL. When enabled, Glue remembers the last processed position and only reads new
data on subsequent runs. Works with S3 (file paths), JDBC (primary key ranges),
and other sources.

### Default Arguments (Spark Jobs)

Key arguments set via `--key value` in DefaultArguments:
- `--enable-continuous-cloudwatch-log true` -- stream logs to CloudWatch
- `--enable-spark-ui true` -- enable Spark UI in S3
- `--enable-metrics true` -- publish execution metrics
- `--enable-auto-scaling true` -- auto-scale workers (Glue 3.0+)
- `--job-language python` -- Python or Scala
- `--TempDir s3://bucket/temp/` -- temporary directory for intermediate results
- `--extra-py-files s3://bucket/lib.zip` -- additional Python libraries
- `--extra-jars s3://bucket/jar.jar` -- additional Java JARs

### Python Shell Jobs

For lightweight tasks that do not need Spark:
- 0.0625 DPU (1/16) or 1 DPU
- Much cheaper: ~$0.004/hour at minimum DPU
- Good for: API calls, small file processing, database queries, notifications
- Max memory: ~1 GB at 1/16 DPU, ~16 GB at 1 DPU
- Pre-installed: boto3, numpy, pandas, scikit-learn, scipy

---

## 4. Triggers and Workflows

### Trigger Types

| Type | Description |
|---|---|
| **SCHEDULED** | Run on a cron schedule |
| **CONDITIONAL** | Run when predecessor jobs/crawlers complete (success/failure) |
| **ON_DEMAND** | Run manually via API or console |
| **EVENT** | Run in response to an EventBridge event |

### Workflows

Workflows orchestrate multiple Glue jobs and crawlers as a directed acyclic
graph (DAG). Each node in the graph is connected by triggers.

Features:
- Visual graph of dependencies
- Run properties (key-value params passed to all jobs in the workflow)
- Max concurrent runs (default: 1)
- States: RUNNING, COMPLETED, STOPPING, STOPPED, ERROR

**When to use Glue Workflows vs Step Functions**: Use Glue Workflows when all
nodes are Glue jobs/crawlers. Use Step Functions when orchestrating across
multiple AWS service types.

---

## 5. Connections

Glue Connections store network and authentication details for external data stores.

| Type | Use Case | VPC Required |
|---|---|---|
| JDBC | RDS, Redshift, external databases | Yes |
| KAFKA | Apache Kafka, Amazon MSK | Yes |
| MONGODB | MongoDB, DocumentDB | Yes |
| NETWORK | Generic VPC access | Yes |
| MARKETPLACE | AWS Marketplace connectors | Varies |
| CUSTOM | Custom Glue Connector interface | Varies |

**VPC Configuration**: Connections that require VPC access need a subnet ID,
security group ID, and availability zone. The Glue role also needs
`ec2:CreateNetworkInterface`, `ec2:DeleteNetworkInterface`,
`ec2:DescribeNetworkInterfaces`, and `ec2:DescribeSecurityGroups`.

---

## 6. Data Quality

Glue Data Quality lets you define rules using **Data Quality Definition Language
(DQDL)** to validate data during ETL.

### Common DQDL Rules

```
RowCount > 0
IsComplete "email"
IsUnique "customer_id"
ColumnLength "phone" between 10 and 15
ColumnValues "status" in ["active", "inactive"]
CustomSql "SELECT COUNT(*) FROM primary WHERE amount < 0" = 0
```

Rules can be:
- Defined inline in ETL jobs via GlueContext
- Created as standalone rulesets and evaluated independently
- Results published to CloudWatch metrics

---

## 7. Encryption

### Security Configurations

A Glue Security Configuration bundles three encryption settings:
1. **S3 encryption**: SSE-S3 or SSE-KMS for data at rest in S3
2. **CloudWatch encryption**: SSE-KMS for CloudWatch Logs
3. **Job bookmark encryption**: SSE-KMS for bookmark data

### Data Catalog Encryption

Separate from Security Configurations:
- **Encryption at rest**: Encrypt all catalog objects with KMS
- **Connection password encryption**: Encrypt connection passwords with KMS

---

## 8. Integration Patterns

### Glue in the Pipeline Engine

In our pipeline engine, Glue is rendered as a **crawler + catalog database**.
The Glue renderer creates:
1. `aws_cloudwatch_log_group` -- for Glue job logs
2. `aws_glue_catalog_database` -- the catalog database
3. `aws_iam_role` + `aws_iam_role_policy` -- execution role
4. `aws_glue_crawler` -- with S3 targets from integrations

### How Glue Connects to Other Services

| Integration | Direction | Who Owns Wiring | IAM on Glue |
|---|---|---|---|
| S3 -> Glue | Glue reads S3 | Glue (s3_target block) | s3:GetObject, s3:ListBucket |
| Glue -> S3 | Glue writes S3 | Glue | s3:PutObject, s3:ListBucket |
| Glue -> DynamoDB | Glue reads/writes | Glue | dynamodb:GetItem, PutItem, Query, Scan |
| Glue -> Redshift | JDBC connection | Glue | redshift:DescribeClusters, GetClusterCredentials |
| Glue -> Aurora | JDBC or Data API | Glue | rds-data:ExecuteStatement, secretsmanager:GetSecretValue |
| Glue -> Kinesis | Streaming read/write | Glue | kinesis:PutRecord, GetRecords, DescribeStream |
| Glue -> Data Catalog | Catalog updates | Glue | glue:GetDatabase, CreateTable, UpdateTable |
| Step Functions -> Glue | SF starts Glue job | Step Functions | glue:StartJobRun, GetJobRun |
| Lambda -> Glue | Lambda starts crawler | Lambda | glue:StartCrawler, GetCrawler |
| EventBridge -> Glue | Schedule Glue job | EventBridge | via event target |
| Glue -> MSK | Streaming from Kafka | Glue | kafka:DescribeCluster, GetBootstrapBrokers |
| Lake Formation -> Glue | Fine-grained access | Lake Formation | lakeformation:GetDataAccess |

### VPC Triggers

Glue requires VPC placement when connecting to:
- **Aurora** (via JDBC connection)
- **Redshift** (via JDBC connection)
- **MSK/Kafka** (via Kafka connection)

VPC access additionally requires these IAM permissions on the Glue role:
- `ec2:CreateNetworkInterface`
- `ec2:DeleteNetworkInterface`
- `ec2:DescribeNetworkInterfaces`
- `ec2:DescribeSecurityGroups`
- `ec2:DescribeSubnets`
- `ec2:DescribeVpcAttribute`

---

## 9. IAM Permissions

### Glue Execution Role

Every Glue crawler and job needs an IAM role with the `glue.amazonaws.com`
service principal. The minimum permissions include:

**Always required** (from spec):
- CloudWatch Logs: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
- Data Catalog: `glue:GetDatabase`, `glue:GetTable`, `glue:CreateTable`,
  `glue:UpdateTable`, `glue:DeleteTable`, `glue:GetPartition`,
  `glue:CreatePartition`, `glue:UpdatePartition`, `glue:BatchCreatePartition`,
  `glue:BatchDeletePartition`

**Additional based on integrations**:
- S3 access: `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`, `s3:DeleteObject`
- DynamoDB: `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:BatchWriteItem`,
  `dynamodb:Query`, `dynamodb:Scan`
- Redshift: `redshift:DescribeClusters`, `redshift:GetClusterCredentials`,
  `redshift-data:ExecuteStatement`, `redshift-data:GetStatementResult`
- Aurora: `rds-data:ExecuteStatement`, `rds-data:BatchExecuteStatement`,
  `secretsmanager:GetSecretValue`

### AWS Managed Policy

`AWSGlueServiceRole` provides baseline Glue + S3 + CloudWatch permissions.
However, our pipeline engine uses inline policies computed from the integration
graph for least-privilege access.

---

## 10. Monitoring and Logging

### CloudWatch Logs

Glue jobs log to CloudWatch when `--enable-continuous-cloudwatch-log` is set.
The log group pattern is: `/aws-glue/jobs/{job_name}`

Log types:
- **Driver logs**: Main application output
- **Executor logs**: Per-executor Spark logs
- **Progress bar**: Job progress updates

### CloudWatch Metrics

Namespace: `AWS/Glue`
Key metrics:
- `glue.ALL.jvm.heap.used` -- heap memory usage
- `glue.ALL.system.cpuSystemLoad` -- CPU utilization
- `glue.ALL.s3.filesystem.read_bytes` -- S3 bytes read
- `glue.ALL.s3.filesystem.write_bytes` -- S3 bytes written
- `glue.driver.aggregate.bytesRead` -- total bytes read
- `glue.driver.aggregate.recordsRead` -- total records read

### Spark UI

When enabled (`--enable-spark-ui true`), Spark UI event logs are written to S3.
Accessible via the Glue console's "Spark UI" tab for each job run.

### Pipeline Run Monitor

The pipeline log aggregator monitors Glue via CloudWatch Logs at the log group
`/aws-glue/jobs/{resource_name}`. This provides real-time log streaming during
pipeline execution.

---

## 11. Quotas and Limits

| Resource | Default Limit | Adjustable |
|---|---|---|
| Jobs per account | 1,000 | Yes |
| Concurrent job runs per account | 200 | Yes |
| Concurrent job runs per job | 1,000 | Yes |
| Crawlers per account | 1,000 | Yes |
| Concurrent crawler runs | 100 | Yes |
| Databases per catalog | 10,000 | Yes |
| Tables per database | 1,000,000 | Yes |
| Partitions per table | 10,000,000 | Yes |
| Triggers per account | 1,000 | Yes |
| Workflows per account | 250 | Yes |
| Max DPU per job | 100 | No |
| Job script size | 50 MB | No |
| Job timeout | 2,880 min (48 hrs) | No |

---

## 12. Common Errors and Troubleshooting

### AccessDenied on S3
**Cause**: Glue role lacks `s3:GetObject` or `s3:ListBucket` permissions.
**Fix**: Add S3 permissions to the Glue execution role's policy.

### EntityNotFoundException
**Cause**: Catalog database or table does not exist -- crawler has not run yet.
**Fix**: Run the crawler first: `glue.start_crawler(Name=crawler_name)`

### CrawlerRunningException
**Cause**: Attempting to start a crawler that is already running.
**Fix**: Wait for the current run to finish. Poll `get_crawler()` until state
is `READY`.

### ConcurrentRunsExceededException
**Cause**: Too many job runs for the account or individual job.
**Fix**: Wait for existing runs to complete, or request a limit increase.

### OutOfMemoryError / Container Killed by YARN
**Cause**: Spark job ran out of memory.
**Fix**: Scale up the worker type (G.1X to G.2X) or increase the number of
workers. Also consider optimizing Spark code (reduce shuffles, use partitioning).

### Connection Failed / JDBC Error
**Cause**: Cannot connect to target database (VPC, credentials, or network issue).
**Fix**: Verify VPC configuration (subnet, security group), check JDBC URL and
credentials in the Glue connection.

---

## 13. Best Practices

1. **Use Glue 4.0** for best performance and latest Spark features
2. **Enable auto-scaling** (Glue 3.0+) to avoid over-provisioning
3. **Use job bookmarks** for incremental processing to avoid reprocessing data
4. **Use Python Shell** for small tasks -- 7x cheaper than Spark at minimum DPU
5. **Use CRAWL_NEW_FOLDERS_ONLY** recrawl policy for large S3 datasets
6. **Enable continuous CloudWatch logging** for debugging
7. **Use Glue connections** for VPC-based data stores instead of hardcoding endpoints
8. **Set up abort incomplete multipart upload** lifecycle rules on Glue temp S3 buckets
9. **Catalog database names must use underscores, not hyphens** -- this is a
   common validation error
10. **Use Security Configurations** for encryption at rest when processing
    sensitive data

---

## 14. Developer Agent: Working with Glue

### Updating Crawler Configuration
```python
glue = boto3.client('glue', region_name=region)
glue.update_crawler(
    Name=resource_name,
    Targets={'S3Targets': [{'Path': 's3://new-bucket/prefix/'}]},
    Schedule='cron(0 6 * * ? *)'
)
```

### Updating ETL Job Script
```python
# Get current script location
job = glue.get_job(JobName=resource_name)['Job']
script_loc = job['Command']['ScriptLocation']  # s3://bucket/key
bucket, key = script_loc[5:].split('/', 1)

# Download, modify, re-upload
s3 = boto3.client('s3')
script = s3.get_object(Bucket=bucket, Key=key)['Body'].read().decode()
modified = script.replace('old_logic', 'new_logic')
s3.put_object(Bucket=bucket, Key=key, Body=modified.encode())
```

### Starting a Job Run
```python
response = glue.start_job_run(
    JobName=resource_name,
    Arguments={'--my_param': 'value'}
)
run_id = response['JobRunId']

# Poll for completion
while True:
    run = glue.get_job_run(JobName=resource_name, RunId=run_id)['JobRun']
    if run['JobRunState'] in ['SUCCEEDED', 'FAILED', 'STOPPED', 'TIMEOUT']:
        break
    time.sleep(30)
```
