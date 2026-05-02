# Amazon SageMaker — Complete Knowledge Base

> This document is the plain-English reference for SageMaker that the pipeline
> engine framework and developer agent can consult when handling any
> SageMaker-related request in a pipeline. It covers what SageMaker is, how it
> works, every feature, integration patterns, security, performance, and
> troubleshooting — written for an agent that needs to reason about SageMaker
> in context, not just look up API parameters.

---

## 1. What Is SageMaker?

Amazon SageMaker is a fully managed machine learning platform. It covers the
entire ML lifecycle: data labeling, feature engineering, training, tuning,
deploying, and monitoring models. For our pipeline engine, SageMaker is
primarily used as a **real-time inference endpoint** — a running ML model that
accepts requests and returns predictions.

### Core Concepts
- **Model**: A definition linking a container image (with ML framework code) to
  model artifacts in S3 (the serialized trained model). Not a running resource.
- **Endpoint Configuration**: Specifies which model(s) to deploy, what instance
  type, how many instances, and traffic routing weights.
- **Endpoint**: The actual running deployment. Provisions EC2-like ML instances,
  loads the model container, and serves inference requests via HTTPS.
- **Training Job**: A temporary compute cluster that runs training code, reads
  data from S3, and writes model artifacts back to S3.
- **Processing Job**: A temporary compute cluster for data processing, feature
  engineering, or model evaluation.
- **Batch Transform**: Offline batch inference — reads a dataset from S3, runs
  predictions, writes results to S3.

### Cost Warning — NEVER Free Tier
SageMaker endpoints are **never** in the AWS Free Tier. The cheapest inference
instance (ml.t2.medium) costs approximately $0.065/hour (~$47/month if running
continuously). Training jobs are billed per second with a 1-minute minimum.
Always use ml.t2.medium as the default to minimize cost.

---

## 2. How Our Pipeline Engine Renders SageMaker

The renderer (`_render_sagemaker`) creates these Terraform resources:

1. **IAM execution role** — assumed by `sagemaker.amazonaws.com`, with an
   inline policy for computed permissions plus `AmazonSageMakerFullAccess`
   managed policy attached.
2. **Pre-built ECR image data source** (default) — uses
   `aws_sagemaker_prebuilt_ecr_image` to resolve the correct DLC image URI for
   the account and region. Avoids the common ECR permission error.
3. **Placeholder model artifact** (when S3 integration exists) — uploads a
   minimal `model.tar.gz` via `aws_s3_object` so `terraform apply` succeeds
   without manual pre-upload.
4. **CloudWatch log group** — `/aws/sagemaker/Endpoints/{endpoint_name}` with
   7-day retention.
5. **SageMaker model** — links the container image to the model artifacts.
6. **Endpoint configuration** — specifies instance type, count, and variant.
7. **SageMaker endpoint** — the running inference endpoint.

### Name Length Safety
All SageMaker names are capped at 63 characters using `suffixed_name()`:
- Model name: `resource_name + "-model"` (limit 63)
- Config name: `resource_name + "-cfg"` (limit 63)
- Endpoint name: `resource_name` (limit 63)

---

## 3. Container Images

### Default Path (Recommended)
Leave `container_image` unset. The renderer uses the
`aws_sagemaker_prebuilt_ecr_image` Terraform data source with `framework` and
`image_tag` config values. This resolves the correct Deep Learning Container
(DLC) registry URI for your AWS account and region automatically.

**Why this matters**: Hardcoding the DLC registry URI
(`763104351884.dkr.ecr.*.amazonaws.com`) causes the error "does not grant
permission to sagemaker.amazonaws.com service principal." The data source
avoids this entirely.

### Supported Frameworks

| Framework | repository_name | Example Tag |
|---|---|---|
| Scikit-learn | `sagemaker-scikit-learn` | `1.2-1-cpu-py3` |
| XGBoost | `sagemaker-xgboost` | `1.7-1` |
| PyTorch (inference) | `pytorch-inference` | `2.1.0-cpu-py310` |
| PyTorch (training) | `pytorch-training` | `2.1.0-gpu-py310-cu121` |
| TensorFlow (inference) | `tensorflow-inference` | `2.13.0-cpu` |
| TensorFlow (training) | `tensorflow-training` | `2.13.0-gpu` |
| HuggingFace PyTorch | `huggingface-pytorch-inference` | `2.0.0-transformers4.28.1-cpu-py310` |
| MXNet | `mxnet-inference` | `1.9.0-cpu-py38` |

### Custom Image Path
Set `container_image` to a fully-qualified ECR URI from your own repository.
You must add an `aws_ecr_repository_policy` granting `sagemaker.amazonaws.com`
the actions: `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`,
`ecr:BatchCheckLayerAvailability`.

---

## 4. Model Artifacts

Model artifacts are stored as `model.tar.gz` in S3 — a gzipped tar archive
containing the serialized model files specific to your framework.

### Artifact Contents by Framework
- **Scikit-learn**: `model.pkl` or `model.joblib`
- **XGBoost**: `xgboost-model`
- **PyTorch**: `model.pth` + `code/inference.py`
- **TensorFlow**: `SavedModel` directory structure (`saved_model.pb` + variables/)
- **HuggingFace**: `config.json` + `pytorch_model.bin` + tokenizer files

### S3 Integration Auto-Resolution
When the pipeline declares an S3 -> SageMaker integration, the renderer
automatically:
1. Sets `model_data_url` to `s3://${aws_s3_bucket.LABEL.id}/model.tar.gz`
2. Creates an `aws_s3_object` resource uploading a placeholder `model.tar.gz`
3. Adds `depends_on` to the SageMaker model resource

The user should replace the placeholder with a real trained model after
deployment.

---

## 5. Real-Time Endpoints

### Endpoint Lifecycle
```
Creating (5-15 min) → InService → Updating → InService
                   ↘ Failed     ↗ RollingBack
```

An endpoint provisions ML instances (like EC2), downloads the model container
from ECR, loads model artifacts from S3, and starts serving requests.

### Production Variants
An endpoint configuration can have multiple variants for A/B testing or canary
deployments:
- Each variant has a `variant_name`, `model_name`, `instance_type`,
  `initial_instance_count`, and `initial_variant_weight`
- Traffic is distributed proportionally by weight
- Our renderer creates a single "primary" variant by default

### Invoking an Endpoint
```python
runtime = boto3.client('sagemaker-runtime')
response = runtime.invoke_endpoint(
    EndpointName='my-endpoint',
    Body=json.dumps({"features": [1.0, 2.0, 3.0]}),
    ContentType='application/json'
)
prediction = json.loads(response['Body'].read())
```

### Autoscaling
SageMaker endpoints can autoscale using Application Auto Scaling:
- Target: `sagemaker:variant:DesiredInstanceCount`
- Common metric: `SageMakerVariantInvocationsPerInstance`
- Terraform: `aws_appautoscaling_target` + `aws_appautoscaling_policy`

### Serverless Inference
For intermittent traffic, use serverless inference (auto-scales to zero):
- Memory: 1024–6144 MB
- Max concurrency: 1–200
- No instance management needed
- Cold start latency of seconds

### Data Capture
Log inference inputs/outputs to S3 for model monitoring:
- Capture modes: Input, Output, or both
- Sampling: 1–100%
- Output format: JSON Lines in S3

---

## 6. Training Jobs

Training jobs are temporary — SageMaker provisions a cluster, runs your
training code, and shuts down automatically.

### Training Flow
1. Upload training data to S3
2. Call `create_training_job` with algorithm spec, input channels, resources
3. SageMaker provisions cluster, pulls container, downloads data
4. Training runs (logs go to CloudWatch `/aws/sagemaker/TrainingJobs`)
5. Model artifacts written to `OutputDataConfig.S3OutputPath`
6. Cluster terminated automatically

### Input Modes
- **File**: Downloads all data from S3 to local EBS before training starts.
  Best for small datasets.
- **Pipe**: Streams data from S3 during training. Best for large datasets.
- **FastFile**: POSIX-compatible streaming (recommended for most cases).

### Spot Training
Use managed spot instances for up to 90% cost savings:
- Set `enable_managed_spot_training = true`
- Set `max_wait_time` (how long to wait for spot capacity)
- Optionally set `checkpoint_s3_uri` for interruption recovery

### Distributed Training
- **Data parallel**: Split training data across instances (each has full model)
- **Model parallel**: Split large model across instances (for models > GPU memory)
- Requires framework support (PyTorch DDP, TensorFlow MirroredStrategy)

### Hyperparameter Tuning
Automatic model tuning runs multiple training jobs with different
hyperparameter combinations:
- Strategies: Bayesian, Random, Hyperband, Grid
- Up to 500 training jobs per tuning job
- Up to 10 parallel training jobs

---

## 7. Processing Jobs

Processing jobs run arbitrary data processing scripts on managed compute. Not
tied to training or inference — use for ETL, feature engineering, evaluation.

### Inputs/Outputs
- Inputs mapped to `/opt/ml/processing/input/INPUT_NAME`
- Outputs from `/opt/ml/processing/output/OUTPUT_NAME` uploaded to S3
- S3 upload mode: EndOfJob (default) or Continuous

### Common Use Cases
- Data preprocessing and feature engineering
- Model evaluation (compute accuracy, precision, recall on test set)
- Data quality checks
- Bias and explainability reports (SageMaker Clarify)

---

## 8. Batch Transform

Offline batch inference for large datasets:

1. Create a SageMaker model (same as for endpoints)
2. Call `create_transform_job` with input S3 path, output S3 path, resources
3. SageMaker provisions instances, loads model, processes all records
4. Predictions written to output S3 path
5. Instances terminated automatically

### Batch Strategies
- **MultiRecord**: Pack multiple records per inference request (faster)
- **SingleRecord**: One record per request (safer for large records)

### When to Use
- One-time predictions on a large dataset
- Periodic batch scoring (daily, weekly)
- When real-time latency is not required

---

## 9. Instance Types

### Inference (Endpoint) — Common Choices

| Instance | vCPU | RAM | GPU | Cost/hr | Use Case |
|---|---|---|---|---|---|
| ml.t2.medium | 2 | 4 GB | 0 | $0.065 | Dev/test, cheapest |
| ml.m5.large | 2 | 8 GB | 0 | $0.134 | Small production |
| ml.c5.xlarge | 4 | 8 GB | 0 | $0.238 | CPU-intensive |
| ml.g4dn.xlarge | 4 | 16 GB | 1 T4 | $0.736 | Best-value GPU |
| ml.inf1.xlarge | 4 | 8 GB | 1 Inf1 | $0.297 | AWS Inferentia |
| ml.p3.2xlarge | 8 | 61 GB | 1 V100 | $4.284 | High-end GPU |

### Training — Common Choices
Same families plus larger sizes. Most common:
- **ml.m5.xlarge**: General-purpose CPU training
- **ml.p3.2xlarge**: GPU training (V100)
- **ml.g4dn.xlarge**: Cost-effective GPU training (T4)

---

## 10. IAM Permissions

### Execution Role
SageMaker resources need an execution role assumed by
`sagemaker.amazonaws.com`. Our renderer creates this role with:
- An inline policy containing computed permissions from the integration graph
- `AmazonSageMakerFullAccess` managed policy for ECR, CloudWatch, etc.

### Always-Required Permissions
```
logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents
ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability
ecr:GetDownloadUrlForLayer, ecr:BatchGetImage
s3:GetObject, s3:ListBucket, s3:GetBucketLocation
cloudwatch:PutMetricData, cloudwatch:GetMetricStatistics
```

### Integration Permissions

**When S3 provides model artifacts (S3 -> SageMaker)**:
`s3:GetObject`, `s3:ListBucket`, `s3:GetBucketLocation`, `s3:GetObjectVersion`

**When Step Functions orchestrates SageMaker**:
`sagemaker:CreateTrainingJob`, `sagemaker:DescribeTrainingJob`,
`sagemaker:CreateProcessingJob`, `sagemaker:CreateTransformJob`, etc.

**When Lambda invokes the endpoint**:
`sagemaker:InvokeEndpoint`

**When SageMaker writes to S3**:
`s3:PutObject`, `s3:GetObject`, `s3:ListBucket`,
`s3:AbortMultipartUpload`, `s3:ListMultipartUploadParts`

**When SageMaker writes to DynamoDB**:
`dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:UpdateItem`,
`dynamodb:Query`, `dynamodb:BatchWriteItem`

---

## 11. Encryption

### In Transit
All SageMaker API calls and endpoint invocations use HTTPS/TLS. Enforced by
default, cannot be disabled.

### At Rest
- **Model artifacts in S3**: Encrypted using the bucket's server-side
  encryption setting (SSE-S3, SSE-KMS, or SSE-C)
- **Training volumes**: EBS volume encryption with optional KMS key
  (`volume_kms_key_id`)
- **Endpoint storage**: EBS encryption with optional KMS key (`kms_key_arn`)

### Inter-Container Traffic Encryption
For distributed training, enable `enable_inter_container_traffic_encryption`
to encrypt data between containers. This adds overhead but is required for
compliance workloads.

---

## 12. VPC Configuration

SageMaker endpoints and training jobs can run inside a VPC for network
isolation. Our pipeline engine auto-triggers VPC placement when SageMaker
integrates with:
- **Aurora** (database in VPC)
- **Redshift** (cluster in VPC)

### VPC Requirements
- At least 2 subnets in different AZs
- Security group allowing SageMaker to reach S3 (via VPC endpoint or NAT)
- Security group allowing SageMaker to reach ECR (for image pull)
- Additional EC2 network interface permissions added automatically by spec_builder

### Network Isolation
Setting `enable_network_isolation = true` prevents the container from making
any outbound network calls. The container can only access data in S3 via the
model artifacts pre-downloaded to the instance.

---

## 13. SageMaker Pipelines

SageMaker Pipelines is a native ML workflow orchestration service (alternative
to Step Functions for ML-specific workflows):

### Step Types
- **TrainingStep**: Run a training job
- **ProcessingStep**: Run a processing job
- **TransformStep**: Run batch transform
- **CreateModelStep**: Register a model
- **RegisterModel**: Add model to Model Registry
- **ConditionStep**: Branch based on conditions
- **CallbackStep**: Wait for external callback
- **LambdaStep**: Invoke a Lambda function
- **QualityCheckStep**: Model quality monitoring
- **ClarifyCheckStep**: Bias and explainability
- **FailStep**: Fail the pipeline

### Limits
- Max 50 steps per pipeline
- Max 256-character pipeline name
- Parameters can be strings, integers, floats, or booleans

---

## 14. Feature Store

A centralized repository for ML features:
- **Online store**: DynamoDB-backed, low-latency reads for real-time inference
- **Offline store**: S3-backed, for batch training data
- **Feature group**: A logical grouping of features with a schema

---

## 15. Model Registry

Central catalog for managing model versions:
- **Model Package Group**: Named group (e.g., "fraud-detection-model")
- **Model Package**: A specific version with metadata, metrics, and S3 artifacts
- **Approval statuses**: PendingManualApproval, Approved, Rejected
- Only approved models can be deployed to endpoints

---

## 16. Updating a Deployed Model (Zero-Downtime)

SageMaker supports zero-downtime rolling updates:

1. Upload new `model.tar.gz` to S3
2. Create a new model: `sm.create_model(ModelName='v2', ...)`
3. Create a new endpoint config: `sm.create_endpoint_config(EndpointConfigName='v2-config', ...)`
4. Update the endpoint: `sm.update_endpoint(EndpointName='my-endpoint', EndpointConfigName='v2-config')`
5. Poll `sm.describe_endpoint()` until status is `InService`

The old instances are replaced gradually — no downtime during the switch.

---

## 17. Integration Patterns in Our Pipeline Engine

### S3 -> SageMaker (Model Artifacts)
S3 provides model artifacts. The SageMaker renderer auto-resolves the S3 bucket
and creates a placeholder model upload.

### Lambda -> SageMaker (Endpoint Invocation)
Lambda calls `invoke_endpoint()`. The env var `{SERVICE_UPPER}_ENDPOINT_NAME`
is auto-wired. Lambda needs `sagemaker:InvokeEndpoint` permission.

### Step Functions -> SageMaker (Job Orchestration)
Step Functions creates training, processing, or transform jobs. The Step Functions
execution role needs SageMaker job management permissions.

### SageMaker -> S3 (Output)
SageMaker writes training output, batch predictions, and processed data to S3.

### SageMaker -> DynamoDB (Results)
SageMaker writes inference results to DynamoDB for low-latency lookups.

### SageMaker -> SNS/SQS/Kinesis (Notifications/Streaming)
SageMaker publishes results to messaging services.

---

## 18. Monitoring

### CloudWatch Log Groups
- Endpoints: `/aws/sagemaker/Endpoints/{endpoint_name}`
- Training jobs: `/aws/sagemaker/TrainingJobs`
- Processing jobs: `/aws/sagemaker/ProcessingJobs`
- Transform jobs: `/aws/sagemaker/TransformJobs`

### CloudWatch Metrics (AWS/SageMaker namespace)
- `Invocations`: Total inference requests
- `InvocationModelErrors`: Errors from the model container
- `ModelLatency`: Time the model takes to respond (ms)
- `OverheadLatency`: SageMaker overhead (ms)
- `Invocation4XXErrors`, `Invocation5XXErrors`
- `CPUUtilization`, `MemoryUtilization`, `GPUUtilization`

### Pipeline Run Monitor
The log aggregator uses CloudWatch Logs at
`/aws/sagemaker/Endpoints/{resource_name}` for real-time monitoring (3-second
polling).

---

## 19. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `EndpointNotFound` | Endpoint not deployed or still creating | Check `describe_endpoint` status, wait for InService |
| `ModelError` / `ModelNotReady` | Container crashed or returned error | Check `/aws/sagemaker/Endpoints/<name>` logs |
| `does not grant permission to sagemaker.amazonaws.com` | ECR permission issue | Use `aws_sagemaker_prebuilt_ecr_image` data source |
| `Could not assume role` | Trust policy wrong | Check IAM role trust allows `sagemaker.amazonaws.com` |
| `Could not find model data` | model.tar.gz missing from S3 | Upload model artifacts to the S3 URI |
| `ResourceLimitExceeded` | Service quota hit | Request increase, delete unused resources |
| `ValidationException...instance type` | Instance type not available | Use ml.t2.medium or check regional availability |
| `ThrottlingException` | Too many API calls | Exponential backoff, use batch transform for bulk |
| `InternalServerError` | Container OOM or crash | Increase instance type, check container logs |

---

## 20. Service Quotas

| Quota | Default Limit |
|---|---|
| Endpoints per region | 200 |
| Endpoint configs per region | 200 |
| Models per region | 200 |
| Variants per endpoint | 10 |
| Concurrent training jobs | 24 |
| Training job max duration | 5 days |
| Training instances per job | 20 |
| Concurrent processing jobs | 24 |
| Concurrent transform jobs | 24 |
| Max model size (compressed) | 30 GB |
| Max model size (uncompressed) | 100 GB |
| Tags per resource | 50 |

---

## 21. Security Best Practices

1. **Use VPC** for endpoints handling sensitive data
2. **Enable inter-container encryption** for distributed training
3. **Use KMS** for volume and S3 encryption
4. **Enable network isolation** when container doesn't need outbound access
5. **Use least-privilege IAM** — avoid `AmazonSageMakerFullAccess` in production
6. **Enable data capture** for model monitoring and auditing
7. **Use Model Registry** with manual approval for production deployments
8. **Set resource limits** via IAM condition keys (`sagemaker:InstanceType`)
9. **Rotate credentials** — SageMaker uses temporary credentials via IAM role

---

## 22. Terraform Resources Created by Our Renderer

### Always Created
1. `aws_iam_role` — execution role for sagemaker.amazonaws.com
2. `aws_iam_role_policy` — inline policy with computed permissions
3. `aws_iam_role_policy_attachment` — AmazonSageMakerFullAccess
4. `data.aws_sagemaker_prebuilt_ecr_image` — DLC image resolver (unless custom image)
5. `aws_cloudwatch_log_group` — endpoint log group
6. `aws_sagemaker_model` — model definition
7. `aws_sagemaker_endpoint_configuration` — endpoint config
8. `aws_sagemaker_endpoint` — the endpoint itself

### Conditionally Created
- `aws_s3_object` — placeholder model artifact (when S3 integration exists)

### Available but Not in Default Renderer
- `aws_sagemaker_feature_group` — Feature Store
- `aws_sagemaker_model_package_group` — Model Registry
- `aws_sagemaker_domain` — SageMaker Studio
- `aws_appautoscaling_target` + `aws_appautoscaling_policy` — autoscaling
