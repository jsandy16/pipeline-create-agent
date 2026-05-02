# AWS Glue Data Catalog -- Complete Knowledge Base

> This document is the plain-English reference for the AWS Glue Data Catalog
> that the pipeline engine framework and developer agent can consult when
> handling any Data Catalog-related request. It covers what the catalog is,
> how databases/tables/partitions work, integration patterns with analytics
> services, and troubleshooting.

---

## 1. What Is the Glue Data Catalog?

The AWS Glue Data Catalog is a **centralized metadata repository** -- a Hive
Metastore-compatible service that stores database and table definitions
(schemas, column types, data locations, partition keys, SerDe information).
It does NOT store actual data; it stores descriptions of where data lives
and how it is structured.

There is **one Data Catalog per AWS account per region**. It serves as the
shared schema store for:
- Amazon Athena (SQL queries)
- Amazon EMR (Spark, Hive, Presto)
- Amazon Redshift Spectrum (external tables)
- AWS Lake Formation (fine-grained access control)
- AWS Glue ETL jobs (read/write table metadata)
- AWS Glue DataBrew (dataset references)

### Core Concepts

- **Catalog**: The top-level container. One per account per region.
- **Database**: A logical namespace grouping related tables (like a schema in
  RDBMS or a database in Hive).
- **Table**: Metadata describing a dataset: column names/types, storage
  location (S3 path), data format (SerDe), and partition keys.
- **Partition**: A segment of a table defined by specific partition key values,
  mapping to a distinct S3 prefix for partition pruning.
- **Connection**: Stored credentials and network configuration for accessing
  external data stores (JDBC, Kafka, etc.).
- **Schema Registry**: Versioned Avro/JSON schema definitions for data
  validation across services.

### Free Tier

The Data Catalog is **always free** for the first 1 million objects stored and
1 million requests per month. Beyond that: $1.00 per 100,000 objects
stored/month, $1.00 per 1 million requests.

---

## 2. Databases

A catalog database is a logical namespace. It groups related tables together.

### Naming Rules

This is a common source of errors:
- **Lowercase letters, digits, and underscores ONLY**
- **NO hyphens** (Hive metastore compatibility requirement)
- Max length: 252 characters
- Cannot start with a digit
- Must be unique within the catalog (account + region)

**Important**: The pipeline engine renderer converts hyphens to underscores in
database names: `bp.resource_name.replace('-', '_')`. This is because pipeline
names often contain hyphens, but catalog database names cannot.

### Database Properties

- **description**: Human-readable description
- **location_uri**: Default S3 location for tables (optional). When set, tables
  created in this database will inherit this as their default location.
- **parameters**: Key-value pairs for custom metadata
- **target_database**: For federated databases pointing to another account's
  catalog

### Federated Databases

You can create a database that points to a database in another AWS account's
catalog. This enables querying cross-account data without copying metadata.
Requires Lake Formation cross-account grants.

---

## 3. Tables

A catalog table describes the schema and storage location of a dataset. Tables
are the primary metadata unit used by query engines.

### Table Types

| Type | Description |
|---|---|
| **EXTERNAL_TABLE** | Points to data in S3. Most common. Data is not managed by the catalog. |
| **MANAGED_TABLE** | Catalog manages data lifecycle (rare in AWS). |
| **VIRTUAL_VIEW** | SQL view defined over other tables. Used by Athena/Presto. |
| **GOVERNED** | Lake Formation governed table with transactions and time-travel. |

### Storage Descriptor

The storage descriptor is the core of a table definition. It specifies:

- **location**: S3 path to the data (e.g., `s3://bucket/prefix/`)
- **columns**: List of `{Name, Type, Comment}` definitions
- **input_format**: Hadoop InputFormat class for reading
- **output_format**: Hadoop OutputFormat class for writing
- **SerDe info**: Serialization/deserialization library and parameters
- **compressed**: Whether data is compressed
- **sort_columns**: Sort order within Hive buckets

### Common SerDe Configurations

| Format | SerDe Library | Input Format |
|---|---|---|
| CSV | `LazySimpleSerDe` | `TextInputFormat` |
| JSON | `JsonSerDe` (OpenX) | `TextInputFormat` |
| Parquet | `ParquetHiveSerDe` | `MapredParquetInputFormat` |
| ORC | `OrcSerde` | `OrcInputFormat` |
| Avro | `AvroSerDe` | `AvroContainerInputFormat` |

### Hive Data Types

**Primitive**: string, int, bigint, double, float, boolean, binary, timestamp,
date, decimal, char, varchar, tinyint, smallint

**Complex**: array<type>, map<key_type, value_type>,
struct<field:type,...>, uniontype<type1,type2>

**Agent tip**: When creating tables via the API, use lowercase Hive type names
(e.g., `string`, not `STRING`).

---

## 4. Partitions

Partitions divide a table into segments based on column values. Each partition
maps to a distinct S3 prefix, enabling query engines to skip irrelevant data
(partition pruning). This is critical for performance with large datasets.

### Hive-Style Partitioning

S3 keys use `key=value` format:
```
s3://bucket/table/year=2024/month=01/data.parquet
s3://bucket/table/year=2024/month=02/data.parquet
```

Glue crawlers automatically detect and register Hive-style partitions.

### Non-Hive Partitioning

S3 keys use plain directories:
```
s3://bucket/table/2024/01/data.parquet
```

Requires manual partition definition or crawler configuration to interpret
the directory structure as partition values.

### Partition Indexes

Partition indexes speed up `GetPartitions` queries by maintaining an index
on partition key columns. Without indexes, every `GetPartitions` call scans
all partitions.

- Max 3 indexes per table
- Max 3 keys per index
- Created via `aws_glue_partition_index` Terraform resource

### Partition Projection (Athena-Specific)

Instead of registering every partition in the catalog, you can define partition
structure in table properties. Athena generates partition paths at query time.

Benefits:
- No need to add partitions when new data arrives
- No catalog API calls for partition listing
- Scales to millions of partitions without catalog overhead

Configuration (table parameters):
```
projection.enabled = true
projection.year.type = integer
projection.year.range = 2020,2030
projection.month.type = integer
projection.month.range = 1,12
storage.location.template = s3://bucket/table/${year}/${month}/
```

---

## 5. Schema Registry

The Data Catalog includes a schema registry for Avro and JSON Schema
definitions. Schemas are versioned and can enforce compatibility rules.

### Compatibility Modes

| Mode | New Version Must Be... |
|---|---|
| BACKWARD | Readable by consumers using previous version |
| FORWARD | Writable by producers using previous version |
| FULL | Both backward and forward compatible |
| NONE | No compatibility checks |

### Integrations

- **Kinesis Data Streams**: Validate records against schema on producer side
- **Amazon MSK**: Validate Kafka messages
- **Glue ETL**: Enforce schema in ETL jobs
- **Glue Streaming**: Handle schema evolution in streaming jobs

---

## 6. Access Control

### IAM Policies

Standard IAM policies control who can read/write catalog metadata. Actions
are granular:
- `glue:GetDatabase`, `glue:GetTable` for read
- `glue:CreateTable`, `glue:UpdateTable` for write
- `glue:DeleteTable`, `glue:DeleteDatabase` for delete

### Catalog Resource Policies

Catalog-level resource policies (similar to S3 bucket policies) control
cross-account access and fine-grained restrictions. Max size: 10 KB.

### Lake Formation

For production environments, Lake Formation is the recommended way to manage
Data Catalog access. It provides:
- Column-level access control
- Row-level filtering
- Tag-based access control
- Cross-account sharing
- Data auditing

---

## 7. Encryption

### Catalog Encryption at Rest

All catalog objects (databases, tables, partitions, connections) can be
encrypted with KMS. Two settings:

1. **Encryption at rest**: Encrypt all metadata with a KMS key
2. **Connection password encryption**: Encrypt stored connection passwords

Once enabled, all new catalog objects are encrypted. Existing objects are
encrypted when next updated.

---

## 8. Integration Patterns

### Data Catalog in the Pipeline Engine

The Data Catalog renderer creates a single resource:
- `aws_glue_catalog_database` with name converted from hyphens to underscores

The Data Catalog is a passive service -- it has no execution role and no
runtime behavior. Other services (Athena, EMR, Glue crawlers, etc.) read
from and write to the catalog.

### How Services Use the Data Catalog

| Service | Reads Catalog | Writes Catalog |
|---|---|---|
| Athena | Table definitions for queries | No |
| EMR | Hive metastore replacement | Creates tables from Spark/Hive |
| Redshift Spectrum | External table definitions | No |
| Glue Crawlers | N/A | Populates tables/partitions |
| Glue ETL | Table schemas | Can update tables |
| Glue DataBrew | Dataset definitions | No |
| Lake Formation | Applies access controls | Governed tables |
| Lambda | Reads metadata via API | Can update metadata |

---

## 9. Quotas and Limits

| Resource | Default Limit | Adjustable |
|---|---|---|
| Databases per catalog | 10,000 | Yes |
| Tables per database | 1,000,000 | Yes |
| Partitions per table | 10,000,000 | Yes |
| Table versions per table | 100,000 | Yes |
| Columns per table | 10,000 | No |
| Partition keys per table | 100 | No |
| Partition indexes per table | 3 | No |
| Connections per catalog | 1,000 | Yes |
| Partitions per BatchCreatePartition | 100 | No |
| Partitions per BatchDeletePartition | 25 | No |
| Partitions per BatchGetPartition | 1,000 | No |
| Catalog resource policy size | 10 KB | No |

### Throttle Rates

| Operation | Rate (requests/sec) |
|---|---|
| GetTable | 100 |
| GetPartition | 100 |
| BatchCreatePartition | 25 |
| CreateTable | 25 |

---

## 10. Common Errors and Troubleshooting

### EntityNotFoundException
**Cause**: Database or table does not exist. Most common when crawlers have
not run yet.
**Fix**: Run the associated Glue crawler to populate the catalog.

### AlreadyExistsException
**Cause**: Trying to create a database or table that already exists.
**Fix**: Use `update_database()` or `update_table()` instead, or skip creation.

### InvalidInputException (database name)
**Cause**: Database name contains hyphens, uppercase, or special characters.
**Fix**: Use only lowercase letters, digits, and underscores.

### AccessDeniedException
**Cause**: Caller's IAM role lacks required `glue:Get*` or `glue:Create*`
permissions.
**Fix**: Add appropriate Glue actions to the IAM policy.

### ResourceNumberLimitExceededException
**Cause**: Exceeded quota for databases, tables, or partitions.
**Fix**: Delete unused resources or request a quota increase.

### ConcurrentModificationException
**Cause**: Two processes (e.g., two crawlers) tried to modify the same
resource simultaneously.
**Fix**: Retry with exponential backoff. This is transient.

---

## 11. Best Practices

1. **Use Hive-style partitioning** (`year=2024/month=01/`) for automatic
   partition detection by crawlers
2. **Use partition projection** in Athena for tables with many partitions
   (thousands+) to avoid catalog overhead
3. **Use Parquet or ORC** format for best query performance with Athena and
   Redshift Spectrum
4. **Create partition indexes** for tables with frequently filtered partition keys
5. **Database names: underscores, not hyphens** -- this is the most common
   validation error
6. **Use Lake Formation** for production access control instead of raw IAM
7. **Clean up table versions** regularly -- they accumulate quickly with
   frequent crawler runs
8. **Use CRAWL_NEW_FOLDERS_ONLY** on crawlers to reduce partition churn
9. **Set location_uri** on databases for consistent default S3 paths

---

## 12. Developer Agent: Working with Data Catalog

### Creating a Table
```python
glue = boto3.client('glue', region_name=region)

glue.create_table(
    DatabaseName=database_name,
    TableInput={
        'Name': 'events',
        'TableType': 'EXTERNAL_TABLE',
        'StorageDescriptor': {
            'Location': 's3://my-bucket/events/',
            'InputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat',
            'OutputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat',
            'SerdeInfo': {
                'SerializationLibrary': 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
            },
            'Columns': [
                {'Name': 'event_id', 'Type': 'string'},
                {'Name': 'timestamp', 'Type': 'timestamp'},
                {'Name': 'data', 'Type': 'string'}
            ]
        },
        'PartitionKeys': [
            {'Name': 'year', 'Type': 'string'},
            {'Name': 'month', 'Type': 'string'}
        ]
    }
)
```

### Adding Partitions
```python
glue.batch_create_partition(
    DatabaseName=database_name,
    TableName='events',
    PartitionInputList=[
        {
            'Values': ['2024', '01'],
            'StorageDescriptor': {
                'Location': 's3://my-bucket/events/year=2024/month=01/',
                'InputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat',
                'OutputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat',
                'SerdeInfo': {
                    'SerializationLibrary': 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
                },
                'Columns': [
                    {'Name': 'event_id', 'Type': 'string'},
                    {'Name': 'timestamp', 'Type': 'timestamp'},
                    {'Name': 'data', 'Type': 'string'}
                ]
            }
        }
    ]
)
```

### Listing Tables
```python
response = glue.get_tables(DatabaseName=database_name)
for table in response['TableList']:
    print(f"Table: {table['Name']}")
    print(f"  Location: {table['StorageDescriptor']['Location']}")
    print(f"  Columns: {len(table['StorageDescriptor']['Columns'])}")
    print(f"  Partitions: {[p['Name'] for p in table.get('PartitionKeys', [])]}")
```
