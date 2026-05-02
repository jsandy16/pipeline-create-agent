# Amazon EMR — Complete Knowledge Base

> This document is the plain-English reference for Amazon EMR that the pipeline
> engine framework and developer agent can consult when handling any EMR-related
> request in a pipeline. It covers what EMR is, how clusters work, every feature,
> integration patterns, security, performance, and troubleshooting.

---

## 1. What Is EMR?

Amazon Elastic MapReduce (EMR) is a managed big-data platform that runs open-source
frameworks — Spark, Hive, HBase, Flink, Presto, Hudi, Pig, and more — on
dynamically scalable clusters of EC2 instances. EMR handles provisioning,
configuration, tuning, and optional auto-termination.

### Core Concepts
- **Cluster**: A set of EC2 instances running Hadoop/YARN and configured applications.
- **Step**: A unit of work (a Spark job, Hive query, etc.) submitted to the cluster.
- **Master node**: Runs the cluster manager (YARN ResourceManager, Spark Driver in client mode).
- **Core node**: Runs HDFS DataNodes and YARN NodeManagers. Shrinking core nodes risks data loss.
- **Task node**: Runs only YARN NodeManagers (compute only, no HDFS). Safe to scale up/down.
- **Release label**: The EMR software version (e.g. `emr-6.15.0`) that determines framework versions.
- **Bootstrap action**: Shell script that runs on every node before applications start.
- **Configuration classification**: Application-specific settings (like `spark-defaults`, `hive-site`).

### Free Tier
EMR is **never** free tier. You pay an EMR per-instance-hour fee on top of
EC2 instance charges plus EBS volume and S3 storage costs. The smallest viable
cluster (1 m4.large master + 1 m4.large core) costs approximately $0.27/hour.

---

## 2. Cluster Types

### Transient Clusters
Set `keep_job_flow_alive_when_no_steps = false`. The cluster auto-terminates
after all steps complete. Best for scheduled batch ETL jobs. This is what our
engine defaults to.

### Long-Running Clusters
Set `keep_job_flow_alive_when_no_steps = true`. The cluster stays alive,
waiting for new steps or interactive sessions. Use for ad-hoc queries,
notebooks (Zeppelin/JupyterHub), and streaming workloads.

### Cluster Lifecycle States
`STARTING` -> `BOOTSTRAPPING` -> `RUNNING` -> `WAITING` (if long-running) ->
`TERMINATING` -> `TERMINATED` (or `TERMINATED_WITH_ERRORS`)

---

## 3. Instance Groups vs. Instance Fleets

### Instance Groups
Each group has a single instance type. Simpler to configure. Supports auto-scaling
policies. Three group types: master (always 1), core (at least 1), task (0+).

### Instance Fleets
Each fleet can contain up to 30 instance types. AWS picks the best available
combination, which dramatically improves Spot availability. You specify
`target_on_demand_capacity` and `target_spot_capacity` per fleet.

### Spot Instances
Use EC2 Spot for up to 90% cost savings. Best practices:
- **Never** use Spot for the master node
- Use Spot for task groups (compute-only, no data loss risk)
- Use instance fleets with multiple instance types for better availability
- Set allocation strategy to `capacity-optimized`

---

## 4. Applications

EMR supports many open-source frameworks. The most common:

| Application | Use Case | Submit Method |
|---|---|---|
| **Spark** | In-memory distributed processing | `spark-submit` via `command-runner.jar` |
| **Hive** | SQL-like queries over S3/HDFS data | `hive-script` via `command-runner.jar` |
| **Presto/Trino** | Interactive SQL analytics | Presto CLI or JDBC |
| **HBase** | NoSQL column-family database | HBase shell or API |
| **Flink** | Stream + batch processing | Flink job submission |
| **Hudi** | Data lake management | Included in Spark by default (EMR 6.x) |
| **Zeppelin** | Notebook analytics | Web UI on port 8890 |
| **JupyterHub** | Multi-user notebooks | Web UI on port 9443 |
| **Livy** | REST API for Spark jobs | HTTP API on port 8998 |

Our engine defaults to `["Spark", "Hive"]` unless the user specifies otherwise.

---

## 5. Steps

Steps are the primary way to submit work to a cluster. Each step specifies:
- **Name**: Display name
- **JAR**: Usually `command-runner.jar` (a built-in jar that delegates to spark-submit, hive-script, etc.)
- **Args**: Command-line arguments
- **ActionOnFailure**: What happens if the step fails (`TERMINATE_CLUSTER`, `CANCEL_AND_WAIT`, `CONTINUE`)

### Common Step Patterns

**Spark submit:**
```
Jar: command-runner.jar
Args: ["spark-submit", "--deploy-mode", "cluster", "s3://bucket/script.py"]
```

**Hive query:**
```
Jar: command-runner.jar
Args: ["hive-script", "--run-hive-script", "--args", "-f", "s3://bucket/query.hql"]
```

**S3 distributed copy:**
```
Jar: command-runner.jar
Args: ["s3-dist-cp", "--src", "s3://source/", "--dest", "s3://dest/"]
```

### Step Concurrency
By default, steps run sequentially (`step_concurrency_level = 1`). You can set
up to 256 concurrent steps for long-running clusters.

### Step Lifecycle
`PENDING` -> `RUNNING` -> `COMPLETED` | `FAILED` | `CANCELLED`

---

## 6. Bootstrap Actions

Shell scripts that run on every node (master + core + task) before applications
start. Up to 16 bootstrap actions per cluster.

**Key facts:**
- Run sequentially in the order specified
- Run with root privileges
- If any bootstrap action fails, the cluster terminates with `BOOTSTRAP_FAILURE`
- Common uses: install Python packages, download configs, set environment variables

**Example:**
```bash
#!/bin/bash
sudo pip3 install pandas numpy boto3
aws s3 cp s3://my-bucket/config.ini /etc/app/config.ini
```

---

## 7. Configuration Classifications

Application settings are passed via `configurations_json` in Terraform. Each
configuration has a `Classification` (the config file) and `Properties` (key-value pairs).

The renderer sets these defaults:
- `spark-log4j`: `log4j.rootCategory = INFO,console,CloudWatch`
- `yarn-site`: `yarn.log-aggregation-enable = true`

Common classifications:
- `spark-defaults`: Spark executor memory, cores, dynamic allocation
- `hive-site`: Metastore configuration (Glue Data Catalog integration)
- `emrfs-site`: S3 consistency settings
- `mapred-site`: MapReduce memory settings

To use Glue Data Catalog as the Hive metastore:
```
Classification: hive-site
Property: hive.metastore.client.factory.class
Value: com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory
```

---

## 8. Logging and Monitoring

### S3 Log URI
Every EMR cluster should have a `log_uri` pointing to an S3 bucket. EMR writes:
- Application logs (Spark driver/executor logs)
- Step logs (stdout/stderr per step)
- YARN container logs
- Hadoop daemon logs

Log path structure: `s3://log-uri/cluster-id/steps/step-id/`

### CloudWatch Logs
Our renderer creates a CloudWatch Log Group at `/aws/emr/{resource_name}` and
configures Spark and YARN to forward logs. This enables the Pipeline Run Preview
feature to stream EMR logs in real time.

### CloudWatch Metrics
EMR publishes metrics under the `AWS/ElasticMapReduce` namespace:
- `IsIdle`, `AppsRunning`, `AppsPending`
- `YARNMemoryAvailablePercentage`, `ContainerPendingRatio`
- `CoreNodesPending`, `CoreNodesRunning`

---

## 9. Security

### Encryption at Rest
- **S3 data**: SSE-S3 (free, default), SSE-KMS, or client-side encryption (CSE-KMS)
- **Local disk**: LUKS encryption for EBS volumes and instance store

### Encryption in Transit
TLS encryption for inter-node communication. Requires PEM certificates.

### Kerberos
Authentication for cluster users via Active Directory or MIT KDC.

### Lake Formation
Fine-grained data access control. Requires EMR 5.31+ or 6.1+.

### Security Groups
EMR uses managed security groups for master and core/task nodes. Additional
security groups can be specified for custom network rules. When using private
subnets, a service access security group is required.

---

## 10. Auto-Scaling

### Managed Scaling (Recommended)
EMR automatically scales core and task groups based on workload metrics. Configure:
- `minimum_capacity_units`: Lower bound
- `maximum_capacity_units`: Upper bound
- `maximum_core_capacity_units`: Protect HDFS by capping core scaling
- `unit_type`: `Instances`, `VCPU`, or `InstanceFleetUnits`

### Custom Auto-Scaling (Deprecated)
CloudWatch-based policies on individual instance groups. Use managed scaling instead.

---

## 11. IAM Roles

EMR requires multiple IAM roles:

### EMR Service Role
- Trust principal: `elasticmapreduce.amazonaws.com`
- Purpose: Manage EC2 instances, S3 log access, CloudWatch
- Our renderer creates this as `{resource_label}_role`

### EC2 Instance Profile Role
- Trust principal: `ec2.amazonaws.com`
- Purpose: Let cluster nodes access S3 data, DynamoDB, Glue Catalog, etc.
- Our renderer creates this as `{resource_label}_ec2_role` + `{resource_label}_ec2_profile`
- This role gets the data-access permissions (S3 read/write, DynamoDB, Glue, etc.)

### Auto-Scaling Role
- Trust principal: `elasticmapreduce.amazonaws.com`
- Purpose: Required only for custom auto-scaling (not managed scaling)

### PassRole
Callers (Lambda, Step Functions) that create clusters or add steps need
`iam:PassRole` permission on the EMR service role.

---

## 12. Integration Patterns

### Step Functions -> EMR
Step Functions uses the `addStep.sync` optimized integration:
```json
{
  "Resource": "arn:aws:states:::elasticmapreduce:addStep.sync",
  "Parameters": {
    "ClusterId.$": "$.cluster_id",
    "Step": {
      "Name": "my-step",
      "HadoopJarStep": {
        "Jar": "command-runner.jar",
        "Args.$": "$.step_args"
      }
    }
  }
}
```
The `.sync` suffix makes Step Functions wait for the step to complete.

### Lambda -> EMR
Lambda calls `add_job_flow_steps()` via the boto3 EMR client:
```python
emr = boto3.client('emr')
emr.add_job_flow_steps(
    JobFlowId=os.environ['MY_CLUSTER_CLUSTER_ID'],
    Steps=[{
        'Name': 'process-data',
        'ActionOnFailure': 'CONTINUE',
        'HadoopJarStep': {
            'Jar': 'command-runner.jar',
            'Args': ['spark-submit', 's3://bucket/script.py']
        }
    }]
)
```

### EMR -> S3
EMR reads input data from S3 and writes output/logs. The renderer automatically
sets `log_uri` to the first S3 bucket found in outgoing integrations.

### EMR -> Glue Data Catalog
EMR can use Glue Data Catalog as the Hive metastore via the
`hive-site` configuration classification.

### EMR -> Redshift
EMR can write to Redshift via JDBC (Spark) or the Redshift Data API.

### EMR -> Aurora
EMR connects to Aurora via JDBC, requiring VPC placement in the same VPC.

### EMR -> Kinesis / MSK
EMR processes streaming data via Spark Structured Streaming with Kinesis
or Kafka connectors.

---

## 13. Terraform Resources Created by Renderer

The `_render_emr()` function creates these resources:

1. `aws_cloudwatch_log_group` — `/aws/emr/{resource_name}`
2. `aws_iam_role` — Service role (trust: `elasticmapreduce.amazonaws.com`)
3. `aws_iam_role_policy` — Inline policy with computed IAM permissions
4. `aws_iam_role` — EC2 instance profile role (trust: `ec2.amazonaws.com`)
5. `aws_iam_instance_profile` — Instance profile referencing the EC2 role
6. `aws_emr_cluster` — The cluster itself with:
   - `master_instance_group` block
   - `core_instance_group` block
   - `ec2_attributes.instance_profile`
   - `log_uri` (S3 bucket from integrations or placeholder)
   - `configurations_json` (spark-log4j + yarn-site defaults)

---

## 14. Common Errors and Troubleshooting

| Error Pattern | Cause | Fix |
|---|---|---|
| `BOOTSTRAP_FAILURE` | Bootstrap script failed | Check script at S3 path. View logs at `LogUri/cluster-id/node/` |
| `FAILED step` | Step execution error | Check `s3://log-uri/cluster-id/steps/step-id/stderr` |
| `TERMINATED_WITH_ERRORS` | Cluster-level failure | `describe_cluster()['Cluster']['Status']['StateChangeReason']` |
| `InsufficientInstanceCapacity` | No EC2 capacity in AZ | Try different instance type or AZ. Use instance fleets. |
| `AccessDeniedException` | Missing IAM permissions | Check both service role and EC2 instance profile role |
| `InvalidRequestException subnet` | Bad subnet config | Verify subnet exists and has DNS hostnames enabled |
| `EC2 QUOTA` | Instance limit reached | Request quota increase via Service Quotas console |

### Debugging Steps
1. Check cluster state: `describe_cluster(ClusterId=id)['Cluster']['Status']`
2. Check step logs: `list_steps(ClusterId=id)` then check S3 log path
3. Check bootstrap logs: `s3://log-uri/cluster-id/node/master-instance-id/`
4. Check YARN logs: `s3://log-uri/cluster-id/containers/`

---

## 15. Developer Agent: Updating EMR

EMR scripts live in S3. To update:
1. Find the cluster: `list_clusters(ClusterStates=['WAITING','RUNNING'])`
2. Get the cluster ID matching the resource name
3. Update the script in S3 via `s3.put_object()`
4. Submit a new step with the updated script path

**Important**: You cannot modify an existing step. You must submit a new step
with the corrected script.

### Config Changes
- Cannot change release label, applications, or instance types on a running cluster
- Can modify instance group sizes via `modify_instance_groups()`
- Can add task instance groups via `add_instance_groups()`
- Can enable/disable termination protection via `set_termination_protection()`

---

## 16. Cost Optimization

1. **Use transient clusters** for batch jobs (auto-terminate after completion)
2. **Use Spot instances** for task groups (up to 90% savings)
3. **Use instance fleets** for better Spot availability
4. **Right-size instances** — start small (m4.large) and scale up only if needed
5. **Enable managed scaling** to auto-scale based on workload
6. **Set auto-termination policies** on long-running clusters
7. **Use S3** instead of HDFS for data persistence (no core node storage costs)
8. **Monitor** `YARNMemoryAvailablePercentage` to detect over/under-provisioning
