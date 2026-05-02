# Demo Video Script — AWS Pipeline Engine
## Total Runtime: ~5 minutes
---

## PART 1 — TOOL EXPLANATION & FRAMEWORK OVERVIEW
### (~3 min, record as slides or talking-head)

---

### SLIDE 1 — Title (0:00–0:15)
**Visual:** Tool name + tagline

> "Hi — in the next 5 minutes I'm going to show you the AWS Pipeline Engine:
> a framework that converts an AWS architecture into fully validated,
> deployable Terraform — automatically, with zero manual HCL writing."

---

### SLIDE 2 — The Problem (0:15–0:50)
**Visual:** Two columns: "Traditional Way" vs "This Tool"

> "Building AWS data pipelines the traditional way means writing Terraform by
> hand — IAM roles, policies, bucket notifications, event source mappings,
> CloudWatch log groups — for every single service. It's repetitive,
> error-prone, and slow. You spend hours getting IAM permissions right,
> and a small typo can break a deploy 30 minutes into terraform apply.
>
> This tool eliminates all of that. You describe your pipeline — what services
> you want and how they connect — and the engine generates the complete,
> correct Terraform for you. In under a second."

---

### SLIDE 3 — Two Ways to Use It (0:50–1:20)
**Visual:** Two input paths with icons

> "There are two ways to give the tool your pipeline design.
>
> Option one: write a simple YAML file. You list your services and your
> integrations. No Terraform knowledge required. The YAML is intentionally
> readable — a junior engineer or even a data scientist can write it.
>
> Option two: take a screenshot or photo of an AWS architecture diagram —
> something you drew in draw.io, Lucidchart, or on a whiteboard — and drop
> it into the tool. One Claude Vision call reads the diagram and converts it
> to the same YAML format automatically. After that, zero LLM calls."

---

### SLIDE 4 — What Gets Generated (1:20–2:00)
**Visual:** YAML on the left, HCL on the right, with a list of auto-generated items

> "From that simple YAML, the engine produces production-ready Terraform HCL.
> Not just the main resources — everything:
>
> - IAM roles and least-privilege policies, computed from your integration graph
> - Environment variables auto-wired between services — for example, when a
>   Lambda writes to SQS, the queue URL is automatically injected as an env var
> - S3 bucket notifications, SQS event source mappings, Lambda permissions
> - CloudWatch log groups for every service
> - VPC placement triggered automatically when services like Aurora or Redshift
>   are in the pipeline
> - Cost-safe defaults — every service defaults to the smallest free-tier
>   or minimum-cost instance type
>
> 27 AWS service types are supported today — S3, Lambda, SQS, SNS, DynamoDB,
> Step Functions, Glue, EMR, EMR Serverless, Kinesis, SageMaker, Redshift,
> Aurora, MSK, Athena, and more."

---

### SLIDE 5 — The Framework Architecture (2:00–2:45)
**Visual:** Architecture diagram (flowchart)

```
YAML / Diagram Image
        │
        ▼
  Spec Loader          ← reads specs/<service>.yaml (knowledge base)
        │
        ▼
  Spec Builder         ← computes IAM, env vars, VPC from integration graph
        │
        ▼
  HCL Renderer         ← golden templates, one per service type
        │
        ▼
  HCL Linter           ← validates cross-references in <50ms
        │
        ▼
  main.tf              ← ready to deploy
```

> "The core idea is: AWS service configurations are known, documented, and
> static. You don't need an LLM to figure out that a Lambda reading from S3
> needs s3:GetObject and s3:ListBucket. That knowledge lives in a YAML spec
> file — once — and the engine applies it to every pipeline automatically.
>
> The process is: load the spec for each service type, compute the full
> blueprint from the integration graph, render it through a golden HCL
> template, lint the result for broken references, and write the file.
> The whole thing runs in under one second for a 15-service pipeline."

---

### SLIDE 6 — Key Design Principles (2:45–3:10)
**Visual:** 3 bullet points

> "Three principles make this reliable:
>
> One — specs hold the knowledge, not prompts. IAM permissions are a table
> lookup, not an LLM judgment. This is why they're always correct.
>
> Two — the linter runs before Terraform. Cross-references are validated in
> Python in 50 milliseconds, catching the same class of errors as
> terraform validate — but without the 30-second terraform init overhead.
>
> Three — free-tier by default. Every service defaults to the smallest
> viable size. A warning comment is emitted in the HCL for any service
> that is never free-tier, so you always know what you're spending."

---

## PART 2 — LIVE DEMO (screen recording)
### (~2 min, record your screen)

---

### DEMO STEP 1 — Show the YAML (0:00–0:30)
**Action:** Open `examples/simple_ingest.yaml` in your editor

> "Here's a simple pipeline — an S3 bucket triggers a Lambda, which writes
> to an SQS queue. Three services, two integrations. That's all you write."

```yaml
pipeline_name: simple_ingest
business_unit: analytics
cost_center: cc001
region: us-east-1

services:
  - name: ingest_bucket
    type: s3

  - name: processor_fn
    type: lambda
    config:
      runtime: python3.12
      handler: handler.process
      memory_size: 128
      timeout: 30

  - name: result_queue
    type: sqs

integrations:
  - source: ingest_bucket
    target: processor_fn
    event: "s3:ObjectCreated:*"

  - source: processor_fn
    target: result_queue
    event: send_message
```

---

### DEMO STEP 2 — Run the Engine (0:30–1:00)
**Action:** Run in terminal

```bash
python main.py examples/simple_ingest.yaml --dry-run
```

> "I'll run it with --dry-run so the HCL prints to the terminal.
> Watch how fast this is — no network calls, no LLM, just pure computation."

**Point out in the output:**
- IAM role + policy for Lambda
- `RESULT_QUEUE_QUEUE_URL` env var auto-injected
- `aws_s3_bucket_notification` wiring S3 → Lambda
- `aws_lambda_event_source_mapping` wiring SQS → Lambda
- `aws_cloudwatch_log_group` for Lambda

---

### DEMO STEP 3 — Show the Complex Example (1:00–1:30)
**Action:** Open `examples/data_processing_pipeline.yaml`

```bash
python main.py examples/data_processing_pipeline.yaml --dry-run
```

> "Here's a 15-service, two-stage pipeline — raw ingestion through Step
> Functions into staging, then CloudWatch-scheduled analytics through Glue
> into a final bucket. Same command. Still under a second."

---

### DEMO STEP 4 — Web UI (1:30–2:00)
**Action:** Open browser to http://localhost:8000

> "There's also a web interface — upload an architecture diagram image,
> and it converts and builds the pipeline live, streaming every step to
> the browser. You can monitor the pipeline run in real time after deploy,
> and use the developer agent to generate boto3 code against live services."

---

## RECORDING TIPS

- **Resolution:** 1920×1080, font size 16+ in terminal
- **Terminal theme:** Dark background for contrast
- **Before recording:** Run `python main.py examples/simple_ingest.yaml --dry-run` once so there's no cold-start delay
- **Slide tool:** Google Slides, Keynote, or even a terminal with big text works
- **Pacing:** Pause 1–2 seconds after each key point — don't rush the IAM/env var callouts

---

## ONE-LINER SUMMARY (for video description)

> "AWS Pipeline Engine — describe your data pipeline in YAML, get production-ready
> Terraform HCL with IAM, env vars, and wiring computed automatically.
> 27 AWS services. Zero manual HCL. Under one second."
