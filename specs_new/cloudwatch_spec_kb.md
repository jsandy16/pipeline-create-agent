# Amazon CloudWatch -- Complete Knowledge Base

> This document is the plain-English reference for CloudWatch that the pipeline
> engine framework and developer agent can consult when handling any
> CloudWatch-related request in a pipeline. It covers the full CloudWatch
> ecosystem: metrics, alarms, dashboards, logs, events, Synthetics, and how
> CloudWatch underpins nearly every other service in the pipeline.

---

## 1. What Is CloudWatch?

Amazon CloudWatch is AWS's monitoring and observability service. It collects
metrics, logs, and events from nearly every AWS service, and provides tools to
visualize, alarm on, and act on that data. In our pipeline engine, CloudWatch
appears in two distinct roles:

1. **As a service type ("cloudwatch")**: Creates CloudWatch Event Rules that
   trigger downstream services on a schedule. This is functionally identical
   to the EventBridge service type. The Terraform resource is
   `aws_cloudwatch_event_rule`.

2. **As infrastructure for all other services**: Every compute service renderer
   creates a `aws_cloudwatch_log_group` for its logs. The pipeline run monitor
   (`log_aggregator.py`) reads these log groups to stream real-time execution
   logs to the browser.

### Core Components
- **Metrics**: Time-series data points (e.g., CPU utilization, request count)
- **Alarms**: Watch metrics and trigger actions when thresholds are breached
- **Dashboards**: Visualization of metrics and logs
- **Logs**: Centralized log collection, storage, and analysis
- **Events**: Event routing (now part of EventBridge)
- **Synthetics**: Automated canary tests for endpoints
- **Contributor Insights**: Top-N analysis of log data

### Free Tier
CloudWatch has a generous always-free tier: 10 custom metrics, 10 alarms,
1 million API requests, 5 GB log data ingestion, 5 GB log data archive
storage, 3 dashboards (up to 50 metrics each), and basic monitoring
(5-minute intervals) for EC2, EBS, and ELB.

---

## 2. CloudWatch Metrics

### What Are Metrics?
Metrics are time-series data points identified by three attributes:
- **Namespace**: Grouping container (e.g., `AWS/Lambda`, `AWS/S3`, `Custom/MyApp`)
- **Metric Name**: What is being measured (e.g., `Invocations`, `Duration`)
- **Dimensions**: Key-value pairs that further identify the metric (e.g.,
  `FunctionName=my-function`)

### Resolution and Retention
| Resolution | Period | Retention |
|---|---|---|
| High-resolution (custom) | 1 second | 3 hours |
| Standard (1-minute) | 60 seconds | 15 days |
| 5-minute aggregation | 300 seconds | 63 days |
| 1-hour aggregation | 3600 seconds | 455 days (15 months) |

Data is automatically aggregated as it ages. You cannot query 1-second data
after 3 hours -- it has already been aggregated to 1-minute.

### Key AWS Service Metrics

**Lambda** (`AWS/Lambda`):
- `Invocations` -- number of function invocations
- `Duration` -- execution time in milliseconds
- `Errors` -- invocations that resulted in an error
- `Throttles` -- invocations throttled by concurrency limits
- `ConcurrentExecutions` -- current concurrent executions

**S3** (`AWS/S3`):
- `BucketSizeBytes`, `NumberOfObjects` -- daily bucket metrics
- `AllRequests`, `GetRequests`, `PutRequests` -- request counts
- `4xxErrors`, `5xxErrors` -- error rates
- `FirstByteLatency`, `TotalRequestLatency` -- performance

**SQS** (`AWS/SQS`):
- `NumberOfMessagesSent`, `NumberOfMessagesReceived`
- `ApproximateNumberOfMessagesVisible` -- queue depth
- `ApproximateAgeOfOldestMessage` -- processing lag

**DynamoDB** (`AWS/DynamoDB`):
- `ConsumedReadCapacityUnits`, `ConsumedWriteCapacityUnits`
- `ThrottledRequests` -- capacity exceeded

**EventBridge** (`AWS/Events`):
- `Invocations`, `FailedInvocations`
- `MatchedEvents`, `TriggeredRules`

### Custom Metrics
Publish your own metrics using `put_metric_data()`. Two approaches:
1. **Direct API call**: Use `cloudwatch.put_metric_data()` with namespace,
   metric name, value, dimensions, and optional unit
2. **Embedded Metric Format**: Publish structured JSON log messages that
   CloudWatch automatically extracts into metrics (no API calls needed)

### Metric Math
Combine metrics using mathematical expressions:
- Error rate: `Errors / Invocations * 100`
- Anomaly detection: `ANOMALY_DETECTION_BAND(metric, 2)`
- Cross-metric aggregation: `SUM(METRICS())`

---

## 3. CloudWatch Alarms

### Metric Alarms
Watch a single metric and trigger actions when a threshold is breached.

**Alarm States**:
- **OK**: Metric is within the acceptable range
- **ALARM**: Metric has breached the threshold
- **INSUFFICIENT_DATA**: Not enough data to determine state

**Configuration**:
- **Metric**: Which metric to watch (namespace + metric name + dimensions)
- **Statistic**: How to aggregate (Sum, Average, Min, Max, SampleCount, or percentile)
- **Period**: Aggregation window (e.g., 300 seconds = 5 minutes)
- **Evaluation Periods**: How many consecutive periods must breach
- **Threshold**: The value to compare against
- **Comparison Operator**: GreaterThan, LessThan, etc.
- **Treat Missing Data**: What to do when no data points exist

**Actions**:
- `alarm_actions`: Trigger when entering ALARM (e.g., SNS notification)
- `ok_actions`: Trigger when returning to OK
- `insufficient_data_actions`: Trigger when data is missing

### Composite Alarms
Combine multiple alarms using AND/OR/NOT logic. Useful for reducing alarm
noise by requiring multiple conditions to be true before alerting.

Example: `ALARM('high-cpu') AND ALARM('low-memory')` -- only alert when
both CPU is high AND memory is low.

### Anomaly Detection
Machine learning-based dynamic thresholds that adapt to metric patterns
(daily/weekly cycles, trends). Instead of a static threshold, the alarm
uses a band of expected values. Useful when "normal" varies by time of day.

### Common Alarm Patterns for Pipelines
| What to Monitor | Metric | Threshold | Why |
|---|---|---|---|
| Lambda errors | `AWS/Lambda:Errors` | >= 1 | Any error is worth investigating |
| Lambda duration | `AWS/Lambda:Duration` | > timeout*0.8 | Approaching timeout |
| SQS queue depth | `AWS/SQS:ApproximateNumberOfMessagesVisible` | > 1000 | Processing falling behind |
| SQS message age | `AWS/SQS:ApproximateAgeOfOldestMessage` | > 300s | Stale messages |
| DynamoDB throttling | `AWS/DynamoDB:ThrottledRequests` | >= 1 | Capacity exhausted |

---

## 4. CloudWatch Dashboards

Dashboards provide customizable visualization of metrics, logs, and alarms.

### Widget Types
- **Metric widget**: Line, stacked area, bar, or pie chart
- **Text widget**: Markdown-formatted text
- **Log widget**: CloudWatch Logs Insights query results
- **Alarm widget**: Alarm status grid

### Key Features
- Up to 500 widgets per dashboard
- Cross-account metrics (with cross-account observability enabled)
- Automatic dashboards for services in use
- 3 free dashboards (up to 50 metrics each)

### Terraform
```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "my-pipeline-dashboard"
  dashboard_body = jsonencode({...})
}
```

---

## 5. CloudWatch Logs

CloudWatch Logs is the centralized log service used by virtually every AWS
compute service. It is critical infrastructure for our pipeline engine's
Pipeline Run Preview feature.

### Core Concepts
- **Log Group**: Container for log streams. Has retention policy, encryption
  settings, and access controls. One log group per service instance.
- **Log Stream**: Sequence of log events from a single source (e.g., one
  Lambda invocation, one ECS container).
- **Log Event**: A single log message with a timestamp (max 256 KB).

### Log Group Classes
- **Standard** (default): Full features -- Logs Insights, metric filters,
  subscription filters, Live Tail
- **Infrequent Access**: 50% lower ingestion cost, but no Logs Insights,
  metric filters, or subscription filters

### Naming Conventions
AWS services use predictable log group naming patterns. Our pipeline engine
relies on these for the log aggregator:

| Service | Log Group Pattern |
|---|---|
| Lambda | `/aws/lambda/FUNCTION_NAME` |
| Step Functions | `/aws/vendedlogs/states/STATE_MACHINE_NAME` |
| Glue | `/aws/glue/jobs/JOB_NAME` |
| EMR | `/aws/emr/CLUSTER_NAME` |
| SageMaker | `/aws/sagemaker/Endpoints/ENDPOINT_NAME` |
| Kinesis Firehose | `/aws/kinesisfirehose/STREAM_NAME` |
| Kinesis Analytics | `/aws/kinesis-analytics/APP_NAME` |
| MSK | `/aws/msk/CLUSTER_NAME` |
| Aurora | `/aws/rds/cluster/CLUSTER_NAME/TYPE` |
| Redshift | `/aws/redshift/cluster/CLUSTER_ID` |
| DMS | `/aws/dms/tasks/TASK_ID` |
| Athena | `/aws/athena/WORKGROUP_NAME` |

### Retention
Log retention is set per log group. Valid values: 1, 3, 5, 7, 14, 30, 60,
90, 120, 150, 180, 365, 400, 545, 731, 1096 (3 years), 1827 (5 years), up
to 3653 (10 years), or 0 (never expire). Our pipeline engine defaults to
7 days to minimize cost.

### CloudWatch Logs Insights
Interactive query language for searching and analyzing log data:
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

Key commands: `fields`, `filter`, `stats`, `sort`, `limit`, `parse`, `display`.
Supports aggregations (`count()`, `avg()`, `sum()`, `min()`, `max()`),
grouping (`by`), and time bucketing (`bin(5m)`).

### Subscription Filters
Stream log data in real-time to destinations:
- Kinesis Data Streams
- Kinesis Data Firehose
- Lambda
- OpenSearch Service

Maximum 2 subscription filters per log group.

### Metric Filters
Extract custom CloudWatch metrics from log data using filter patterns.
Up to 100 metric filters per log group.

---

## 6. CloudWatch Events (Pipeline Service Type)

In our pipeline engine, the "cloudwatch" service type creates CloudWatch Event
Rules for scheduled triggers. This is the same underlying service as
EventBridge (same API, same Terraform resources).

### How It Works in the Pipeline
1. The renderer creates an `aws_cloudwatch_event_rule` with a
   `schedule_expression` (default: `rate(5 minutes)`)
2. For each outgoing integration, it creates an `aws_cloudwatch_event_target`
3. If the target is Lambda, it also creates an `aws_lambda_permission`
   allowing `events.amazonaws.com` to invoke the function

### Difference from EventBridge Service Type
- **cloudwatch**: Defaults to `schedule_expression` (time-based triggers)
- **eventbridge**: Can use `schedule_expression` or `event_pattern`
  (event-driven triggers)
- Both produce identical Terraform resources

### Schedule Expressions
**Rate expressions**: `rate(5 minutes)`, `rate(1 hour)`, `rate(7 days)`
**Cron expressions**: `cron(0 12 * * ? *)` (daily at noon UTC)

Cron fields: minutes, hours, day-of-month, month, day-of-week, year.
Cannot specify both day-of-month AND day-of-week (one must be `?`).
All times are UTC.

---

## 7. CloudWatch Synthetics

Automated canary scripts that monitor endpoints and APIs for availability
and latency. Canaries run on a schedule and produce CloudWatch metrics,
logs, and screenshots.

### Use Cases
- Monitor HTTP endpoints for uptime
- Visual monitoring with screenshot comparison
- API endpoint testing with custom scripts
- Heartbeat monitoring (simple availability checks)

### Important Notes
- Synthetics is NOT free tier eligible
- Canaries need an IAM role and an S3 bucket for artifacts
- Runtime: Node.js-based (syn-nodejs-puppeteer-*)

---

## 8. Contributor Insights

Analyze log data to identify top contributors -- e.g., which IP addresses
generate the most errors, which API keys make the most requests, which
DynamoDB partition keys are hottest.

Built-in rules available for DynamoDB and VPC Flow Logs. Custom rules
can target any log group field.

---

## 9. IAM and Security

### CloudWatch Events Permissions
The events API uses the `events:` namespace (same as EventBridge):
- `events:PutRule`, `events:PutTargets`, `events:PutEvents`
- `events:DescribeRule`, `events:ListRules`, `events:ListTargetsByRule`

### CloudWatch Metrics Permissions
- `cloudwatch:PutMetricData` -- publish custom metrics
- `cloudwatch:GetMetricData` -- retrieve metric data
- `cloudwatch:PutMetricAlarm` -- create/update alarms

### CloudWatch Logs Permissions
Every compute service needs these in its IAM role:
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

The pipeline run monitor (`log_aggregator.py`) needs:
- `logs:FilterLogEvents`
- `logs:DescribeLogGroups`

### Encryption
- **Log groups**: Optionally encrypted with KMS customer-managed keys
  (Terraform attribute: `kms_key_id`)
- **Metrics**: Encrypted at rest with AWS-owned keys (no CMK option)

### ARN Formats
- Event rule: `arn:aws:events:REGION:ACCOUNT:rule/RULE_NAME`
- Alarm: `arn:aws:cloudwatch:REGION:ACCOUNT:alarm:ALARM_NAME`
- Dashboard: `arn:aws:cloudwatch::ACCOUNT:dashboard/DASHBOARD_NAME`
- Log group: `arn:aws:logs:REGION:ACCOUNT:log-group:GROUP_NAME`

---

## 10. Integration Patterns in Our Pipeline Engine

### CloudWatch as Service Type (Scheduled Triggers)

**CloudWatch -> Lambda**:
The CloudWatch renderer creates `aws_cloudwatch_event_rule` (with schedule),
`aws_cloudwatch_event_target` (Lambda ARN), and `aws_lambda_permission`
(principal: `events.amazonaws.com`). The statement_id includes the source
rule label to prevent collisions when multiple rules target the same Lambda.

**CloudWatch -> SQS**:
The renderer creates the rule and target. The SQS renderer creates
`aws_sqs_queue_policy` allowing `events.amazonaws.com` `SendMessage`.

### CloudWatch Logs as Infrastructure

Nearly every service renderer creates a CloudWatch log group:
```python
resource "aws_cloudwatch_log_group" "{label}_lg" {
  name              = "/aws/{service}/{resource_name}"
  retention_in_days = 7
  tags = { ... }
}
```

Services that configure native CloudWatch Logs:
Lambda, Step Functions, Glue, Glue DataBrew, EMR, EMR Serverless, SageMaker,
Kinesis Firehose, Kinesis Analytics, MSK, Aurora, Redshift, DMS, Athena.

Services monitored via CloudTrail instead (no native CW Logs):
S3, SQS, SNS, DynamoDB, EventBridge, CloudWatch rules, Kinesis Streams.

Services with no monitoring:
IAM, Lake Formation, Glue Data Catalog, QuickSight, EC2, SageMaker Notebook.

---

## 11. Terraform Resources

### Created by CloudWatch Renderer (Pipeline Service Type)
1. `aws_cloudwatch_event_rule` -- the schedule-based rule with tags
2. `aws_cloudwatch_event_target` -- one per target service
3. `aws_lambda_permission` -- when target is Lambda

### Created by Other Service Renderers
- `aws_cloudwatch_log_group` -- created by nearly every service renderer
- `aws_cloudwatch_metric_alarm` -- can be added for monitoring
- `aws_cloudwatch_dashboard` -- can be added for visualization
- `aws_cloudwatch_log_metric_filter` -- can be added for log-based metrics
- `aws_cloudwatch_log_subscription_filter` -- for log streaming

---

## 12. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `InvalidEventPatternException` | Bad event pattern JSON | Fix syntax, test with `test_event_pattern()` |
| `ResourceNotFoundException` (rule) | Rule doesn't exist | Verify name, run `put_rule()` to recreate |
| `ResourceAlreadyExistsException` (log group) | Log group exists | No action needed |
| `ResourceNotFoundException` (log group) | Log group missing | Create with `create_log_group()` or re-deploy |
| `LimitExceededException` (alarms) | >5000 alarms per account | Delete unused alarms or request increase |
| `InvalidParameterValueException` (retention) | Bad retention value | Use valid values (1,3,5,7,14,30,...) |
| `AccessDeniedException` (logs) | Missing log permissions | Add `logs:CreateLogGroup`, `logs:PutLogEvents` |
| `ThrottlingException` | API rate limit | Exponential backoff |

---

## 13. Monitoring in Our Pipeline

The Pipeline Run Preview feature relies heavily on CloudWatch Logs:

1. **Discovery**: `log_aggregator.py` reads `terraform.tfstate` to find
   deployed resources, then maps each service to its CloudWatch Log Group
   using `_LOG_GROUP_PATTERNS`
2. **Polling**: Every ~3 seconds, `FilterLogEvents` is called on all
   discovered log groups to fetch new events
3. **Streaming**: Events are merged chronologically and pushed via WebSocket
   to the browser

For services without native CloudWatch Logs (S3, SQS, DynamoDB, etc.),
CloudTrail `LookupEvents` is used instead (5-15 minute delay).

---

## 14. Best Practices

1. **Set retention on all log groups** -- our engine defaults to 7 days;
   production workloads may need longer
2. **Use metric filters** -- extract meaningful metrics from logs
   (error counts, latency percentiles)
3. **Set up alarms for critical metrics** -- Lambda errors, SQS queue
   depth, DynamoDB throttling
4. **Use composite alarms** -- reduce noise by combining conditions
5. **Use anomaly detection** -- for metrics with daily/weekly patterns
6. **Use Logs Insights** -- for ad-hoc investigation instead of
   downloading log files
7. **Consider Infrequent Access log groups** -- for logs you rarely query
   (50% ingestion savings)
8. **Set up dashboards** -- for operational visibility into pipelines
9. **Use embedded metric format** -- to publish metrics from Lambda
   without extra API calls
10. **Configure abort incomplete multipart upload** -- lifecycle rule on
    log export S3 buckets
