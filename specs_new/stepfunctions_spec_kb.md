# AWS Step Functions — Complete Knowledge Base

> This document is the plain-English reference for AWS Step Functions that the
> pipeline engine framework and developer agent can consult when handling any
> Step Functions-related request in a pipeline. It covers what Step Functions is,
> how state machines work, Amazon States Language, all 15 service integrations
> in the renderer, error handling, and troubleshooting.

---

## 1. What Is Step Functions?

AWS Step Functions is a serverless workflow orchestration service. You define
workflows as **state machines** using the **Amazon States Language (ASL)**, a
JSON-based language. Step Functions manages state, checkpoints, retries, and
error handling for distributed applications.

### Core Concepts
- **State machine**: A workflow definition containing states and transitions.
- **State**: A single step in the workflow (Task, Choice, Wait, Pass, etc.).
- **Execution**: A running instance of a state machine with its own input/output.
- **ASL (Amazon States Language)**: The JSON-based definition language.
- **Service integration**: A built-in pattern for calling AWS services from Task states.
- **Execution role**: IAM role the state machine assumes to invoke services.

### Free Tier
Standard workflows: **4,000 state transitions/month** (always free).
Express workflows: No free tier.

---

## 2. State Machine Types

### STANDARD
- **Duration**: Up to 365 days
- **Execution**: Exactly-once semantics
- **History**: Full event history (up to 25,000 events) via GetExecutionHistory
- **Pricing**: $0.025 per 1,000 state transitions
- **Patterns**: Supports `.sync` (wait for completion) and `.waitForTaskToken`
- **Use cases**: ETL orchestration, batch processing, human approval workflows, long-running jobs

### EXPRESS
- **Duration**: Up to 5 minutes
- **Execution**: At-least-once semantics
- **History**: No execution history API (use CloudWatch Logs)
- **Pricing**: Per request + per GB-second of duration
- **Patterns**: Does NOT support `.sync` or `.waitForTaskToken`
- **Use cases**: High-throughput event processing, IoT, API backends

Our engine defaults to STANDARD, which is appropriate for pipeline orchestration.

---

## 3. Amazon States Language (ASL)

Every state machine is defined as a JSON document:

```json
{
  "Comment": "My pipeline workflow",
  "StartAt": "FirstState",
  "States": {
    "FirstState": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": { "FunctionName": "my-function", "Payload.$": "$" },
      "Next": "SecondState"
    },
    "SecondState": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": { "JobName": "my-job" },
      "End": true
    }
  }
}
```

### Top-Level Fields
- `Comment`: Optional description
- `StartAt`: Name of the first state (required)
- `States`: Map of state definitions (required)
- `TimeoutSeconds`: Max execution time

---

## 4. State Types

### Task (most important)
Executes work by calling an AWS service, Activity, or Lambda function. The
`Resource` field determines what is called.

### Pass
Passes input to output, optionally injecting static `Result` data. Useful for
transforming data between states or as a placeholder.

### Choice
Conditional branching based on input data. Evaluates rules (StringEquals,
NumericGreaterThan, etc.) and transitions to the matching state. Must have a
`Default` fallback.

### Wait
Pauses for a fixed number of seconds, until a timestamp, or using a dynamic
value from the input (SecondsPath/TimestampPath).

### Parallel
Executes multiple branches concurrently. Each branch is a complete sub-workflow.
Output is an array of results (one per branch).

### Map
Iterates over an array, running a sub-workflow for each element. Two modes:
- **INLINE**: Up to 40 items, processed within the parent execution
- **DISTRIBUTED**: Up to 100 million items, processed as child executions

### Succeed
Terminal success state. Stops the execution successfully.

### Fail
Terminal failure state with an error name and cause message.

---

## 5. Service Integrations — The 15-Way Dispatch

This is the most critical section. The renderer's `_build_state_machine_definition()`
function creates ASL Task states based on the target service type. Here are all
15 integration types the renderer handles:

### 5.1 Lambda
```json
{
  "Resource": "arn:aws:states:::lambda:invoke",
  "Parameters": {
    "FunctionName.$": "$.function_name",
    "Payload.$": "$"
  }
}
```
Lambda invocations are synchronous by default. No `.sync` suffix needed.
IAM: `lambda:InvokeFunction`

### 5.2 Glue
```json
{
  "Resource": "arn:aws:states:::glue:startJobRun.sync",
  "Parameters": {
    "JobName": "my-glue-job"
  }
}
```
The `.sync` suffix makes Step Functions wait for the Glue job to complete.
IAM: `glue:StartJobRun`, `glue:GetJobRun`, `glue:GetJobRuns`, `glue:BatchStopJobRun`

### 5.3 DynamoDB
```json
{
  "Resource": "arn:aws:states:::dynamodb:putItem",
  "Parameters": {
    "TableName": "my-table",
    "Item": { "id": { "S.$": "$.id" } }
  }
}
```
Defaults to putItem. Other operations: getItem, updateItem, deleteItem, query, scan.
IAM: `dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:UpdateItem`, `dynamodb:Query`, `dynamodb:DeleteItem`

### 5.4 SQS
```json
{
  "Resource": "arn:aws:states:::sqs:sendMessage",
  "Parameters": {
    "QueueUrl.$": "$.queue_url",
    "MessageBody.$": "$"
  }
}
```
IAM: `sqs:SendMessage`

### 5.5 SNS
```json
{
  "Resource": "arn:aws:states:::sns:publish",
  "Parameters": {
    "TopicArn.$": "$.topic_arn",
    "Message.$": "$"
  }
}
```
IAM: `sns:Publish`

### 5.6 S3
```json
{
  "Resource": "arn:aws:states:::aws-sdk:s3:putObject",
  "Parameters": {
    "Bucket.$": "$.bucket",
    "Key.$": "$.key",
    "Body.$": "$.body"
  }
}
```
Uses the AWS SDK integration pattern (not an optimized integration). Any S3 API
can be called by changing the operation name in the resource ARN.
IAM: `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`

### 5.7 EMR Serverless
```json
{
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
The `.sync` suffix waits for the job to complete.
IAM: `emr-serverless:StartJobRun`, `emr-serverless:GetJobRun`, `emr-serverless:CancelJobRun`, `iam:PassRole`

### 5.8 EMR
```json
{
  "Resource": "arn:aws:states:::elasticmapreduce:addStep.sync",
  "Parameters": {
    "ClusterId.$": "$.cluster_id",
    "Step": {
      "Name": "my-step",
      "ActionOnFailure": "CONTINUE",
      "HadoopJarStep": {
        "Jar": "command-runner.jar",
        "Args.$": "$.step_args"
      }
    }
  }
}
```
IAM: `elasticmapreduce:AddJobFlowSteps`, `elasticmapreduce:DescribeStep`, `elasticmapreduce:CancelSteps`, `iam:PassRole`

### 5.9 SageMaker
```json
{
  "Resource": "arn:aws:states:::sagemaker:createTransformJob.sync",
  "Parameters": {
    "TransformJobName.$": "$.job_name",
    "ModelName.$": "$.model_name",
    "TransformInput": {
      "DataSource": {
        "S3DataSource": { "S3DataType": "S3Prefix", "S3Uri.$": "$.input_uri" }
      },
      "ContentType": "text/csv"
    },
    "TransformOutput": { "S3OutputPath.$": "$.output_uri" },
    "TransformResources": { "InstanceCount": 1, "InstanceType": "ml.m5.large" }
  }
}
```
Other SageMaker operations: createTrainingJob.sync, createProcessingJob.sync.
IAM: `sagemaker:Create*Job`, `sagemaker:Describe*Job`, `sagemaker:Stop*Job`, `iam:PassRole`

### 5.10 Athena
```json
{
  "Resource": "arn:aws:states:::athena:startQueryExecution.sync",
  "Parameters": {
    "QueryString.$": "$.query",
    "WorkGroup": "my-workgroup"
  }
}
```
IAM: `athena:StartQueryExecution`, `athena:GetQueryExecution`, `athena:GetQueryResults`

### 5.11 EventBridge
```json
{
  "Resource": "arn:aws:states:::events:putEvents",
  "Parameters": {
    "Entries": [{
      "Source": "stepfunctions.my-pipeline",
      "DetailType": "StepFunctionOutput",
      "Detail.$": "$"
    }]
  }
}
```
IAM: `events:PutEvents`

### 5.12 Kinesis Streams (via spec IAM)
Resource: `arn:aws:states:::aws-sdk:kinesis:putRecord`
IAM: `kinesis:PutRecord`, `kinesis:PutRecords`

### 5.13 Redshift (via spec IAM)
Resource: `arn:aws:states:::aws-sdk:redshift-data:executeStatement`
IAM: `redshift-data:ExecuteStatement`, `redshift-data:GetStatementResult`, `redshift-data:DescribeStatement`

### 5.14 Fallback (unknown types)
For unrecognized service types, the renderer generates a generic SDK integration:
```json
{
  "Resource": "arn:aws:states:::aws-sdk:{type}:invoke",
  "Parameters": {}
}
```

### 5.15 No Integrations
If the state machine has no outgoing integrations, the renderer creates a single
PassState: `{"Type": "Pass", "End": true}`.

---

## 6. Integration Patterns

### Request-Response (default)
Call the service and immediately proceed. Used for: Lambda, DynamoDB, SQS, SNS,
S3, EventBridge.

### Synchronous (.sync)
Call the service and wait for completion. Step Functions polls the service status.
Used for: Glue, EMR, EMR Serverless, SageMaker, Athena.
**Only available for STANDARD state machines.**

### Wait for Task Token (.waitForTaskToken)
Pause until an external process calls `SendTaskSuccess` or `SendTaskFailure`
with the task token. Used for human approval workflows and external integrations.
**Only available for STANDARD state machines.**

---

## 7. Error Handling

### Retry
Automatic retry on failure with exponential backoff:
```json
{
  "Retry": [{
    "ErrorEquals": ["States.TaskFailed"],
    "IntervalSeconds": 5,
    "MaxAttempts": 3,
    "BackoffRate": 2.0
  }]
}
```

### Catch
Redirect to a fallback state on error:
```json
{
  "Catch": [{
    "ErrorEquals": ["States.ALL"],
    "Next": "HandleError",
    "ResultPath": "$.error"
  }]
}
```

### Predefined Error Codes
| Error | Meaning |
|---|---|
| `States.ALL` | Matches any error |
| `States.Timeout` | Task exceeded TimeoutSeconds |
| `States.TaskFailed` | Task returned a failure |
| `States.Permissions` | Insufficient IAM permissions |
| `States.DataLimitExceeded` | Input/output exceeded 256 KB |
| `States.NoChoiceMatched` | No Choice rule matched, no Default |
| `States.HeartbeatTimeout` | Activity missed heartbeat |
| `States.BranchFailed` | Parallel/Map branch failed |

---

## 8. Input/Output Processing

Data flows through 5 transformation stages (applied in order):

1. **InputPath**: Select subset of state input (`"$.data"`)
2. **Parameters**: Construct new JSON for the task (use `.$` suffix for JsonPath)
3. **(Task execution)**
4. **ResultSelector**: Transform task result
5. **ResultPath**: Place result in original input (`"$.taskResult"` or `null` to discard)
6. **OutputPath**: Select subset of output for next state

### Intrinsic Functions
ASL supports built-in functions for common transformations:
- `States.Format('Hello, {}', $.name)` — string formatting
- `States.JsonToString($.obj)` — JSON to string
- `States.StringToJson($.str)` — string to JSON
- `States.Array($.a, $.b)` — create array
- `States.UUID()` — generate UUID
- `States.MathAdd($.x, 1)` — arithmetic
- `States.StringSplit($.csv, ',')` — split string

---

## 9. Logging and Monitoring

### CloudWatch Logs
Our renderer creates a log group at `/aws/vendedlogs/states/{resource_name}`
and configures ALL-level logging with execution data included. This enables:
- Full input/output logging for each state transition
- Pipeline Run Preview streaming in the web UI
- Post-mortem debugging of failed executions

The log destination ARN must include the `:*` suffix:
`"${aws_cloudwatch_log_group.LABEL_lg.arn}:*"`

### X-Ray Tracing
Optional distributed tracing. Not enabled by default to avoid extra cost.
Enable with `tracing_configuration { enabled = true }` in Terraform.

### Execution History
STANDARD only. Use `GetExecutionHistory` to see every state transition event.
Max 25,000 events per execution.

---

## 10. Terraform Resources Created by Renderer

The `_render_stepfunctions()` function creates:

1. `aws_iam_role` — Execution role (trust: `states.amazonaws.com`)
2. `aws_iam_role_policy` — Inline policy with all service integration permissions
3. `aws_cloudwatch_log_group` — `/aws/vendedlogs/states/{resource_name}`
4. `aws_sfn_state_machine` — The state machine with:
   - `definition` — Double-encoded ASL JSON
   - `role_arn` — Execution role
   - `type` — STANDARD (default)
   - `logging_configuration` — CloudWatch Logs at ALL level

### ASL Definition Generation
The renderer builds the definition by:
1. Walking `bp.integrations_as_source` (outgoing integrations)
2. Creating one Task state per integration target
3. Dispatching on `tgt.type` to pick the correct Resource ARN and Parameters
4. Chaining states sequentially with `Next`/`End`
5. Wrapping in the top-level ASL structure with `Comment`, `StartAt`, `States`

If there are no outgoing integrations, a single `PassState` is created.

---

## 11. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `States.TaskFailed` | Downstream service error | Check target service logs (Lambda, Glue, etc.) |
| `AccessDenied / iam:PassRole` | Missing IAM permissions | Add permissions to execution role |
| `States.Timeout` | Task or execution timeout | Increase TimeoutSeconds or optimize task |
| `States.DataLimitExceeded` | >256 KB input/output | Use S3 for large payloads |
| `ExecutionAlreadyExists` | Duplicate execution name | Use unique names or omit for auto-generation |
| `InvalidDefinition` | Bad ASL JSON | Validate in Step Functions console |
| `States.NoChoiceMatched` | Missing Default in Choice | Add Default state to Choice |
| `ExecutionHistoryLimitExceeded` | >25K events (STANDARD) | Break into child executions or use Distributed Map |
| `StateMachineDoesNotExist` | State machine deleted | Re-run terraform apply |

### Debugging Steps
1. Check execution status: `describe_execution(executionArn)`
2. Get event history: `get_execution_history(executionArn)`
3. Find the failed state in the events (look for `TaskFailed` event type)
4. Check the downstream service logs for the root cause error
5. Check CloudWatch Logs at `/aws/vendedlogs/states/{resource_name}`

---

## 12. Developer Agent: Updating Step Functions

### Updating the State Machine Definition
```python
sfn = boto3.client('stepfunctions')
machines = sfn.list_state_machines()['stateMachines']
arn = next(m['stateMachineArn'] for m in machines if 'my-pipeline' in m['name'])
desc = sfn.describe_state_machine(stateMachineArn=arn)
defn = json.loads(desc['definition'])

# Modify the definition
defn['States']['NewState'] = {'Type': 'Pass', 'End': True}
defn['States']['OldLastState']['Next'] = 'NewState'
del defn['States']['OldLastState']['End']

sfn.update_state_machine(
    stateMachineArn=arn,
    definition=json.dumps(defn),
    roleArn=desc['roleArn']
)
```

### What Can Be Updated
- Definition (ASL JSON)
- Role ARN
- Logging configuration
- Tracing configuration

### What Cannot Be Changed
- Type (STANDARD/EXPRESS) — requires delete + recreate
- Name — requires delete + recreate

### Execution Management
- Start: `start_execution(stateMachineArn, input=json.dumps({...}))`
- Stop: `stop_execution(executionArn, cause='manual stop')`
- Redrive (retry from failure): `redrive_execution(executionArn)` (STANDARD only)

---

## 13. Advanced Patterns

### Saga Pattern (Compensating Transactions)
Use Catch blocks to redirect to rollback states when a step fails:
```json
{
  "Charge Credit Card": {
    "Type": "Task", "Resource": "...",
    "Catch": [{ "ErrorEquals": ["States.ALL"], "Next": "Refund Credit Card" }],
    "Next": "Reserve Flight"
  }
}
```

### Fan-Out / Fan-In with Parallel
Execute multiple independent tasks and aggregate results:
```json
{
  "Type": "Parallel",
  "Branches": [
    { "StartAt": "ProcessA", "States": { "ProcessA": { "Type": "Task", ... } } },
    { "StartAt": "ProcessB", "States": { "ProcessB": { "Type": "Task", ... } } }
  ]
}
```

### Dynamic Parallelism with Map
Process each item in a list independently:
```json
{
  "Type": "Map",
  "ItemsPath": "$.items",
  "MaxConcurrency": 10,
  "ItemProcessor": {
    "StartAt": "ProcessItem",
    "States": { "ProcessItem": { "Type": "Task", "Resource": "...", "End": true } }
  }
}
```

### Distributed Map for Massive Scale
Process millions of items from S3:
```json
{
  "Type": "Map",
  "ItemProcessor": {
    "ProcessorConfig": { "Mode": "DISTRIBUTED", "ExecutionType": "STANDARD" },
    "StartAt": "...", "States": { ... }
  },
  "ItemReader": {
    "Resource": "arn:aws:states:::s3:getObject",
    "ReaderConfig": { "InputType": "CSV" },
    "Parameters": { "Bucket": "my-bucket", "Key": "data.csv" }
  },
  "MaxConcurrency": 1000
}
```

---

## 14. Cost Optimization

1. **Use STANDARD for orchestration** (4,000 free transitions/month)
2. **Use EXPRESS only for high-throughput** short-duration workloads
3. **Minimize state transitions** — combine simple operations into single Lambda functions
4. **Use Wait states** instead of polling loops
5. **Set appropriate timeouts** to avoid stuck executions accruing costs
6. **Use Distributed Map** for massive parallelism (more efficient than launching many executions)
7. **Disable X-Ray tracing** in production unless needed
8. **Set CloudWatch logging to ERROR** level in production (reduces log volume)

---

## 15. Quotas to Watch

| Quota | Limit | Adjustable |
|---|---|---|
| State machines per region | 10,000 | Yes |
| Max execution time (STANDARD) | 365 days | No |
| Max execution time (EXPRESS) | 5 minutes | No |
| Input/output size | 256 KB | No |
| Execution history events | 25,000 | No |
| Open executions per SM | 1,000,000 | Yes |
| StartExecution API rate | 1,000/sec | Yes |
| Definition size | 1 MB | No |
| States per machine | 10,000 | No |
