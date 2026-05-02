# Amazon EventBridge -- Complete Knowledge Base

> This document is the plain-English reference for EventBridge that the pipeline
> engine framework and developer agent can consult when handling any
> EventBridge-related request in a pipeline. It covers what EventBridge is, how
> it works, every feature, integration patterns, security, and troubleshooting.

---

## 1. What Is EventBridge?

Amazon EventBridge is a serverless event bus service that connects applications
using events. It was formerly known as CloudWatch Events and still uses the same
underlying API (`events` client in boto3, `aws_cloudwatch_event_rule` in
Terraform). EventBridge routes events from sources (AWS services, SaaS partners,
or your own applications) to targets based on rules you define.

### Core Concepts
- **Event**: A JSON object representing a state change or occurrence.
- **Event Bus**: A channel that receives events. The "default" bus gets all AWS
  service events. Custom buses isolate application-specific events.
- **Rule**: A filter that matches incoming events by pattern or fires on a
  schedule, then routes matched events to one or more targets.
- **Target**: The destination that processes the event (Lambda, SQS, SNS, Step
  Functions, Kinesis, ECS, API destinations, etc.).
- **Event Pattern**: A JSON structure that defines which events a rule matches.
- **Schedule Expression**: A `rate()` or `cron()` expression for time-based rules.

### Free Tier
All AWS service state-change events (e.g., EC2 state changes, S3 events routed
via EventBridge) are free. Custom events cost $1.00 per million events. Schema
discovery is free for 5 million ingested events/month during the first year.

### Relationship to CloudWatch Events
EventBridge IS CloudWatch Events with additional features (custom buses, SaaS
integrations, schema registry, Pipes). The API, Terraform resources, and ARN
format are the same (`events` namespace). In our pipeline engine, both
`eventbridge` and `cloudwatch` service types use `aws_cloudwatch_event_rule` as
the primary Terraform resource.

---

## 2. Event Buses

### Default Bus
Every AWS account has a "default" event bus. All AWS service events (EC2 state
changes, S3 events, CodePipeline state changes, etc.) are automatically
delivered to this bus. Your custom events can also be sent here.

### Custom Buses
Create custom event buses to isolate application events from AWS service noise.
Use cases include multi-tenant event routing, cross-account event sharing, and
domain-specific event channels.

### Partner Buses
SaaS partners (Datadog, Auth0, PagerDuty, Zendesk, etc.) can send events to
partner event buses. The partner creates an event source, and you accept it
from your console. Partner bus names follow the format
`aws.partner/PARTNER/EVENT_NAMESPACE`.

### Cross-Account Event Sharing
Events can be shared between AWS accounts using resource-based policies on event
buses. The source account creates a rule with a target pointing to the
destination account's event bus. The destination bus needs a resource policy
allowing the source account to call `events:PutEvents`.

### Cross-Region Routing
Events can be routed to another region by setting the target to an event bus
in that region. This costs $1.00 per million cross-region events and delivers
with at-least-once, eventually consistent semantics.

---

## 3. Rules

### Event Pattern Rules
Match events by content. You specify a JSON pattern that describes which
fields to match. The pattern is compared against the event JSON. Multiple
values in an array mean OR; multiple fields at the same level mean AND.

### Schedule Rules
Fire on a time-based schedule using `rate()` or `cron()` expressions:
- `rate(5 minutes)` -- every 5 minutes
- `rate(1 hour)` -- every hour
- `cron(0 12 * * ? *)` -- daily at noon UTC
- `cron(0 8 ? * MON-FRI *)` -- weekdays at 8 AM UTC

**Note**: For new scheduled workloads, AWS recommends EventBridge Scheduler
(a separate service with higher throughput, one-time schedules, timezone
support, and flexible time windows).

### Rule Limits
- Up to **300 rules** per event bus (adjustable via Service Quotas)
- Up to **5 targets** per rule (hard limit)
- Rule names: max 64 characters, alphanumeric plus `.`, `-`, `_`
- Rules are evaluated independently and concurrently
- An event can match multiple rules

### Rule States
- **ENABLED**: Active, matching events
- **DISABLED**: Exists but not matching

### Managed Rules
Rules with the `aws.` prefix are created by AWS services (e.g., AWS Health,
Config). They cannot be modified or deleted by users.

---

## 4. Event Patterns

Event patterns are JSON objects that define which events match a rule. They are
the core filtering mechanism in EventBridge.

### Pattern Structure
```json
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "detail": {
    "bucket": {
      "name": ["my-bucket"]
    }
  }
}
```

### Matching Operators
| Operator | Description | Example |
|---|---|---|
| Exact match | Value equals | `{"source": ["aws.s3"]}` |
| Prefix | Starts with | `{"prefix": "logs/"}` |
| Suffix | Ends with | `{"suffix": ".csv"}` |
| Anything-but | Does NOT match | `{"anything-but": "terminated"}` |
| Numeric | Comparison operators | `{"numeric": [">", 0, "<=", 100]}` |
| CIDR | IP address match | `{"cidr": "10.0.0.0/8"}` |
| Exists | Field present/absent | `{"exists": true}` |
| Wildcard | Glob matching | `{"wildcard": "*.json"}` |
| Equals-ignore-case | Case insensitive | `{"equals-ignore-case": "SUCCESS"}` |

### Combining Logic
- Multiple values in an array = **OR**: `{"source": ["aws.s3", "aws.ec2"]}`
- Multiple fields at the same level = **AND**: both must match
- Empty pattern `{}` matches ALL events (dangerous -- use with caution)

### Common AWS Event Patterns
- **S3 object created**: `{"source": ["aws.s3"], "detail-type": ["Object Created"]}`
- **EC2 state change**: `{"source": ["aws.ec2"], "detail-type": ["EC2 Instance State-change Notification"]}`
- **CodePipeline failure**: `{"source": ["aws.codepipeline"], "detail-type": ["CodePipeline Pipeline Execution State Change"], "detail": {"state": ["FAILED"]}}`
- **GuardDuty finding**: `{"source": ["aws.guardduty"], "detail-type": ["GuardDuty Finding"]}`

### Testing Patterns
Use `test_event_pattern()` API to validate a pattern against a sample event
without creating any rules. This is invaluable for debugging.

---

## 5. Targets

Each rule can have up to 5 targets. When an event matches a rule, EventBridge
delivers the event to all of the rule's targets.

### Supported Targets

| Target | Permissions Model | Role Required? | Notes |
|---|---|---|---|
| **Lambda** | Resource policy | No | `aws_lambda_permission` with `events.amazonaws.com` |
| **SQS** | Queue policy | No | Standard queues only (NOT FIFO) |
| **SNS** | Topic policy | No | Standard topics only |
| **Step Functions** | IAM role | Yes | `states:StartExecution` |
| **Kinesis Streams** | IAM role | Yes | `kinesis:PutRecord` |
| **Kinesis Firehose** | IAM role | Yes | `firehose:PutRecord` |
| **ECS Task** | IAM role | Yes | `ecs:RunTask` + `iam:PassRole` |
| **CodeBuild** | IAM role | Yes | `codebuild:StartBuild` |
| **CodePipeline** | IAM role | Yes | `codepipeline:StartPipelineExecution` |
| **Batch** | IAM role | Yes | `batch:SubmitJob` |
| **SSM Run Command** | IAM role | Yes | `ssm:SendCommand` |
| **CloudWatch Logs** | Resource policy | No | Log group resource policy |
| **API Destination** | Connection | N/A | External HTTP API via connection |
| **Event Bus** | IAM role | Yes | Cross-account/cross-region routing |
| **Redshift** | IAM role | Yes | Redshift Data API SQL |
| **SageMaker Pipeline** | IAM role | Yes | `sagemaker:StartPipelineExecution` |

### Input Transformation
Before delivering to a target, you can transform the event:
1. **Matched event** (default): Deliver the entire event as-is
2. **Constant JSON** (`Input`): Deliver a fixed JSON string
3. **Input path** (`InputPath`): Extract a portion via JSONPath
4. **Input transformer**: Template-based transformation using `input_paths_map`
   (extract variables) and `input_template` (compose output with `<variable>`
   placeholders)

### Retry Policy and Dead Letter Queue
- **Retry**: 0-185 attempts over up to 24 hours (default: 185 attempts, 24h)
- **DLQ**: Optional SQS queue for events that exhaust all retries
- Both are configured per-target in Terraform via `retry_policy` and
  `dead_letter_config` blocks

---

## 6. EventBridge Pipes

Pipes are point-to-point integrations that connect a source directly to a
target, optionally filtering and enriching events along the way. Unlike rules
(which match events on a bus), Pipes pull events from a source.

### Pipe Components
1. **Source**: DynamoDB Streams, Kinesis, SQS, MSK, or Amazon MQ
2. **Filtering** (optional): Event pattern filter (up to 5 patterns)
3. **Enrichment** (optional): Lambda, Step Functions, API Gateway, or API
   destination
4. **Target**: Same targets as EventBridge rules

### When to Use Pipes vs. Rules
- **Pipes**: Direct source-to-target, ordered processing, batching, no bus
  overhead
- **Rules**: Content-based routing, multiple targets, AWS service events,
  complex pattern matching

---

## 7. Archive and Replay

### Event Archiving
Store events from an event bus for later replay. You can filter which events
to archive using an event pattern. Archives are charged per GB stored per
month.

### Event Replay
Re-deliver archived events to the same event bus within a specified time range.
Replayed events include metadata identifying them as replays. Rules can filter
for or against replayed events.

**Constraints**:
- Maximum 20 archives per event bus
- Replay delivers to the SAME bus the events were archived from
- Replay rate is limited by regional throughput
- There is no Terraform resource for replays (API-only)

---

## 8. Schema Registry

EventBridge can automatically discover event schemas from events flowing
through a bus. Schemas are stored in a registry and can be used to generate
code bindings.

### Built-In Schemas
The `aws.events` registry contains schemas for all AWS service events. These
are automatically maintained by AWS.

### Schema Discovery
Enable a discoverer on an event bus to automatically infer schemas from events.
Cost: $0.10 per million ingested events (first 5M free/month for 12 months).

### Code Bindings
Generate language-specific code (Java, Python, TypeScript) from schemas for
type-safe event handling.

---

## 9. Schedules (EventBridge Scheduler)

EventBridge Scheduler is a separate (but related) service for running scheduled
tasks. It is recommended over rule-based schedules for new workloads.

### Advantages over Rule Schedules
- Higher throughput and scalability
- One-time schedules with `at(YYYY-MM-DDTHH:MM:SS)` expressions
- Flexible time windows (spread invocations over a window)
- Built-in timezone support (rule schedules are always UTC)
- More target types

### Terraform
- `aws_scheduler_schedule` -- the schedule itself
- `aws_scheduler_schedule_group` -- group schedules for management

---

## 10. IAM and Security

### EventBridge Is Passive
EventBridge itself does not have an execution role. It is not a "principal"
service. Instead:
- **Resource-based targets** (Lambda, SQS, SNS): The target service grants
  permission to `events.amazonaws.com` via its resource policy
- **IAM role targets** (Step Functions, Kinesis, ECS, etc.): EventBridge
  assumes an IAM role that you provide to invoke the target

### Key IAM Actions
| Category | Actions |
|---|---|
| Rules | `PutRule`, `DeleteRule`, `DescribeRule`, `EnableRule`, `DisableRule`, `ListRules` |
| Targets | `PutTargets`, `RemoveTargets`, `ListTargetsByRule` |
| Events | `PutEvents`, `PutPartnerEvents`, `TestEventPattern` |
| Buses | `CreateEventBus`, `DeleteEventBus`, `DescribeEventBus`, `PutPermission` |
| Archives | `CreateArchive`, `DeleteArchive`, `DescribeArchive`, `StartReplay` |

### ARN Formats
- Rule: `arn:aws:events:REGION:ACCOUNT:rule/[BUS_NAME/]RULE_NAME`
- Bus: `arn:aws:events:REGION:ACCOUNT:event-bus/BUS_NAME`
- Archive: `arn:aws:events:REGION:ACCOUNT:archive/ARCHIVE_NAME`
- Pipe: `arn:aws:pipes:REGION:ACCOUNT:pipe/PIPE_NAME`

### Encryption
- Events are encrypted at rest with AWS-owned keys by default
- Custom event buses can use customer-managed KMS keys
- All API calls use TLS 1.2+

---

## 11. Integration Patterns in Our Pipeline Engine

### EventBridge as Source (EventBridge triggers other services)

**EventBridge -> Lambda** (most common):
The EventBridge renderer creates `aws_cloudwatch_event_rule`,
`aws_cloudwatch_event_target`, and `aws_lambda_permission` (principal:
`events.amazonaws.com`, source_arn: rule ARN). The statement_id includes the
source rule label so multiple rules can target the same Lambda.

**EventBridge -> SQS**:
The EventBridge renderer creates the rule and target. The SQS renderer
creates `aws_sqs_queue_policy` allowing `events.amazonaws.com` to
`sqs:SendMessage`.

### EventBridge in Fan-Out Pattern

When multiple Lambda functions need to react to the same S3 event type, the
S3 renderer switches to EventBridge fan-out:
1. Enable `eventbridge = true` on `aws_s3_bucket_notification`
2. Create an `aws_cloudwatch_event_rule` per event pattern
3. Add each Lambda as a target on the rule

This avoids the S3 native notification limitation of one Lambda per event
type per prefix/suffix filter.

### EventBridge as Schedule Trigger

Schedule-based rules are commonly used to:
- Trigger periodic Lambda processing
- Start Step Functions workflows on a schedule
- Initiate batch processing at specific times

---

## 12. Terraform Resources

### Always Created by EventBridge Renderer
1. `aws_cloudwatch_event_rule` -- the rule (pattern or schedule) with tags
2. `aws_cloudwatch_event_target` -- one per target service

### Conditionally Created
- `aws_lambda_permission` -- when target is Lambda
- `aws_cloudwatch_event_bus` -- when using a custom bus
- `aws_cloudwatch_event_bus_policy` -- for cross-account sharing
- `aws_cloudwatch_event_archive` -- for event archiving
- `aws_cloudwatch_event_connection` -- for API destinations
- `aws_cloudwatch_event_api_destination` -- for external APIs
- `aws_pipes_pipe` -- for Pipes
- `aws_scheduler_schedule` -- for Scheduler

### Created by Other Renderers
- `aws_sqs_queue_policy` (SQS renderer) -- when EventBridge targets SQS
- `aws_s3_bucket_notification` (S3 renderer) -- when S3 events route via EB

---

## 13. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `ResourceNotFoundException` | Rule/bus/archive not found | Verify name, check terraform apply |
| `InvalidEventPatternException` | Bad pattern JSON | Fix syntax, test with `test_event_pattern()` |
| `ManagedRuleException` | Modifying AWS-managed rule | Cannot modify rules with `aws.` prefix |
| `LimitExceededException` (targets) | >5 targets per rule | Split into multiple rules or use fan-out |
| `LimitExceededException` (rules) | >300 rules per bus | Request quota increase or consolidate |
| `AccessDeniedException` | Missing IAM permissions | Add `events:PutRule`, `events:PutTargets`, etc. |
| `PolicyLengthExceededException` | Bus policy too large | Use org-level conditions instead of account lists |

---

## 14. Monitoring

EventBridge has no native CloudWatch Log Group of its own. In our pipeline
engine, EventBridge is monitored via **CloudTrail LookupEvents** filtered by
the rule ARN. This provides a 5-15 minute delivery delay.

CloudWatch Metrics for EventBridge (namespace `AWS/Events`):
- `Invocations` -- successful target invocations
- `FailedInvocations` -- target invocations that failed
- `MatchedEvents` -- events that matched at least one rule
- `TriggeredRules` -- rules that triggered
- `ThrottledRules` -- rules throttled due to limits
- `DeadLetterInvocations` -- events sent to DLQ

---

## 15. Best Practices

1. **Use the default bus for AWS service events** -- do not create custom buses
   for AWS-originated events
2. **Use custom buses for application events** -- isolate your events from AWS
   noise
3. **Keep event patterns specific** -- avoid empty patterns (`{}`) that match
   everything
4. **Set up DLQs** -- configure dead letter queues for critical targets
5. **Use input transformers** -- send only relevant fields to targets
6. **Test patterns before deploying** -- use `test_event_pattern()` API
7. **Monitor FailedInvocations** -- set CloudWatch alarms on this metric
8. **Consider EventBridge Scheduler** -- for new time-based workloads
9. **Use Pipes for point-to-point** -- when you do not need event bus features
10. **Archive important events** -- for replay capability and audit
