# AWS Lambda -- Complete Knowledge Base

> This document is the plain-English reference for Lambda that the pipeline engine
> framework and developer agent can consult when handling any Lambda-related request
> in a pipeline. It covers what Lambda is, how it works, every feature, integration
> patterns, security, performance, and troubleshooting -- written for an agent
> that needs to reason about Lambda in context, not just look up API parameters.

---

## 1. What Is Lambda?

AWS Lambda is a serverless compute service that runs your code in response to
events without requiring you to provision or manage servers. You upload your code
(as a ZIP file or container image), configure triggers, and Lambda handles
everything else: scaling, patching, monitoring, and high availability.

Lambda is the most common compute service in our pipeline engine. It serves as
the "glue" between other AWS services -- reading from S3, processing data,
writing to DynamoDB, publishing to SNS/SQS, invoking other Lambdas, and
orchestrating services like EMR, Glue, and SageMaker.

### Core Concepts
- **Function**: Your code + configuration (runtime, handler, memory, timeout).
- **Execution role**: IAM role that grants the function permissions to access AWS services.
- **Handler**: The entry point method (e.g., `index.handler` means `handler()` in `index.py`).
- **Event**: JSON payload that triggers the function (structure depends on the source).
- **Execution environment**: Isolated container that runs your function. Reused across invocations ("warm start") or created fresh ("cold start").
- **Concurrency**: Number of simultaneous function executions.

### Free Tier
Lambda is always-free tier: 1 million requests/month and 400,000 GB-seconds of
compute time per month. At 128 MB memory, that is 3.2 million seconds (~37 days)
of execution per month.

---

## 2. Function Configuration

### Memory and CPU
- **Memory range**: 128 MB to 10,240 MB (10 GB), in 1 MB increments
- **CPU scales with memory**: At 1,769 MB, you get 1 full vCPU equivalent
- Below 1,769 MB, you get a proportional fraction of a vCPU
- Above 1,769 MB, you get additional vCPU cores (up to 6 vCPUs at 10 GB)
- **Our default**: 128 MB (minimum, free-tier friendly)

### Timeout
- **Range**: 1 second to 900 seconds (15 minutes)
- **Our default**: 30 seconds
- If your function times out, increase the timeout or optimize the code

### Ephemeral Storage (/tmp)
- **Range**: 512 MB to 10,240 MB (10 GB), in 1 MB increments
- Persists between invocations on the same execution environment (warm starts)
- Cleared when the environment is recycled

### Environment Variables
- Key-value pairs accessible to your function code
- **Aggregate limit**: 4 KB total across all environment variables
- Encrypted at rest by default (AWS KMS managed key)
- Can use customer-managed KMS key for additional control
- **Critical**: Always fetch current vars before updating to avoid erasing existing wiring

### Architectures
- **x86_64**: Intel/AMD, broader compatibility
- **arm64**: AWS Graviton2, 20% cheaper, better price-performance
- **Our default**: arm64 (cost optimization)

---

## 3. Runtimes

Lambda supports managed runtimes for multiple languages. All runtimes support
both x86_64 and arm64 architectures.

### Currently Supported (as of 2026)

| Language | Identifiers | OS |
|---|---|---|
| Python | python3.14, python3.13, **python3.12** (our default), python3.11, python3.10 | AL2023/AL2 |
| Node.js | nodejs24.x, nodejs22.x, nodejs20.x | AL2023 |
| Java | java25, java21, java17, java11, java8.al2 | AL2023/AL2 |
| .NET | dotnet10, dotnet9 (container only), dotnet8 | AL2023 |
| Ruby | ruby3.4, ruby3.3, ruby3.2 | AL2023/AL2 |
| Custom | provided.al2023, provided.al2 | AL2023/AL2 |

**Go, Rust, C++**: Use custom runtime (`provided.al2023`).

**Important**: Amazon Linux 2 reaches EOL on June 30, 2026. Migrate to
Amazon Linux 2023-based runtimes as soon as possible.

---

## 4. Deployment Packages

### ZIP Archive
- **Max size**: 50 MB (zipped), 250 MB (unzipped, including layers)
- Upload directly via API/SDK or from S3
- Our renderer creates a placeholder ZIP with `data.archive_file`

### Container Image
- **Max size**: 10 GB (uncompressed)
- Based on AWS-provided or custom base images
- Stored in Amazon ECR

### Layers
- ZIP archives containing libraries, custom runtimes, or config files
- **Max 5 layers** per function
- Extracted to `/opt` in the execution environment
- Shared across multiple functions
- Each layer version is immutable; ARN includes version number
- ARN format: `arn:aws:lambda:REGION:ACCOUNT:layer:NAME:VERSION`
- **Not recommended for Go/Rust** (increases cold start time)

---

## 5. Concurrency

### Unreserved Concurrency (Default)
Functions share a regional pool of 1,000 concurrent executions (default).
No additional cost. Risk: other functions can consume all capacity.

### Reserved Concurrency
Guarantees a fixed amount of concurrency for a specific function. Also caps
maximum concurrency (prevents runaway scaling). No additional cost. Set via
`reserved_concurrent_executions` attribute.

**Trade-off**: Reserved capacity is subtracted from the account pool, reducing
availability for other functions.

### Provisioned Concurrency
Pre-initializes execution environments to eliminate cold starts. Used for
latency-sensitive applications. **Additional charge** -- billed for provisioned
hours regardless of usage.

### Scaling
- **Rate**: 1,000 new instances per 10 seconds per function
- **RPS limit**: 10x the concurrency quota (10,000 RPS at default 1,000 concurrency)
- Functions with very short execution times (<100ms) may hit RPS limits before concurrency limits

### Concurrency Formula
```
Concurrency = (average requests/second) * (average duration in seconds)
```
Example: 100 requests/sec with 500ms average = 50 concurrent executions.

---

## 6. Invocation Models

### Synchronous (RequestResponse)
- Caller waits for the function to complete
- Payload limit: 6 MB (request and response)
- Response streaming: up to 200 MB
- Use case: API Gateway, SDK `invoke()`, CLI

### Asynchronous (Event)
- Lambda queues the event and returns immediately (202 status)
- Payload limit: 1 MB
- Auto-retries: up to 2 times (configurable 0-2)
- Max event age: 6 hours (configurable)
- Dead letter queue: SQS or SNS for failed events
- Destinations: route success/failure to SQS, SNS, Lambda, or EventBridge
- Use case: S3 events, SNS notifications, CloudWatch Events

### DryRun
- Validates parameters and permissions without executing
- Use for testing IAM configuration

---

## 7. Event Source Mappings (Poll-Based Triggers)

Lambda polls these services and invokes the function with batches of records.
The **Lambda renderer** creates `aws_lambda_event_source_mapping` for these.

| Source | Default Batch | Max Batch | Starting Position | Bisect on Error | Parallelization |
|---|---|---|---|---|---|
| SQS | 10 | 10,000 | N/A | No | No |
| Kinesis Streams | 100 | 10,000 | LATEST / TRIM_HORIZON | Yes | Yes (1-10) |
| DynamoDB Streams | 100 | 10,000 | LATEST / TRIM_HORIZON | Yes | Yes (1-10) |
| MSK | 100 | 10,000 | LATEST / TRIM_HORIZON | No | No |
| Self-managed Kafka | 100 | 10,000 | LATEST / TRIM_HORIZON | No | No |
| Amazon MQ | varies | varies | varies | No | No |
| DocumentDB | varies | varies | varies | No | No |

**Payload limit**: 6 MB for the entire batch (non-configurable).

**Batching window**: 0-300 seconds. Set higher to accumulate more records per invocation.

---

## 8. Event-Driven Triggers (Push-Based)

These services invoke Lambda directly (not via event source mapping):

| Source | Permission Required | Created By |
|---|---|---|
| S3 event notification | `aws_lambda_permission` (s3.amazonaws.com) | S3 renderer |
| SNS subscription | `aws_sns_topic_subscription` (protocol: lambda) | SNS renderer |
| EventBridge rule | `aws_lambda_permission` (events.amazonaws.com) | CloudWatch/EventBridge renderer |
| CloudWatch Events | `aws_lambda_permission` (events.amazonaws.com) | CloudWatch renderer |
| API Gateway | `aws_lambda_permission` (apigateway.amazonaws.com) | API Gateway config |
| CloudWatch Logs | `aws_lambda_permission` (logs.amazonaws.com) | CloudWatch Logs config |
| IoT Rules | `aws_lambda_permission` (iot.amazonaws.com) | IoT config |

---

## 9. VPC Configuration

Lambda can run inside a VPC to access private resources like RDS, ElastiCache,
Redshift, MSK, and OpenSearch.

### How It Works
- Lambda creates Elastic Network Interfaces (ENIs) in your VPC subnets
- Traffic to VPC resources stays within the VPC
- Internet access requires a NAT Gateway or VPC endpoint

### When VPC Is Required (vpc_triggers in our engine)
Our pipeline engine automatically enables VPC when Lambda integrates with:
- Redshift
- Aurora / RDS
- OpenSearch
- ElastiCache
- MSK

### Terraform Resources Created
- `aws_security_group` with egress-only rules
- `vpc_config` block on the Lambda function

### IAM Permissions Required
The execution role automatically gets:
- `ec2:CreateNetworkInterface`
- `ec2:DescribeNetworkInterfaces`
- `ec2:DeleteNetworkInterface`

### Best Practices
- Use at least 2 subnets in different AZs for high availability
- Place Lambda in private subnets (not public)
- Use VPC endpoints for AWS services (S3 Gateway endpoint is free)
- Be aware of ENI limits (500 per VPC, adjustable)

---

## 10. Function URLs

Lambda function URLs provide a dedicated HTTPS endpoint without needing
API Gateway. Useful for simple webhook endpoints or microservices.

- **Auth types**: AWS_IAM (SigV4 required) or NONE (public)
- **CORS**: Configurable
- **Response streaming**: Supported
- **URL format**: `https://<url-id>.lambda-url.<region>.on.aws`

---

## 11. Destinations

Route asynchronous invocation results to another service without writing
routing code in the function itself:

**Supported destinations** (on success and/or failure):
- SQS queue
- SNS topic
- Lambda function
- EventBridge event bus

---

## 12. IAM Permissions Reference

### Execution Role (Trust Policy)
Every Lambda function has an execution role with trust policy for
`lambda.amazonaws.com`. This role determines what AWS services the function
can access.

### Always-Required Permissions
Every Lambda execution role needs:
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

### VPC Permissions (when vpc_required)
- `ec2:CreateNetworkInterface`
- `ec2:DescribeNetworkInterfaces`
- `ec2:DeleteNetworkInterface`

### Integration Permissions (from spec_builder)
Permissions are computed from the integration graph. Examples:

| Integration | Permissions Added |
|---|---|
| Lambda reads S3 | s3:GetObject, s3:ListBucket |
| Lambda writes S3 | s3:PutObject, s3:GetObject, s3:ListBucket, s3:DeleteObject |
| Lambda sends to SQS | sqs:SendMessage |
| Lambda receives from SQS | sqs:ReceiveMessage, sqs:DeleteMessage, sqs:GetQueueAttributes |
| Lambda publishes to SNS | sns:Publish |
| Lambda writes DynamoDB | dynamodb:PutItem, GetItem, UpdateItem, Query, Scan, DeleteItem, BatchWriteItem |
| Lambda invokes Lambda | lambda:InvokeFunction |
| Lambda starts Step Functions | states:StartExecution, states:DescribeExecution |
| Lambda writes Kinesis | kinesis:PutRecord, kinesis:PutRecords |
| Lambda writes Firehose | firehose:PutRecord, firehose:PutRecordBatch |
| Lambda queries Redshift | redshift-data:ExecuteStatement, GetStatementResult, DescribeStatement, redshift:GetClusterCredentials |
| Lambda queries Aurora | rds-data:ExecuteStatement, BatchExecuteStatement, secretsmanager:GetSecretValue |
| Lambda invokes SageMaker | sagemaker:InvokeEndpoint |
| Lambda puts EventBridge | events:PutEvents |
| Lambda starts Athena | athena:StartQueryExecution, GetQueryExecution, GetQueryResults + S3 perms |
| Lambda starts EMR Serverless | emr-serverless:StartJobRun, GetJobRun, CancelJobRun, ListJobRuns, GetApplication, iam:PassRole |
| Lambda submits EMR steps | elasticmapreduce:AddJobFlowSteps, DescribeStep, ListSteps, DescribeCluster, iam:PassRole |
| Lambda starts Glue | glue:StartJobRun, GetJobRun, StartCrawler, GetCrawler, GetCrawlerMetrics |
| Lambda accesses MSK | kafka:DescribeCluster, GetBootstrapBrokers, kafka-cluster:Connect, DescribeGroup, AlterGroup, DescribeTopic, ReadData, WriteData |

### Resource-Based Policy (Function Policy)
Grants other services permission to invoke the function:
- **Max size**: 20 KB
- Created via `aws_lambda_permission` Terraform resource
- Common principals: s3.amazonaws.com, events.amazonaws.com, sns.amazonaws.com, lambda.amazonaws.com

### ARN Formats
- Function: `arn:aws:lambda:REGION:ACCOUNT:function:NAME`
- Version: `arn:aws:lambda:REGION:ACCOUNT:function:NAME:VERSION`
- Alias: `arn:aws:lambda:REGION:ACCOUNT:function:NAME:ALIAS`
- Layer: `arn:aws:lambda:REGION:ACCOUNT:layer:NAME:VERSION`

---

## 13. Environment Variables in Our Pipeline

Lambda environment variables are auto-wired based on outgoing integrations.
The spec builder replaces `{PEER_UPPER}` with the target service name in
uppercase and `{peer_label}` with the Terraform resource label.

| Target Service | Env Var Pattern | Terraform Reference |
|---|---|---|
| S3 | `{PEER}_BUCKET` | `aws_s3_bucket.{label}.id` |
| SQS | `{PEER}_QUEUE_URL` | `aws_sqs_queue.{label}.url` |
| SNS | `{PEER}_TOPIC_ARN` | `aws_sns_topic.{label}.arn` |
| DynamoDB | `{PEER}_TABLE` | `aws_dynamodb_table.{label}.name` |
| Step Functions | `{PEER}_STATE_MACHINE_ARN` | `aws_sfn_state_machine.{label}.arn` |
| Lambda | `{PEER}_FUNCTION_ARN` | `aws_lambda_function.{label}.arn` |
| Kinesis Streams | `{PEER}_STREAM_NAME` | `aws_kinesis_stream.{label}.name` |
| Kinesis Firehose | `{PEER}_DELIVERY_STREAM` | `aws_kinesis_firehose_delivery_stream.{label}.name` |
| EventBridge | `{PEER}_EVENT_BUS` | `aws_cloudwatch_event_bus.{label}.name` |
| EMR Serverless | `{PEER}_APPLICATION_ID` + `{PEER}_EXECUTION_ROLE_ARN` | app ID + role ARN |
| EMR | `{PEER}_CLUSTER_ID` | `aws_emr_cluster.{label}.id` |
| Glue | `{PEER}_CRAWLER_NAME` | `aws_glue_crawler.{label}.name` |
| Athena | `{PEER}_WORKGROUP` | `aws_athena_workgroup.{label}.name` |
| MSK | `{PEER}_BOOTSTRAP_BROKERS` | `aws_msk_cluster.{label}.bootstrap_brokers` |
| Redshift | `{PEER}_CLUSTER_ID` + `{PEER}_DATABASE` | cluster ID + database name |
| Aurora | `{PEER}_CLUSTER_ARN` + `{PEER}_DATABASE` | cluster ARN + database name |
| SageMaker | `{PEER}_ENDPOINT_NAME` | `aws_sagemaker_endpoint.{label}.name` |

---

## 14. Terraform Resources

### Always Created by Lambda Renderer
1. `data.archive_file` -- placeholder ZIP with stub handler
2. `aws_iam_role` -- execution role (trust: lambda.amazonaws.com)
3. `aws_iam_role_policy` -- inline policy with computed permissions
4. `aws_cloudwatch_log_group` -- `/aws/lambda/{function_name}`, 7-day retention
5. `aws_lambda_function` -- the function with all configuration

### Conditionally Created
- `aws_lambda_event_source_mapping` -- when SQS, Kinesis, DynamoDB, or MSK triggers this Lambda
- `aws_lambda_permission` -- when this Lambda invokes another Lambda
- `aws_security_group` -- when `vpc_required` is true

### Created by Other Renderers
- `aws_s3_bucket_notification` + `aws_lambda_permission` -- S3 renderer (S3 triggers Lambda)
- `aws_sns_topic_subscription` -- SNS renderer (SNS delivers to Lambda)
- `aws_cloudwatch_event_target` + `aws_lambda_permission` -- CloudWatch/EventBridge renderer

---

## 15. Service Quotas

| Quota | Limit |
|---|---|
| Concurrent executions (default) | 1,000 per region (adjustable) |
| Function memory | 128 MB - 10,240 MB |
| Function timeout | 900 seconds (15 minutes) |
| Environment variables | 4 KB aggregate |
| Deployment package (ZIP) | 50 MB zipped, 250 MB unzipped |
| Container image | 10 GB uncompressed |
| Layers per function | 5 |
| /tmp storage | 512 MB - 10,240 MB |
| Sync payload | 6 MB request + response |
| Async payload | 1 MB |
| Resource-based policy | 20 KB |
| Function name | 64 characters max |
| File descriptors | 1,024 |
| Processes/threads | 1,024 |
| Storage for ZIPs + layers | 75 GB per region |
| ENIs per VPC | 500 (adjustable) |

---

## 16. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `Task timed out after N seconds` | Function exceeded timeout | Increase timeout or optimize code |
| `Runtime exited / signal: killed / OOM` | Out of memory | Increase memory_size (e.g., 512 or 1024 MB) |
| `Unable to import module / No module named` | Missing dependency | Rebuild ZIP with dependency, or use Layer |
| `AccessDenied / not authorized` | Missing IAM permission | Add required action to execution role |
| `Invalid length for executionRoleArn: 0` | EMR env var empty | Set EXECUTION_ROLE_ARN env var from IAM |
| `ResourceNotFoundException` | Function does not exist | Check terraform apply completed |
| `TooManyRequestsException` | Concurrency limit hit | Request limit increase or add reserved concurrency |
| `Unzipped size must be smaller` | Package > 250 MB | Use layers or container image |
| `ENILimitReachedException` | VPC ENI limit | Request ENI limit increase |
| `KMSAccessDeniedException` | Cannot decrypt env vars | Add kms:Decrypt to execution role |
| `InvalidSecurityGroupID` | Bad VPC config | Verify security group exists |

---

## 17. Security Best Practices

1. **Least privilege IAM**: Only grant specific actions on specific resource ARNs
2. **Use arm64**: 20% cheaper with equal or better performance
3. **Environment variable encryption**: Use customer-managed KMS key for sensitive data
4. **Code signing**: Ensure only trusted code runs in production
5. **VPC for private resources**: Always use VPC when accessing RDS, Redshift, MSK, etc.
6. **Reserved concurrency**: Prevent runaway scaling and protect downstream services
7. **Dead letter queues**: Configure DLQ for async invocations to prevent event loss
8. **Function URLs**: Use AWS_IAM auth type unless public access is required
9. **Resource-based policy**: Restrict which services/accounts can invoke the function
10. **Enable X-Ray tracing**: For distributed tracing across service boundaries

---

## 18. Monitoring in Our Pipeline

Lambda has native CloudWatch Logs integration. The Lambda renderer creates a
CloudWatch Log Group at `/aws/lambda/{function_name}` with 7-day retention.

For pipeline run monitoring, the log aggregator discovers this log group from
the Terraform state and polls `FilterLogEvents` in near-real-time (~3 seconds).

### Key CloudWatch Metrics (AWS/Lambda namespace)
- `Invocations` -- number of function invocations
- `Duration` -- execution time in milliseconds
- `Errors` -- invocations that resulted in an error
- `Throttles` -- invocations throttled by concurrency limits
- `ConcurrentExecutions` -- current concurrent executions
- `IteratorAge` -- age of last record processed (for stream sources)

---

## 19. Integration Patterns in Our Pipeline Engine

### Lambda as Event Target (receives events)
- **S3 -> Lambda**: S3 renderer creates notification + permission. Lambda receives S3 event JSON.
- **SQS -> Lambda**: Lambda renderer creates event source mapping. Lambda receives batch of SQS messages.
- **Kinesis -> Lambda**: Lambda renderer creates event source mapping. Lambda receives batch of records.
- **DynamoDB -> Lambda**: Lambda renderer creates event source mapping. Lambda receives stream records.
- **SNS -> Lambda**: SNS renderer creates subscription. Lambda receives SNS message wrapper.
- **EventBridge -> Lambda**: EventBridge renderer creates target + permission. Lambda receives event JSON.

### Lambda as Orchestrator (sends to other services)
Lambda is the most common "orchestrator" in our pipelines. It can invoke any
AWS service via boto3 SDK. Our engine auto-wires:
1. IAM permissions (from spec `as_source_to` rules)
2. Environment variables (from spec `env_vars.as_source_to` rules)
3. Terraform resource references (from renderer wiring)

### Wiring Ownership Rules
| Wiring | Owned By | Resources Created |
|---|---|---|
| S3 -> Lambda trigger | S3 fragment | `aws_s3_bucket_notification` + `aws_lambda_permission` |
| SQS -> Lambda ESM | Lambda fragment | `aws_lambda_event_source_mapping` |
| Kinesis -> Lambda ESM | Lambda fragment | `aws_lambda_event_source_mapping` |
| DynamoDB -> Lambda ESM | Lambda fragment | `aws_lambda_event_source_mapping` |
| SNS -> Lambda sub | SNS fragment | `aws_sns_topic_subscription` |
| EventBridge -> Lambda | EventBridge fragment | `aws_cloudwatch_event_target` + `aws_lambda_permission` |
| Lambda -> Lambda invoke | Caller Lambda fragment | `aws_lambda_permission` on target |

---

## 20. Code Update Workflow (Developer Agent)

### Updating Environment Variables (Most Common)
```python
lam = boto3.client('lambda', region_name=region)
# ALWAYS fetch current vars first
current = lam.get_function_configuration(
    FunctionName=name
).get('Environment', {}).get('Variables', {})
# Merge new vars with existing
lam.update_function_configuration(
    FunctionName=name,
    Environment={'Variables': {**current, 'NEW_KEY': 'new_value'}}
)
```

### Updating Function Code
1. Download current ZIP: `info = lam.get_function(FunctionName=name)` then fetch `info['Code']['Location']`
2. Modify files in memory using `zipfile.ZipFile` + `io.BytesIO`
3. Re-upload: `lam.update_function_code(FunctionName=name, ZipFile=modified_zip.getvalue())`
4. Wait for propagation: poll `LastUpdateStatus` until `Successful` (~5-30 seconds)

### Updating Configuration
```python
lam.update_function_configuration(
    FunctionName=name,
    Timeout=300,
    MemorySize=512,
    # ... any updatable attribute
)
```
