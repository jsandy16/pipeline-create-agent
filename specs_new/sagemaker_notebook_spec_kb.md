# Amazon SageMaker Notebook Instance — Complete Knowledge Base

> This document is the plain-English reference for SageMaker Notebook Instances
> that the pipeline engine framework and developer agent can consult when
> handling any notebook-related request in a pipeline. It covers what notebook
> instances are, how they work, configuration options, integration patterns,
> and troubleshooting.

---

## 1. What Is a SageMaker Notebook Instance?

A SageMaker Notebook Instance is a managed Jupyter notebook server running on
a dedicated ML compute instance. It provides a browser-based environment for
interactive data exploration, visualization, ML experimentation, and
prototyping.

### Core Concepts
- **Notebook Instance**: A managed EC2-like compute instance running JupyterLab
  and the classic Jupyter Notebook interface
- **Execution Role**: IAM role assumed by the notebook, controlling what AWS
  services the notebook can access
- **EBS Volume**: Persistent storage mounted at `/home/ec2-user/SageMaker`
- **Lifecycle Configuration**: Shell scripts that run at creation and/or start

### What Makes It Different from SageMaker Endpoints
A notebook instance is an **interactive** resource for human users. It does not
serve inference requests. It is the simplest SageMaker resource: just an IAM
role and a compute instance. No model, no endpoint, no container image required.

### Cost Warning — NEVER Free Tier
SageMaker Notebook Instances are **never** in the permanent AWS Free Tier.
There was a limited 2-month trial (250 hours/month of ml.t2.medium) for new
accounts. After that, ml.t2.medium costs approximately $0.046/hour (~$33/month
continuously). **Always stop instances when not in use.**

---

## 2. How Our Pipeline Engine Renders Notebook Instances

The renderer (`_render_sagemaker_notebook`) creates these Terraform resources:

1. **IAM execution role** — assumed by `sagemaker.amazonaws.com`, with an
   inline policy for computed permissions based on integrations.
2. **Notebook instance** — with configured instance type, volume size, and
   internet access setting.
3. **Security group** (conditional) — only when `vpc_required` is true, with
   egress to 0.0.0.0/0.

### Name Length Safety
Notebook instance names are capped at 63 characters using `suffixed_name()`.

### VPC Behavior
When `vpc_required` is true (triggered by integrations with Redshift, Aurora,
or RDS), the renderer:
1. Creates a security group allowing all egress
2. Sets `subnet_id` from `data.aws_subnets.default`
3. Sets `direct_internet_access = "Disabled"`
4. Attaches the security group

When not in VPC, `direct_internet_access` uses the config value (default: "Enabled").

**Note**: The renderer does NOT set `platform_identifier` because it is not
supported in all regions. AWS defaults to the latest platform automatically.

---

## 3. Instance Lifecycle

```
Pending (3-5 min) → InService → Stopping → Stopped → InService (restart)
                  ↘ Failed                         ↘ Deleting → Deleted
```

### States
| State | Description | Billing |
|---|---|---|
| Pending | Being created | No |
| InService | Running, accessible | **Yes** |
| Stopping | Shutting down | Yes (briefly) |
| Stopped | EBS preserved, no compute | **No compute** (EBS storage charged) |
| Failed | Creation or start failed | No |
| Updating | Config being changed | No |

### Key Behavior
- **Stop/Start**: EBS data at `/home/ec2-user/SageMaker` is preserved across
  stop/start cycles. The root volume (OS, packages) is NOT preserved — any
  system-level packages installed outside a lifecycle config will be lost.
- **Delete**: ALL data is permanently lost. Always save important work to S3 or
  Git before deleting.
- **Update**: Instance must be in the Stopped state before you can update
  instance type, volume size, lifecycle config, or role ARN.

---

## 4. Access Methods

### JupyterLab (Recommended)
The default interface. Access via the SageMaker console or presigned URL.
Modern tabbed interface with file browser, terminal, and notebook editor.

### Classic Jupyter Notebook
Legacy interface accessible at `/tree` path. Still supported.

### Terminal
Full Linux terminal access via JupyterLab: New > Terminal.

### Presigned URL
Generate a one-time browser URL for programmatic access:
```python
sm = boto3.client('sagemaker')
url = sm.create_presigned_notebook_instance_url(
    NotebookInstanceName='my-notebook'
)['AuthorizedUrl']
# URL valid for 5 minutes, session lasts until tab closed
```

---

## 5. Pre-Installed Software

Notebook instances come pre-installed with:

### ML Frameworks
TensorFlow, PyTorch, Apache MXNet, scikit-learn, XGBoost, Keras

### Data Tools
pandas, NumPy, SciPy, matplotlib, seaborn, Bokeh

### AWS Tools
boto3, AWS CLI, SageMaker Python SDK, s3fs

### Kernels
- Python 3 (conda_python3)
- TensorFlow (conda_tensorflow2_p310)
- PyTorch (conda_pytorch_p310)
- MXNet (conda_mxnet_p38)
- R

### Package Installation
Users can install additional packages:
```bash
# In a notebook cell or terminal
pip install my-package
conda install -c conda-forge my-package

# System packages (requires root access enabled)
sudo yum install -y my-system-package
```

---

## 6. Storage

### EBS Volume
- Mount point: `/home/ec2-user/SageMaker`
- Default size: 5 GB
- Min: 5 GB, Max: 16,384 GB (16 TB)
- Type: gp2 (General Purpose SSD)
- **Persists across stop/start** — data is safe when you stop the instance
- **Lost on delete** — permanently gone when you delete the instance
- Can only be **increased**, never decreased
- Resize requires stopping the instance first

### Root Volume
- Size: 20 GB (fixed, not configurable)
- Contains OS and pre-installed packages
- **NOT preserved across stops** — reinstall custom system packages via
  lifecycle config

### External Storage Options
- **S3**: Use `boto3` or `s3fs` for reading/writing. Best for sharing data.
- **EFS**: Mount via lifecycle config script for shared persistent storage.
- **FSx for Lustre**: Mount for high-throughput ML workloads.

---

## 7. Lifecycle Configurations

Shell scripts that automate notebook setup. Two trigger points:

### On Create (runs once)
Executes when the instance is first created. Use for one-time setup:
- Install conda environments
- Clone Git repositories
- Install system packages
- Configure Jupyter extensions

### On Start (runs every start)
Executes every time the instance starts (including after stop/start). Use for:
- Activate conda environments
- Pull latest from Git repos
- Set environment variables
- Start auto-stop scripts

### Constraints
- Max script size: 16 KB
- Runs as root
- Timeout: 5 minutes (instance fails if script takes longer)
- Scripts must be base64 encoded when using the API

### Auto-Stop Pattern
The most common lifecycle config installs an idle auto-stop script:
```bash
#!/bin/bash
# On-start script: auto-stop after 1 hour of inactivity
IDLE_TIME=3600
nohup python /home/ec2-user/autostop.py --time $IDLE_TIME &
```
This saves significant cost by stopping idle notebooks automatically.

---

## 8. Git Repository Integration

Notebook instances can be linked to Git repositories:
- **1 default repository**: Cloned to `/home/ec2-user/SageMaker` on creation
- **Up to 2 additional repositories**: Also cloned to SageMaker directory
- Supports CodeCommit, GitHub, GitLab, Bitbucket

For private repos, store credentials in AWS Secrets Manager and reference via
`aws_sagemaker_code_repository`.

---

## 9. Instance Types

| Instance | vCPU | RAM | GPU | Cost/hr | Use Case |
|---|---|---|---|---|---|
| ml.t2.medium | 2 | 4 GB | 0 | $0.046 | Light exploration (default) |
| ml.t3.medium | 2 | 4 GB | 0 | $0.046 | Better networking |
| ml.t3.large | 2 | 8 GB | 0 | $0.093 | Medium datasets |
| ml.m5.xlarge | 4 | 16 GB | 0 | $0.269 | Larger datasets |
| ml.c5.xlarge | 4 | 8 GB | 0 | $0.238 | CPU-intensive |
| ml.g4dn.xlarge | 4 | 16 GB | 1 T4 | $0.736 | GPU experimentation |
| ml.p3.2xlarge | 8 | 61 GB | 1 V100 | $4.284 | Heavy GPU work |

**Recommendation**: Start with ml.t2.medium. Upgrade only when needed. Always
stop the instance when not actively using it.

---

## 10. VPC Configuration

### When VPC Is Needed
Our pipeline engine auto-places notebooks in a VPC when they integrate with:
- **Redshift** — cluster lives in VPC
- **Aurora** — cluster lives in VPC
- **RDS** — database lives in VPC

### VPC Requirements
When in a VPC with `direct_internet_access = "Disabled"`:
- **NAT Gateway** or **VPC endpoints** are needed for:
  - S3 access (Gateway endpoint)
  - SageMaker API (Interface endpoint)
  - ECR for package installation (Interface endpoint)
  - PyPI/Conda for package installation (NAT Gateway)

### Without VPC
Default behavior: `direct_internet_access = "Enabled"`. Full internet access
for installing packages, accessing APIs, etc.

---

## 11. IAM Permissions

### Execution Role
The notebook's execution role is assumed by `sagemaker.amazonaws.com`. It
controls what AWS services the notebook code can access.

### Always Required
```
logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents
sagemaker:DescribeNotebookInstance, sagemaker:ListTags
```

### Integration-Based Permissions
These are computed from the pipeline's integration graph:

| Integration | Permissions Added |
|---|---|
| Notebook -> S3 | s3:GetObject, PutObject, ListBucket, DeleteObject |
| Notebook -> Athena | athena:StartQueryExecution, GetQueryResults + glue:GetTable |
| Notebook -> DynamoDB | dynamodb:GetItem, PutItem, Query, Scan, BatchGetItem |
| Notebook -> Redshift | redshift:GetClusterCredentials, redshift-data:ExecuteStatement |
| Notebook -> Aurora | rds-data:ExecuteStatement, secretsmanager:GetSecretValue |
| Notebook -> Glue Catalog | glue:GetTable, GetDatabase, GetPartitions |
| Notebook -> SageMaker endpoint | sagemaker:InvokeEndpoint, DescribeEndpoint |
| Notebook -> Lambda | lambda:InvokeFunction |
| Notebook -> Step Functions | states:StartExecution, DescribeExecution |
| S3 -> Notebook | s3:GetObject, ListBucket |

---

## 12. Encryption

### EBS Volume Encryption
- Optional KMS key via `kms_key_id` Terraform attribute
- Default: AWS managed key (aws/sagemaker)
- Can only be set at creation time

### In Transit
All connections use HTTPS. Jupyter interface is always accessed over TLS.

### Root Access
- Can be disabled to prevent `sudo` access
- When disabled, users can still install packages in conda environments
- Terraform attribute: `root_access = "Enabled"` or `"Disabled"`

---

## 13. Updating a Notebook Instance

The update workflow requires stopping first:

1. `sm.stop_notebook_instance(NotebookInstanceName='my-notebook')`
2. Poll `describe_notebook_instance` until status is `Stopped`
3. `sm.update_notebook_instance(NotebookInstanceName='my-notebook', InstanceType='ml.m5.xlarge')`
4. `sm.start_notebook_instance(NotebookInstanceName='my-notebook')`
5. Poll until status is `InService`

### What Can Be Updated
- Instance type
- IAM role ARN
- Lifecycle configuration
- Volume size (increase only)
- Default code repository
- Additional code repositories
- Root access setting

---

## 14. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `NotebookInstance Failed` | Lifecycle config script errored | Check `/aws/sagemaker/NotebookInstances/<name>/LifecycleConfig` logs |
| `Lifecycle config timed out` | Script took > 5 minutes | Optimize script, use background processes |
| `ResourceLimitExceeded` | Too many notebook instances | Delete unused instances, request quota increase |
| `Instance type not available` | Not supported in region | Use ml.t2.medium |
| `Volume size cannot be decreased` | Tried to shrink EBS | Volume can only grow; create new instance for smaller |
| `AccessDeniedException` | Missing IAM permissions | Check execution role permissions |
| `NotebookInstanceNotFound` | Instance doesn't exist | Check terraform apply, re-deploy |

---

## 15. Integration Patterns in Our Pipeline Engine

### Notebook as Data Explorer
The most common pattern: notebook instance reads data from S3, queries Athena
or databases, and writes results back to S3.

### Notebook as ML Experimenter
Notebook trains models locally or submits SageMaker training jobs, evaluates
results, and saves model artifacts to S3 for later deployment.

### Notebook with Databases (VPC)
When the pipeline connects a notebook to Redshift or Aurora, the renderer
auto-places the notebook in a VPC with a security group.

---

## 16. Terraform Resources Created by Our Renderer

### Always Created
1. `aws_iam_role` — execution role for sagemaker.amazonaws.com
2. `aws_iam_role_policy` — inline policy with integration-based permissions
3. `aws_sagemaker_notebook_instance` — the notebook instance

### Conditionally Created
- `aws_security_group` — when VPC is required (Redshift/Aurora/RDS integration)

### Available but Not in Default Renderer
- `aws_sagemaker_notebook_instance_lifecycle_configuration`
- `aws_sagemaker_code_repository`

---

## 17. Monitoring

### CloudWatch Logs
- Instance logs: `/aws/sagemaker/NotebookInstances/{instance_name}`
- Lifecycle config logs: `/aws/sagemaker/NotebookInstances/{instance_name}/LifecycleConfig`

### Pipeline Run Monitor
Notebook instances are NOT monitored by the pipeline run log aggregator. They
are interactive resources, not pipeline execution resources. They fall under
the "metadata-only / no monitoring" category.

---

## 18. Cost Optimization Tips

1. **Always stop when not in use** — you pay per second while InService
2. **Use auto-stop lifecycle config** — auto-stops after idle timeout
3. **Start with ml.t2.medium** — cheapest instance, upgrade only when needed
4. **Use spot instances** for notebooks via SageMaker Studio (not classic instances)
5. **Minimize EBS volume size** — 5 GB is sufficient for most exploration
6. **Delete unused instances** — stopped instances still incur EBS charges
7. **Use S3 for large datasets** — stream from S3 instead of copying to EBS

---

## 19. SageMaker Notebook vs. SageMaker Studio

| Feature | Notebook Instance | SageMaker Studio |
|---|---|---|
| Interface | JupyterLab / Classic Jupyter | JupyterLab (customized) |
| Compute | Fixed instance | Dynamic compute (switch types without restart) |
| Storage | EBS per instance | EFS (shared across instances) |
| Collaboration | Not shared | Shared via domain |
| Cost | Per-instance-hour | Per-instance-hour + domain cost |
| Terraform | `aws_sagemaker_notebook_instance` | `aws_sagemaker_domain` + `aws_sagemaker_user_profile` |
| Our renderer | Supported | Not supported (use notebook instance) |

Our pipeline engine creates classic notebook instances, not SageMaker Studio.
