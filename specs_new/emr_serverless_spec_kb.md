# Amazon EMR Serverless — Complete Knowledge Base

> This document is the plain-English reference for Amazon EMR Serverless that
> the pipeline engine framework and developer agent can consult when handling
> any EMR Serverless-related request in a pipeline. It covers what EMR Serverless
> is, how applications and job runs work, every feature, integration patterns,
> security, cost, and troubleshooting.

---

## 1. What Is EMR Serverless?

Amazon EMR Serverless lets you run Apache Spark and Hive jobs without managing
clusters. You create an **application** (a logical container), submit **job runs**
to it, and EMR Serverless automatically provisions, configures, and scales the
compute and memory. You pay only for the vCPU-seconds, GB-seconds of memory,
and ephemeral storage used during job execution.

### Core Concepts
- **Application**: A named serverless container for a specific framework (Spark or Hive).
  Applications have capacity limits, auto-start/stop policies, and optional VPC config.
- **Job run**: A single execution of a Spark or Hive workload. Each run gets isolated resources.
- **Worker**: A compute unit with configured vCPU, memory, and disk. Workers are Drivers or Executors.
- **Pre-initialized capacity**: Optional pre-warmed workers to reduce cold start latency.
- **Maximum capacity**: Upper bound on total resources (vCPU, memory, disk) the application can use.
- **Execution role**: IAM role that job runs assume to access S3, Glue, etc.

### Key Differences from EMR on EC2
| Feature | EMR on EC2 | EMR Serverless |
|---|---|---|
| Infrastructure | You manage EC2 clusters | Fully managed, no clusters |
| Pricing | Per-instance-hour | Per vCPU-second + GB-second |
| Scaling | Manual or managed scaling | Automatic within max capacity |
| Cold start | Cluster already running | 1-3 min (or instant with pre-init) |
| Applications | Spark, Hive, HBase, Flink, ... | Spark and Hive only |
| Type change | New cluster | Cannot change after creation |

### Free Tier
EMR Serverless is **never** free tier. You pay for every vCPU-second and
GB-second consumed. Pre-initialized capacity incurs charges even when idle.

### Prerequisite
EMR Serverless must be enabled in your AWS account before first use. Go to
AWS Console -> EMR -> EMR Serverless -> Get started (one-time per account/region).
Without this, Terraform apply fails with `SubscriptionRequiredException`.

---

## 2. Application Types

### Spark Applications
- Submit PySpark scripts or Scala JARs from S3
- Job driver key: `sparkSubmit`
- Supports Spark SQL, DataFrames, Structured Streaming, MLlib
- Uses Glue Data Catalog as the default Hive metastore

### Hive Applications
- Submit HiveQL scripts from S3
- Job driver key: `hive`
- Uses Tez execution engine
- Automatically uses Glue Data Catalog as metastore

### Architecture
- **X86_64**: Standard x86. Wider instance type availability.
- **ARM64**: Graviton-based. Up to 15% lower cost per vCPU-second.

---

## 3. Application Lifecycle

```
CREATING -> CREATED -> STARTING -> STARTED -> STOPPING -> STOPPED -> TERMINATED
```

- **CREATED**: Application exists but is not started. No workers running.
- **STARTING**: Pre-initializing workers (if initial_capacity > 0).
- **STARTED**: Ready to accept job runs. Pre-initialized workers are running.
- **STOPPED**: No workers. No compute charges. Restarts on next job (if auto_start enabled).

### Auto-Start
When enabled (default), the application automatically starts when a job run is
submitted. No need to call `start_application()` manually. Recommended to leave
enabled.

### Auto-Stop
When enabled (default), the application stops after being idle for the configured
timeout (default 15 minutes). This releases pre-initialized workers to save cost.
The app restarts automatically on the next job submission.

---

## 4. Job Runs

### Submitting a Spark Job
```python
emr_s = boto3.client('emr-serverless')
emr_s.start_job_run(
    applicationId='00abcdef1234567',
    executionRoleArn='arn:aws:iam::123456789012:role/my-emr-role',
    jobDriver={
        'sparkSubmit': {
            'entryPoint': 's3://my-bucket/scripts/etl.py',
            'entryPointArguments': ['--date', '2024-01-01'],
            'sparkSubmitParameters': '--conf spark.executor.cores=2 --conf spark.executor.memory=4g'
        }
    },
    configurationOverrides={
        'monitoringConfiguration': {
            'cloudWatchLoggingConfiguration': {
                'enabled': True,
                'logGroupName': '/aws/emr-serverless/my-app'
            }
        }
    }
)
```

### Three Critical Requirements
1. **executionRoleArn** must be a valid IAM role ARN (>= 20 characters). An empty
   string causes `ValidationException: Invalid length for parameter executionRoleArn`.
2. **cloudWatchLoggingConfiguration.enabled = True** is MANDATORY. Without it, AWS
   rejects with "Missing required parameter".
3. **Application must be STARTED** (or auto_start enabled). Otherwise: "Application
   not in state STARTED".

### Job Run Lifecycle
```
SUBMITTED -> PENDING -> SCHEDULED -> RUNNING -> SUCCESS | FAILED | CANCELLED
```

### Monitoring Job Runs
- CloudWatch Logs: `/aws/emr-serverless/{app-name}`
- Spark UI: `get_dashboard_for_job_run()` returns a pre-signed URL
- CloudWatch Metrics: vCPU usage, memory usage, job duration
- `get_job_run()` returns `totalExecutionDurationSeconds` and `totalResourceUtilization`

---

## 5. Capacity Management

### Pre-Initialized Capacity
Pre-warm workers to reduce cold start latency from minutes to seconds. You
specify worker counts and sizes for Driver and Executor types.

**Cost implication**: Pre-initialized workers incur charges while the application
is in STARTED state, even if no jobs are running. Set to 0 to eliminate idle costs.

Our engine defaults:
- Driver: 1 worker, 1 vCPU, 2 GB memory
- Executor: 1 worker, 1 vCPU, 2 GB memory

### Maximum Capacity
Upper bound on total resources. EMR Serverless will not scale beyond this.

Our engine defaults: 4 vCPU, 8 GB memory, 40 GB disk.

### Dynamic Scaling
EMR Serverless automatically scales within the maximum capacity bounds. No
configuration needed. Workers are added for parallel tasks and released
immediately when done.

### CPU and Memory Constraints
- Supported CPU values: 1, 2, 4, 8, or 16 vCPU
- Memory must be between 2x and 8x the CPU value
- Disk per worker: 20-200 GB

---

## 6. Networking

By default, EMR Serverless runs in AWS-managed networking. To access private
resources (Aurora, Redshift, MSK), configure VPC placement:

```hcl
network_configuration {
  subnet_ids         = ["subnet-abc", "subnet-def"]
  security_group_ids = ["sg-123"]
}
```

**Requirements**:
- Subnets must be private (no auto-assign public IP)
- NAT Gateway or VPC endpoints needed for S3, Glue, CloudWatch access
- Security groups must allow outbound traffic to required services

---

## 7. IAM Roles

### Execution Role
The execution role is assumed by job runs to access data and services. It must
trust `emr-serverless.amazonaws.com` as a principal.

Our renderer creates this role with all permissions computed from the integration
graph (S3 read/write, Glue catalog, DynamoDB, etc.).

### PassRole
Any caller (Lambda, Step Functions) that calls `start_job_run()` needs
`iam:PassRole` permission on the execution role, because it passes the role
ARN to EMR Serverless.

### Common Permission Set
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject", "s3:PutObject", "s3:ListBucket",
    "glue:GetDatabase", "glue:GetTable", "glue:GetPartition",
    "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
  ],
  "Resource": "*"
}
```

---

## 8. Integration Patterns

### Step Functions -> EMR Serverless
Step Functions uses the `startJobRun.sync` optimized integration:
```json
{
  "Type": "Task",
  "Resource": "arn:aws:states:::emr-serverless:startJobRun.sync",
  "Parameters": {
    "ApplicationId.$": "$.application_id",
    "ExecutionRoleArn.$": "$.execution_role_arn",
    "JobDriver": {
      "SparkSubmit": {
        "EntryPoint.$": "$.entry_point"
      }
    }
  }
}
```
The `.sync` suffix makes Step Functions wait for the job to complete.

### Lambda -> EMR Serverless
Lambda calls `start_job_run()` via boto3. The caller needs two environment variables:
- `{PEER_UPPER}_APPLICATION_ID` — the application ID
- `{PEER_UPPER}_EXECUTION_ROLE_ARN` — the execution role ARN

### EMR Serverless -> S3
All Spark/Hive jobs read input from and write output to S3. The execution role
needs S3 read/write permissions.

### EMR Serverless -> Glue Data Catalog
EMR Serverless uses Glue Data Catalog as the default metastore for both Spark
SQL and Hive. The execution role needs Glue read permissions.

---

## 9. Terraform Resources Created by Renderer

The `_render_emr_serverless()` function creates:

1. `aws_iam_role` — Execution role (trust: `emr-serverless.amazonaws.com`)
2. `aws_iam_role_policy` — Inline policy with computed permissions
3. `aws_cloudwatch_log_group` — `/aws/emr-serverless/{resource_name}`
4. `aws_emrserverless_application` — The application with:
   - `initial_capacity` blocks (Driver + Executor)
   - `maximum_capacity` block
   - `auto_start_configuration { enabled = true }`
   - `auto_stop_configuration { enabled = true, idle_timeout_minutes = N }`
   - `architecture`

The renderer emits a prerequisite comment warning about SubscriptionRequiredException.

---

## 10. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Invalid length for parameter executionRoleArn, value: 0` | Empty execution role ARN env var | Set `{SELF_UPPER}_EXECUTION_ROLE_ARN` on calling Lambda |
| `Missing required parameter...cloudWatchLoggingConfiguration...enabled` | Missing monitoring config | Add `cloudWatchLoggingConfiguration.enabled = True` to start_job_run() |
| `SubscriptionRequiredException` | EMR Serverless not enabled | Console -> EMR -> EMR Serverless -> Get started |
| `Application not in state STARTED` | App is STOPPED and auto_start=false | Enable auto_start or call start_application() |
| `AccessDeniedException` | Execution role missing permissions | Add S3/Glue/CloudWatch permissions to execution role |
| `ValidationException capacity` | Exceeds max capacity | Increase maximum_capacity or reduce resource requests |
| `ResourceNotFoundException` | Application deleted | Re-run terraform apply |
| `ServiceQuotaExceededException` | Too many apps or concurrent jobs | Request quota increase |

### Debugging Job Failures
1. Check job state: `get_job_run(applicationId, jobRunId)['jobRun']['stateDetails']`
2. Check CloudWatch Logs: `/aws/emr-serverless/{app-name}`
3. Check Spark UI: `get_dashboard_for_job_run(applicationId, jobRunId)['url']`
4. Check execution role permissions if AccessDenied

---

## 11. Developer Agent: Updating EMR Serverless

### Updating Job Scripts
Scripts live in S3. To update:
1. Find the application: `list_applications()` filter by name
2. Find the latest job run: `list_job_runs(applicationId)`
3. Get the entry point S3 path: `get_job_run()['jobRun']['jobDriver']['sparkSubmit']['entryPoint']`
4. Update the script: `s3.put_object(Bucket, Key, Body=new_script)`
5. Submit a new job run with the same entry point

### Updating Application Config
Use `update_application()` to change:
- `initialCapacity` (pre-warmed workers)
- `maximumCapacity` (resource limits)
- `autoStartConfiguration`
- `autoStopConfiguration`
- `networkConfiguration`

**Cannot change**: application type (SPARK/HIVE), release label, architecture.

---

## 12. Cost Optimization

1. **Disable pre-initialized capacity** if cold start latency is acceptable
2. **Set low maximum capacity** to prevent runaway costs (our default: 4 vCPU / 8 GB)
3. **Enable auto-stop** with short idle timeout (our default: 15 minutes)
4. **Use ARM64** architecture for up to 15% cost savings
5. **Right-size Spark configurations** — avoid over-allocating executor memory
6. **Monitor job resource utilization** via `get_job_run()['totalResourceUtilization']`
7. **Use Spark dynamic allocation** to auto-scale executors within a job
8. **Partition data in S3** to reduce data scanned per job

---

## 13. EMR Serverless vs EMR on EC2 — When to Choose

| Choose EMR Serverless when... | Choose EMR on EC2 when... |
|---|---|
| Batch Spark/Hive jobs | Need HBase, Flink, Presto, or other frameworks |
| Variable workloads (pay per use) | Steady workloads (cheaper at scale) |
| No cluster management desired | Need fine-grained cluster tuning |
| Quick job runs (minutes to hours) | Long-running clusters with notebooks |
| Simple networking needs | Complex multi-tenant security |
