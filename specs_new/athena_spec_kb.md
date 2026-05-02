# Amazon Athena -- Complete Knowledge Base

> This document is the plain-English reference for Amazon Athena that the
> pipeline engine framework and developer agent can consult when handling any
> Athena-related request. It covers what Athena is, how workgroups/queries/
> catalogs work, all integration patterns, performance optimization, and
> troubleshooting.

---

## 1. What Is Amazon Athena?

Amazon Athena is a **serverless interactive query service** that lets you
analyze data directly in Amazon S3 using standard SQL. There is no
infrastructure to manage -- you submit a query, Athena runs it on a
distributed engine, and results are written to S3.

Athena is based on **Trino** (formerly Presto) for DML queries and uses
**Hive** DDL syntax for table management. It uses the **AWS Glue Data Catalog**
as its default metastore for table and partition metadata.

### Core Concepts

- **Workgroup**: Isolates queries, users, and costs. Each workgroup has its own
  result location, encryption settings, and cost controls.
- **Query Execution**: A single SQL query submission. Has states: QUEUED,
  RUNNING, SUCCEEDED, FAILED, CANCELLED.
- **Named Query**: A saved SQL query that can be executed by name.
- **Prepared Statement**: A parameterized query with `?` placeholders.
- **Data Catalog**: Metadata source (default: Glue Data Catalog). Can register
  external catalogs for federated queries.
- **Result Configuration**: S3 location and encryption for query results.

### Pricing (No Free Tier)

Athena has **no free tier**:
- $5.00 per TB of data scanned (most regions)
- DDL statements and failed queries are free
- Minimum charge: 10 MB per query
- CTAS/INSERT: billed for data scanned + data stored

**Key cost insight**: Using columnar formats (Parquet, ORC) can reduce costs by
90%+ compared to CSV/JSON because Athena reads only the columns needed.

---

## 2. Workgroups

Workgroups are the primary organizational unit in Athena. Every query runs
within a workgroup.

### Why Use Workgroups

1. **Cost control**: Set per-query data scan limits
2. **Result isolation**: Each workgroup has its own S3 result location
3. **Access control**: IAM policies can restrict users to specific workgroups
4. **Monitoring**: Separate CloudWatch metrics per workgroup
5. **Configuration**: Different engine versions, encryption settings

### Key Configuration

| Setting | Description | Default |
|---|---|---|
| enforce_workgroup_configuration | Force workgroup result config | true |
| publish_cloudwatch_metrics_enabled | Publish query metrics | false |
| bytes_scanned_cutoff_per_query | Max bytes before query is cancelled | None |
| requester_pays_enabled | Query requester-pays buckets | false |
| engine_version | Athena SQL engine version | AUTO |

### Default Workgroup

Every account has a `primary` workgroup that cannot be deleted. Our pipeline
engine creates custom workgroups for each pipeline.

### Engine Version

**Important for Terraform**: The engine version MUST be set to `"AUTO"`.
Setting a specific version (e.g., "Athena engine version 3") causes Terraform
validation errors.

---

## 3. Query Execution

### Submitting Queries

Queries are submitted via `start_query_execution()` and return a
`QueryExecutionId` for tracking. The query runs asynchronously.

### Query Lifecycle

1. **QUEUED** -- waiting for capacity
2. **RUNNING** -- executing on Athena engine
3. **SUCCEEDED** -- results written to S3
4. **FAILED** -- error occurred (check StateChangeReason)
5. **CANCELLED** -- user or system cancelled

### SQL Support

**DML**: SELECT, INSERT INTO, CTAS (CREATE TABLE AS SELECT), UNLOAD, DELETE
(Iceberg), UPDATE (Iceberg), MERGE INTO (Iceberg), OPTIMIZE, VACUUM

**DDL**: CREATE TABLE, CREATE EXTERNAL TABLE, CREATE VIEW, CREATE DATABASE,
ALTER TABLE, DROP TABLE/VIEW/DATABASE, SHOW, DESCRIBE, MSCK REPAIR TABLE

**Utility**: EXPLAIN, EXPLAIN ANALYZE, PREPARE, EXECUTE

### Query Result Reuse

Athena can cache and reuse results from identical queries (up to 60 minutes).
This avoids re-scanning data for repeated queries. Must be enabled in
workgroup configuration.

---

## 4. Data Sources

### Primary: S3

Athena's native data source. Supported formats:

| Format | Type | Cost Efficiency | Query Speed |
|---|---|---|---|
| **Parquet** | Columnar | Excellent | Fast |
| **ORC** | Columnar | Excellent | Fast |
| **Avro** | Row-based | Good | Medium |
| **CSV/TSV** | Row-based | Poor | Slow |
| **JSON** | Row-based | Poor | Slow |
| **Ion** | Row-based | Good | Medium |

**Best practice**: Always use Parquet with Snappy compression for the best
combination of cost and performance. Use CTAS to convert CSV/JSON data to
Parquet.

Compression: GZIP, BZIP2, LZ4, Snappy, ZSTD, LZO

### Open Table Formats

Athena supports three open table formats with advanced features:

| Format | ACID | Time Travel | Schema Evolution | DML |
|---|---|---|---|---|
| **Iceberg** | Yes | Yes | Yes | Full (UPDATE, DELETE, MERGE) |
| **Hudi** | Yes | Yes | Yes | Read-only in Athena |
| **Delta Lake** | Yes | Yes | Yes | Read-only in Athena |

### Glue Data Catalog

Athena uses the Glue Data Catalog as its default metadata store. Tables and
databases defined in the catalog are immediately available in Athena. The
built-in catalog name is `AwsDataCatalog`.

### Federated Queries

Athena can query 25+ external data sources via Lambda-based connectors:
- Amazon RDS (MySQL, PostgreSQL)
- Amazon Redshift
- Amazon DynamoDB
- Amazon DocumentDB
- Amazon OpenSearch
- CloudWatch Logs and Metrics
- Apache HBase, Redis, JDBC

Federated queries require:
- A Lambda connector function
- A registered Athena data catalog of type `LAMBDA`
- A spill bucket for large intermediate results
- `lambda:InvokeFunction` permission

---

## 5. CTAS and UNLOAD

### CTAS (CREATE TABLE AS SELECT)

Creates a new table from query results. Key use case: **convert CSV/JSON to
Parquet** for faster and cheaper subsequent queries.

```sql
CREATE TABLE my_db.parquet_table
WITH (
    format = 'PARQUET',
    external_location = 's3://bucket/output/',
    partitioned_by = ARRAY['year', 'month']
) AS
SELECT * FROM my_db.csv_table;
```

Supported output formats: PARQUET, ORC, AVRO, JSON, TEXTFILE
Compression: GZIP, SNAPPY, LZ4, ZSTD, NONE

### UNLOAD

Exports query results in a specific format to S3 without creating a catalog
table. Useful for data export pipelines.

```sql
UNLOAD (SELECT * FROM my_table WHERE year = '2024')
TO 's3://bucket/export/'
WITH (format = 'PARQUET', compression = 'SNAPPY')
```

---

## 6. Encryption

### Result Encryption

Query results can be encrypted:

| Option | Description |
|---|---|
| SSE_S3 | Amazon S3-managed keys (free) |
| SSE_KMS | AWS KMS-managed keys (KMS charges) |
| CSE_KMS | Client-side encryption with KMS (Athena encrypts before writing) |

### Source Data Encryption

Athena can transparently read S3 data encrypted with:
- SSE-S3 (automatic)
- SSE-KMS (needs `kms:Decrypt` permission)
- CSE-KMS (needs `kms:Decrypt` permission)

**Not supported**: SSE-C (customer-provided keys)

---

## 7. Integration Patterns

### Athena in the Pipeline Engine

The Athena renderer creates:
1. `aws_cloudwatch_log_group` -- for query execution logs
2. `aws_athena_workgroup` -- with result configuration pointing to an S3 bucket

If an S3 integration exists, the workgroup's result location uses that bucket.
Otherwise, it uses a conventionally named fallback.

### How Athena Connects to Other Services

| Integration | Direction | Who Owns Wiring |
|---|---|---|
| Athena -> S3 (data) | Athena reads source data | Athena workgroup |
| Athena -> S3 (results) | Athena writes query results | Athena workgroup |
| Athena -> Glue Catalog | Athena reads table metadata | Athena (implicit) |
| Lambda -> Athena | Lambda submits queries | Lambda |
| Step Functions -> Athena | SF starts query execution | Step Functions |
| Glue -> Athena | Glue job submits queries | Glue |
| QuickSight -> Athena | QuickSight uses Athena as data source | QuickSight |
| Athena -> Lambda (federated) | Federated query connector | Athena |

### Common Pipeline Patterns

1. **S3 -> Glue Crawler -> Athena**: Crawler catalogs S3 data, Athena queries it.
   Most common analytics pattern.
2. **S3 -> Athena (CTAS) -> S3**: Convert raw CSV/JSON to Parquet.
3. **Lambda -> Athena -> S3**: Event-driven query execution.
4. **Step Functions -> [Glue, Athena]**: Orchestrated ETL with post-ETL analytics.
5. **Athena -> QuickSight**: Interactive dashboards on S3 data.

---

## 8. Performance Optimization

### Data Format (Biggest Impact)

| Format | Data Scanned | Cost | Query Time |
|---|---|---|---|
| CSV (uncompressed) | 100% | $$$$$ | Slow |
| CSV (GZIP) | ~30-40% | $$$ | Medium |
| JSON | 100% | $$$$$ | Slow |
| Parquet | 5-20% | $ | Fast |
| ORC | 5-20% | $ | Fast |

### Partitioning

Partition data by commonly filtered columns (year, month, day, region).
Athena skips entire partitions when WHERE clauses match partition keys.

Example: `WHERE year = '2024' AND month = '01'` on a partitioned table scans
only that month's data instead of the entire table.

### Partition Projection

For tables with many partitions (thousands+), use Athena's partition
projection to avoid Glue Catalog overhead. Define partition structure in table
properties instead of registering each partition individually.

### Column Pruning

Only SELECT the columns you need. With columnar formats, Athena reads only
the requested columns from disk.

Bad: `SELECT * FROM table WHERE ...` (reads all columns)
Good: `SELECT id, name, amount FROM table WHERE ...` (reads 3 columns)

### Compression

Use Snappy (Parquet default) or ZSTD for the best balance of compression
ratio and decompression speed.

### Other Tips

- Use `LIMIT` wisely -- it limits output but Athena may still scan all data
- Use `approx_distinct()` instead of `COUNT(DISTINCT)` for large datasets
- Avoid too many small files -- merge into larger files (128 MB+)
- Use `MSCK REPAIR TABLE` to sync partitions after adding new data

---

## 9. IAM Permissions

### Common Query User Permissions

A user or service that queries via Athena needs permissions for three services:

**Athena**:
- `athena:StartQueryExecution`
- `athena:GetQueryExecution`
- `athena:GetQueryResults`
- `athena:GetWorkGroup`

**S3** (source data):
- `s3:GetObject`
- `s3:ListBucket`
- `s3:GetBucketLocation`

**S3** (results):
- `s3:PutObject`
- `s3:GetObject`
- `s3:GetBucketLocation`

**Glue Catalog**:
- `glue:GetDatabase`
- `glue:GetTable`
- `glue:GetPartitions`

### Workgroup-Level Access Control

Use the `athena:workgroup` condition key to restrict users to specific
workgroups:
```json
{
    "Effect": "Allow",
    "Action": "athena:StartQueryExecution",
    "Resource": "arn:aws:athena:*:*:workgroup/my-workgroup",
    "Condition": {
        "StringEquals": {"athena:workgroup": "my-workgroup"}
    }
}
```

---

## 10. Monitoring and Logging

### CloudWatch Metrics

When `publish_cloudwatch_metrics_enabled` is true:
- ProcessedBytes (data scanned per query)
- TotalExecutionTime
- EngineExecutionTime
- ServiceProcessingTime
- QueryPlanningTime
- QueryQueueTime

### CloudWatch Logs

The pipeline engine creates a CloudWatch Log Group at
`/aws/athena/{resource_name}` for Athena query execution logs.

### Pipeline Run Monitor

The log aggregator monitors Athena via CloudWatch Logs at the log group
`/aws/athena/{resource_name}`.

---

## 11. Quotas and Limits

| Resource | Default Limit | Adjustable |
|---|---|---|
| Concurrent queries per account | 25 | Yes (to hundreds) |
| Query string length | 256 KB | No |
| Query timeout | 30 minutes | No |
| Workgroups per account | 1,000 | Yes |
| Named queries per account | 1,000 | Yes |
| Prepared statements per workgroup | 1,000 | No |
| Data catalogs per account | 1,000 | No |
| Tags per workgroup | 50 | No |
| Min data scanned per query | 10 MB | No |

### Rate Limits

| Operation | Rate (per second) |
|---|---|
| StartQueryExecution | 20 |
| GetQueryExecution | 100 |
| GetQueryResults | 100 |
| BatchGetQueryExecution | 20 |
| ListQueryExecutions | 5 |

---

## 12. Common Errors and Troubleshooting

### FAILED Query

**First step**: Always check the error reason:
```python
athena.get_query_execution(QueryExecutionId=id)['QueryExecution']['Status']['StateChangeReason']
```

### TABLE_NOT_FOUND / HIVE_METASTORE_ERROR
**Cause**: Table does not exist in Glue Catalog.
**Fix**: Run Glue crawler to populate catalog, or create table via DDL.

### AccessDenied on S3 Results
**Cause**: Cannot write query results to S3 output location.
**Fix**: Add `s3:PutObject`, `s3:GetBucketLocation` for the results bucket.

### AccessDenied on Glue Catalog
**Cause**: Cannot read table metadata.
**Fix**: Add `glue:GetDatabase`, `glue:GetTable`, `glue:GetPartitions`.

### COLUMN_NOT_FOUND / SYNTAX_ERROR
**Cause**: SQL syntax error or column name mismatch.
**Fix**: Use `DESCRIBE table_name` to verify schema.

### HIVE_CANNOT_OPEN_SPLIT
**Cause**: S3 data files referenced by table do not exist.
**Fix**: Verify S3 paths. Run `MSCK REPAIR TABLE` for partition sync.

### QUERY_TIMEOUT
**Cause**: Query exceeded 30-minute timeout.
**Fix**: Optimize query -- add partition filters, use columnar format, reduce
data scanned.

### EXCEEDED_MEMORY_LIMIT
**Cause**: Query needs more memory than available.
**Fix**: Reduce result set, use `LIMIT`, approximate functions, or partition data.

### TooManyRequestsException
**Cause**: Exceeded concurrent query limit or API rate limit.
**Fix**: Implement exponential backoff. Request quota increase.

### INVALID_TABLE / SerDe Error / HIVE_BAD_DATA
**Cause**: Data format does not match table SerDe configuration.
**Fix**: Verify table definition matches actual data format.

---

## 13. Best Practices

1. **Use Parquet** for all analytical tables -- 90%+ cost savings vs CSV
2. **Partition by date** (year/month/day) for time-series data
3. **Use partition projection** for tables with thousands of partitions
4. **Set bytes_scanned_cutoff** on workgroups to prevent runaway query costs
5. **Enable enforce_workgroup_configuration** to control result locations
6. **Convert CSV to Parquet** using CTAS before running analytics
7. **Compress data** with Snappy or ZSTD
8. **Merge small files** into 128 MB+ files for optimal performance
9. **Use named queries** for reusable SQL
10. **Poll query status** with exponential backoff (not tight loops)

---

## 14. Developer Agent: Working with Athena

### Running a Query
```python
athena = boto3.client('athena', region_name=region)

# Submit query
response = athena.start_query_execution(
    QueryString='SELECT * FROM my_db.my_table LIMIT 10',
    WorkGroup=workgroup_name,
    QueryExecutionContext={'Database': 'my_db'},
    ResultConfiguration={
        'OutputLocation': 's3://results-bucket/prefix/'
    }
)
query_id = response['QueryExecutionId']

# Poll for completion
import time
while True:
    status = athena.get_query_execution(QueryExecutionId=query_id)
    state = status['QueryExecution']['Status']['State']
    if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
        break
    time.sleep(2)

if state == 'SUCCEEDED':
    results = athena.get_query_results(QueryExecutionId=query_id)
    for row in results['ResultSet']['Rows']:
        print([col.get('VarCharValue', '') for col in row['Data']])
elif state == 'FAILED':
    reason = status['QueryExecution']['Status']['StateChangeReason']
    print(f"Query failed: {reason}")
```

### Converting CSV to Parquet via CTAS
```python
ctas_query = """
CREATE TABLE my_db.parquet_events
WITH (
    format = 'PARQUET',
    external_location = 's3://output-bucket/parquet-events/',
    partitioned_by = ARRAY['year']
) AS
SELECT * FROM my_db.csv_events
"""
athena.start_query_execution(
    QueryString=ctas_query,
    WorkGroup=workgroup_name
)
```

### Updating Workgroup Configuration
```python
athena.update_work_group(
    WorkGroup=workgroup_name,
    ConfigurationUpdates={
        'ResultConfigurationUpdates': {
            'OutputLocation': 's3://new-results-bucket/prefix/'
        },
        'BytesScannedCutoffPerQuery': 1073741824,  # 1 GB limit
        'PublishCloudWatchMetricsEnabled': True
    }
)
```
