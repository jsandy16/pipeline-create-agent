# Amazon Kinesis Data Analytics (v2) -- Complete Knowledge Base

> This document is the plain-English reference for Kinesis Data Analytics that
> the pipeline engine framework and developer agent can consult when handling
> any analytics application request in a pipeline. It covers SQL and Apache Flink
> applications, inputs/outputs, integrations, and troubleshooting.

---

## 1. What Is Kinesis Data Analytics?

Amazon Kinesis Data Analytics (KDA) is a service for processing streaming data
in real time using SQL queries or Apache Flink applications. It was rebranded to
"Amazon Managed Service for Apache Flink" in August 2023, but our pipeline
engine uses the original naming convention (`kinesis_analytics`).

The service has two application modes:

- **SQL Applications** (SQL-1_0): Write SQL queries that run continuously against
  streaming input. Simple but limited. Being deprecated.
- **Flink Applications** (FLINK-1_x): Compile and deploy Java, Scala, or Python
  (PyFlink) code that runs on managed Apache Flink infrastructure. Powerful but
  requires coding.

### Core Concepts

- **Application**: A running compute instance that processes streaming data.
  Has an execution role, input(s), output(s), and application code.
- **KPU (Kinesis Processing Unit)**: The compute unit. Each KPU provides 1 vCPU
  and 4 GB memory. You pay per KPU-hour (~$0.11/hour).
- **Parallelism**: Number of parallel tasks. Each task uses one KPU (by default).
- **Input**: Streaming data source (Kinesis Streams or Firehose for SQL; any
  Flink connector for Flink applications).
- **Output**: Destination for processed data (Kinesis Streams, Firehose, Lambda,
  S3, etc.).
- **In-Application Stream**: Internal data channel within a SQL application.
  Data flows from input to in-application streams to output.

### NOT Free Tier

Kinesis Analytics is never free tier eligible. ~$0.11/KPU-hour minimum (1 KPU).
Flink applications also charge for snapshot storage (~$0.10/GB-month).

---

## 2. SQL Applications

SQL applications are the simpler mode. You write SQL queries that process
streaming data. Best for filtering, aggregation, and simple transformations.

### How SQL Applications Work

1. Data arrives from a streaming input (Kinesis Streams or Firehose)
2. Data lands in `SOURCE_SQL_STREAM_001` (the input in-application stream)
3. Your SQL code processes the data:
   - SELECT, WHERE, GROUP BY (with windowing), JOIN (with reference data)
   - Results are written to `DESTINATION_SQL_STREAM`
4. Output mappings deliver results to Kinesis Streams, Firehose, or Lambda

### Key SQL Concepts

**In-Application Streams**: Internal data channels. Think of them as tables
that records flow through. You CREATE them, INSERT INTO them, and SELECT FROM
them. Max 64 per application.

**PUMPs**: Continuous INSERT INTO queries. A PUMP moves data from one
in-application stream to another. Required to connect SQL outputs.

```sql
CREATE OR REPLACE PUMP "MY_PUMP" AS
INSERT INTO "DESTINATION_SQL_STREAM"
SELECT STREAM "device_id", COUNT(*) AS "event_count"
FROM "SOURCE_SQL_STREAM_001"
GROUP BY "device_id",
         STEP("SOURCE_SQL_STREAM_001".ROWTIME BY INTERVAL '1' MINUTE);
```

**Windowing Functions**:

| Window Type | Description | SQL Pattern |
|---|---|---|
| Tumbling | Fixed-size, non-overlapping | `GROUP BY STEP(ROWTIME BY INTERVAL '1' MINUTE)` |
| Sliding | Fixed-size, overlapping | `GROUP BY STEP(ROWTIME BY INTERVAL '10' SECOND) WINDOW INTERVAL '1' MINUTE` |
| Stagger | Based on key's first arrival | `WINDOWED BY STAGGER(ORDER BY ROWTIME, PARTITION BY key RANGE INTERVAL '1' MINUTE)` |

**Reference Data**: S3-backed lookup tables for enrichment. Max 1 GB. Loaded
at application start and refreshed via API call.

### SQL Limitations

- Single streaming input source only
- Max 3 output destinations
- Max 100 KB application code
- Max 64 in-application streams
- No custom code (SQL only)
- Being deprecated in favor of Flink

---

## 3. Apache Flink Applications

Flink applications are the powerful mode. You write Java, Scala, or Python code
that runs on managed Apache Flink infrastructure. Supports complex event
processing, exactly-once semantics, stateful computations, and multiple
inputs/outputs.

### How Flink Applications Work

1. Package your Flink code as a JAR (Java/Scala) or ZIP (Python) file
2. Upload to S3
3. Create the application, referencing the S3 code location
4. Start the application -- KDA provisions Flink infrastructure and runs your code

### Flink Runtime Versions

| Version | Status | Key Features |
|---|---|---|
| FLINK-1_6 | Legacy | Basic streaming |
| FLINK-1_8 | Legacy | Improved state management |
| FLINK-1_11 | Supported | Python (PyFlink), Table API |
| FLINK-1_13 | Supported | Improved watermarks, CDC connectors |
| FLINK-1_15 | Supported | Improved checkpointing, SQL improvements |
| FLINK-1_18 | Supported | Better PyFlink, watermark alignment |
| FLINK-1_19 | Latest | Latest features |

### Key Flink Features

**Checkpointing**: Flink periodically snapshots application state. If the
application fails, it restarts from the latest checkpoint with exactly-once
processing guarantees. Default interval: 60 seconds.

**Parallelism**: Number of parallel tasks (like threads). Each task gets one
KPU by default. `parallelism_per_kpu` (1-8) lets you run multiple tasks per
KPU to reduce cost.

**Auto-Scaling**: Flink can auto-scale parallelism based on throughput.
Enabled via `auto_scaling_enabled = true`.

**Snapshots**: Manually triggered state snapshots (separate from automatic
checkpoints). Used for:
- Application version updates (stop with snapshot, update code, start from snapshot)
- Rollback to previous state after a bad deployment
- Forking applications

**Runtime Properties**: Key-value properties passed to the Flink application
(like environment variables). Accessed in code via
`KinesisAnalyticsRuntime.getApplicationProperties()`.

### Flink Connectors

| Connector | Source | Sink |
|---|---|---|
| Kinesis Streams | flink-connector-kinesis | flink-connector-kinesis |
| Kafka (MSK) | flink-connector-kafka | flink-connector-kafka |
| S3 | flink-connector-filesystem | flink-connector-filesystem |
| OpenSearch | -- | flink-connector-elasticsearch |
| JDBC (Aurora, RDS) | flink-connector-jdbc | flink-connector-jdbc |

---

## 4. Application Lifecycle

```
CREATED  -->  STARTING  -->  RUNNING  -->  STOPPING  -->  READY (STOPPED)
                                 |
                                 +------->  FORCE_STOPPING  -->  READY
```

- **start_application**: Start processing (from READY state)
- **stop_application**: Stop processing (creates snapshot for Flink apps)
- **stop_application(Force=true)**: Force stop without snapshot (for stuck apps)
- **update_application**: Update code/config (SQL: must stop first; Flink: in-place)

**Important**: SQL applications must be STOPPED to update code. Flink
applications can be updated while RUNNING (with automatic snapshot).

---

## 5. Integration Patterns in the Pipeline Engine

### Kinesis Analytics Inputs (Data Flows In)

| Source | SQL | Flink | Terraform |
|---|---|---|---|
| **Kinesis Streams** | `inputs` block | Code connector | `kinesis_streams_input` |
| **Kinesis Firehose** | `inputs` block | Code connector | `kinesis_firehose_input` |
| **MSK** | No | Code connector | VPC config required |
| **S3 (reference)** | `reference_data_sources` | Code | S3 ARN in config |
| **S3 (Flink code)** | N/A | `s3_content_location` | Bucket + key |

### Kinesis Analytics Outputs (Data Flows Out)

| Destination | SQL | Flink | Terraform |
|---|---|---|---|
| **Kinesis Streams** | `outputs` block | Code connector | `kinesis_streams_output` |
| **Kinesis Firehose** | `outputs` block | Code connector | `kinesis_firehose_output` |
| **Lambda** | `outputs` block | No | `lambda_output` |
| **S3** | No | FileSystem sink | Code-level |
| **MSK** | No | Kafka sink | Code-level, VPC required |

### Wiring Ownership

The Kinesis Analytics renderer (`_render_kinesis_analytics`) owns:
- The application resource
- CloudWatch Log Group and Log Stream
- IAM role and policy
- Input configuration (when sourcing from Kinesis Streams)
- Output configurations (for SQL applications)

---

## 6. Terraform Pattern in the Pipeline Engine

The `_render_kinesis_analytics` function generates:

1. **CloudWatch Log Group** (`/aws/kinesis-analytics/{name}`)
2. **CloudWatch Log Stream** (`application-logs`)
3. **IAM Role** (trust: kinesisanalytics.amazonaws.com)
4. **IAM Policy** with permissions for inputs, outputs, and logging
5. **Application** with:
   - Runtime environment (SQL-1_0 by default)
   - Service execution role
   - SQL application configuration with input block (if Kinesis Streams source)
   - CloudWatch logging options

The renderer checks incoming integrations (`integrations_as_target`) for a
Kinesis Streams source and creates the `inputs` block with schema configuration
(JSON format, VARCHAR payload column).

---

## 7. IAM Permissions

### Application Execution Role

The execution role needs permissions for:

| Purpose | Actions |
|---|---|
| **Always** | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` |
| **Read Kinesis Streams** | `kinesis:GetRecords`, `kinesis:GetShardIterator`, `kinesis:DescribeStream`, `kinesis:ListShards` |
| **Read Firehose** | `firehose:DescribeDeliveryStream` |
| **Write Kinesis Streams** | `kinesis:PutRecord`, `kinesis:PutRecords` |
| **Write Firehose** | `firehose:PutRecord`, `firehose:PutRecordBatch` |
| **Write to Lambda** | `lambda:InvokeFunction` |
| **Read/Write S3** | `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` |
| **VPC (if needed)** | `ec2:Describe*`, `ec2:CreateNetworkInterface`, `ec2:DeleteNetworkInterface` |
| **Glue (Flink SQL)** | `glue:GetDatabase`, `glue:GetTable`, `glue:GetTables` |
| **MSK (Flink)** | `kafka-cluster:Connect`, `kafka-cluster:ReadData`, `kafka-cluster:WriteData`, etc. |

---

## 8. Common Error Patterns and Fixes

### ResourceInUseException (Application Running)

**Cause**: Cannot update a SQL application while it is running.

**Fix**: Stop the application first:
```python
kda.stop_application(ApplicationName='my-app')
# Wait for READY status
kda.update_application(ApplicationName='my-app', ...)
kda.start_application(ApplicationName='my-app', ...)
```

### SQL Syntax Errors

**Cause**: Invalid SQL code in the application.

**Fix**: Common issues:
- Stream names must be in double quotes: `"SOURCE_SQL_STREAM_001"`
- Column names are case-sensitive
- Missing PUMP (INSERT INTO must use `CREATE OR REPLACE PUMP`)
- ROWTIME is a special column -- cannot be selected directly, use STEP()

### Version Conflict

**Cause**: `CurrentApplicationVersionId` does not match (concurrent update).

**Fix**: Call `describe_application` to get the latest version ID, then retry.

### Schema Discovery Failure

**Cause**: `discover_input_schema` cannot determine schema from input stream.

**Fix**: Ensure the input stream has records in JSON or CSV format. Try manual
schema definition instead of auto-discovery.

### InvalidApplicationConfigurationException

**Cause**: Application config is invalid (wrong Flink version, missing VPC, etc.).

**Fix**: Check that `runtime_environment` matches the code version. If accessing
MSK or Aurora, add VPC configuration.

---

## 9. Monitoring

### CloudWatch Metrics (AWS/KinesisAnalytics namespace)

Key SQL application metrics:
- `InputBytes` / `InputRecords`: Input throughput
- `OutputBytes` / `OutputRecords`: Output throughput
- `LateInputRecords`: Records that arrived after the watermark
- `Success` / `InputProcessing.ProcessingFailedRecords`: Processing status

Key Flink application metrics:
- `cpuUtilization`: CPU usage per KPU
- `heapMemoryUtilization`: Memory usage
- `lastCheckpointDuration`: Checkpoint time
- `lastCheckpointSize`: Checkpoint state size
- `numberOfFailedCheckpoints`: Checkpoint failures
- `numRecordsInPerSecond` / `numRecordsOutPerSecond`: Throughput
- `currentInputWatermark` / `currentOutputWatermark`: Watermark lag

### Pipeline Run Monitor

Kinesis Analytics is monitored via **CloudWatch Logs** in the pipeline run
monitor. The log group pattern is `/aws/kinesis-analytics/{resource_name}`.
Logs include application errors, SQL compilation issues, and Flink task
failures.

---

## 10. Best Practices

1. **Use Flink for new workloads**. SQL applications are being deprecated.
   Flink offers more power, better performance, and exactly-once semantics.

2. **Start with 1 KPU** and enable auto-scaling for Flink applications. KDA
   will scale up as needed.

3. **Design for checkpointing**. Keep Flink application state small and
   serializable. Large state = slow checkpoints = longer recovery time.

4. **Use runtime properties** instead of hardcoding configuration in Flink code.
   This lets you change settings without redeploying.

5. **Test SQL locally** before deploying. Common pitfalls: case-sensitive column
   names, missing PUMPs, incorrect window syntax.

6. **Monitor checkpoint duration**. If checkpoints take longer than the
   checkpoint interval, the application will fall behind.

7. **Use snapshots for deployments**. Stop with snapshot, update code, start
   from snapshot. This preserves application state across updates.

---

## 11. Kinesis Analytics vs EMR vs Glue

| Feature | Kinesis Analytics | EMR (Spark/Flink) | Glue |
|---|---|---|---|
| **Processing model** | Streaming only | Batch + streaming | Batch + streaming |
| **Managed** | Fully managed | Semi-managed | Fully managed |
| **Compute unit** | KPU ($0.11/hr) | EC2 instances | DPU ($0.44/hr) |
| **Latency** | Milliseconds-seconds | Seconds-minutes | Minutes |
| **Code** | SQL or Flink JAR | Spark/Flink/Hive/etc. | PySpark/Python |
| **Best for** | Real-time stream processing | Complex ETL, large-scale analytics | Serverless ETL |

Choose Kinesis Analytics when you need low-latency real-time processing of
streaming data. Choose EMR when you need large-scale batch + streaming with
full control. Choose Glue for serverless ETL jobs.

---

## 12. Developer Agent Patterns

**Checking application status**:
```python
kda = boto3.client('kinesisanalyticsv2')
app = kda.describe_application(ApplicationName='my-app')
status = app['ApplicationDetail']['ApplicationStatus']
version = app['ApplicationDetail']['ApplicationVersionId']
```

**Starting an application**:
```python
kda.start_application(
    ApplicationName='my-app',
    RunConfiguration={
        'SqlRunConfigurations': [{
            'InputId': '1.1',
            'InputStartingPositionConfiguration': {
                'InputStartingPosition': 'NOW'
            }
        }]
    }
)
```

**Stopping an application**:
```python
kda.stop_application(ApplicationName='my-app')
```

**Updating SQL code**:
```python
kda.update_application(
    ApplicationName='my-app',
    CurrentApplicationVersionId=version,
    ApplicationConfigurationUpdate={
        'SqlApplicationConfigurationUpdate': {
            'InputUpdates': [],
            'OutputUpdates': [],
            'ReferenceDataSourceUpdates': []
        },
        'ApplicationCodeConfigurationUpdate': {
            'CodeContentType': 'PLAINTEXT',
            'CodeContentUpdate': {
                'TextContentUpdate': 'SELECT STREAM * FROM "SOURCE_SQL_STREAM_001" WHERE "value" > 100;'
            }
        }
    }
)
```

**Creating a Flink snapshot**:
```python
kda.create_application_snapshot(
    ApplicationName='my-app',
    SnapshotName='pre-deploy-v2'
)
```
