# AWS Glue DataBrew -- Complete Knowledge Base

> This document is the plain-English reference for AWS Glue DataBrew that the
> pipeline engine framework and developer agent can consult when handling any
> DataBrew-related request in a pipeline. It covers what DataBrew is, how
> projects/datasets/recipes/jobs work, all integration patterns, and
> troubleshooting.

---

## 1. What Is AWS Glue DataBrew?

AWS Glue DataBrew is a visual data preparation tool that lets you clean and
normalize data **without writing code**. It provides 250+ built-in
transformations that you arrange as "recipe steps." DataBrew also offers data
profiling to understand data quality, distribution, and PII content.

### Core Concepts

- **Dataset**: A reference to your data (S3 path, Glue Catalog table, or
  database table). The dataset itself does not contain data -- it points to it.
- **Project**: Binds a dataset to a recipe for interactive data preparation.
  Opening a project starts a session with a sample of your data.
- **Recipe**: An ordered list of transformation steps. Recipes are versioned;
  you edit a "working" version and then publish it as an immutable numbered
  version.
- **Job**: Applies a published recipe to a full dataset (recipe job) or
  generates a statistical profile (profile job). Jobs run on managed compute.
- **Schedule**: Cron-based recurring execution of jobs.
- **Ruleset**: Data quality rules evaluated during job execution.

### Pricing (No Free Tier)

DataBrew has **no free tier**. Billing:
- Interactive sessions: ~$0.48 per node-hour
- Recipe/profile jobs: ~$0.48 per node-hour
- Minimum 3 nodes per job
- Typical minimum cost: ~$1.44/hour per running job

---

## 2. Datasets

A dataset is a named reference to data in S3, Glue Data Catalog, or a database.
Datasets are reusable across projects and jobs.

### Input Types

| Source | Description |
|---|---|
| **S3** | Direct S3 path (bucket + key prefix) |
| **Glue Data Catalog** | Reference to a catalog database/table |
| **Database** | JDBC connection to RDS, Redshift, etc. |

### Supported Formats

| Format | Options |
|---|---|
| CSV | delimiter, header_row |
| JSON | multi_line |
| Parquet | (auto-detected) |
| ORC | (auto-detected) |
| Excel | sheet_names, sheet_indexes, header_row |

### Path Options

Datasets can filter input files by:
- Last modified date (process only recent files)
- Files limit (cap number of files)
- Path parameters (dynamic partitioning)

### Limits

- Max columns per dataset: 2,000
- Max dataset size for interactive sessions: 20 GB
- Max datasets per account: 100

---

## 3. Projects

A project binds a dataset to a recipe. When you open a project, DataBrew starts
an interactive session where you can preview transformations on a sample of
your data.

### Sample Types

| Type | Description |
|---|---|
| FIRST_N | First N rows |
| LAST_N | Last N rows |
| RANDOM | Random sample of N rows |

Default sample size: 500 rows.

### Session Behavior

- Sessions auto-terminate after 60 minutes of idle time
- Sessions use managed compute (no infrastructure to manage)
- Each session costs ~$0.48/node-hour

---

## 4. Recipes

A recipe is a set of ordered transformation steps. Recipes are the core unit of
data preparation logic in DataBrew.

### Recipe Versioning

- **Working version**: The editable draft. Modify with `update_recipe()`.
- **Published version**: Immutable numbered version. Create with `publish_recipe()`.
- You **must publish** a recipe version before a recipe job can use it.
- Max 100 versions per recipe.

### Transformation Categories

DataBrew provides 250+ built-in transformations organized into categories:

**Column Operations**: DELETE, RENAME, DUPLICATE, MOVE, CHANGE_DATA_TYPE,
MERGE, SPLIT, NEST, UNNEST, FLAG

**String Operations**: UPPER_CASE, LOWER_CASE, TRIM, PAD, REMOVE_WHITESPACE,
REMOVE_SPECIAL_CHARACTERS, REPLACE_VALUE, REGEX_REPLACE, SUBSTRING,
EXTRACT_PATTERN

**Number Operations**: ROUND, FLOOR, CEIL, ABS, LOG, SQRT, POWER,
MATH_EXPRESSION

**Date Operations**: DATE_FORMAT, DATE_ADD, DATE_DIFF, EXTRACT_DATE_PART,
CONVERT_TIMEZONE

**Data Quality**: FILL_MISSING_VALUES, REMOVE_DUPLICATES, REMOVE_OUTLIERS,
REMOVE_NULL_ROWS, VALIDATE_DATA

**Aggregation**: GROUP_BY, PIVOT, UNPIVOT, ROLLING_WINDOW

**Filtering**: FILTER_ROWS, FILTER_VALUES, TOP_N, BOTTOM_N, SAMPLE

**Joining**: JOIN, UNION

**Encoding**: ONE_HOT_ENCODING, ORDINAL_ENCODING, BINARY_ENCODING

**Custom**: CUSTOM_SQL, CUSTOM_FUNCTION

### Recipe Step Structure

Each step has:
```json
{
  "Action": {
    "Operation": "UPPER_CASE",
    "Parameters": {
      "sourceColumn": "name"
    }
  },
  "ConditionExpressions": []
}
```

---

## 5. Jobs

### Recipe Jobs

Apply a published recipe to a full dataset and write results to a destination.

**Output Destinations**:
- S3 (CSV, JSON, Parquet, Avro, ORC, XML, Tableau Hyper, Glue Parquet)
- Glue Data Catalog table
- Database table (via JDBC connection)

**Output Compression**: GZIP, LZ4, SNAPPY, BZIP2, DEFLATE, LZO, BROTLI,
ZSTD, ZLIB

**Overwrite**: Can overwrite existing output files.

### Profile Jobs

Analyze a dataset and generate statistics stored as JSON in S3.

**Statistics Generated**:
- Dataset level: row count, column count, duplicate rows
- Column level: data types, null percentage, unique values, min/max/mean/median,
  most common values, string length distribution, pattern detection
- Entity detection: PII (email, phone, SSN, credit card, etc.)

### Job Configuration

- Min nodes: 3 (max_capacity)
- Max nodes: 90
- Worker type: T_2 (2 vCPU, 16 GB RAM)
- Max retries: configurable
- Timeout: up to 2,880 minutes (48 hours)
- Log subscription: ENABLE or DISABLE

### Scheduling

Jobs can be scheduled with cron expressions:
```
cron(0 * * * ? *)     -- every hour
cron(0 6 * * ? *)     -- daily at 6 AM UTC
```

---

## 6. Integration Patterns

### DataBrew in the Pipeline Engine

The DataBrew renderer creates:
1. `aws_cloudwatch_log_group` -- for DataBrew job logs
2. `aws_iam_role` + `aws_iam_role_policy` -- execution role
3. `aws_databrew_dataset` -- with S3 input from integrations
4. `aws_databrew_project` -- binding dataset + recipe
5. `aws_databrew_job` -- profile job with output location

### How DataBrew Connects to Other Services

| Integration | Direction | Who Owns Wiring | IAM on DataBrew |
|---|---|---|---|
| S3 -> DataBrew | DataBrew reads input | DataBrew (dataset) | s3:GetObject, s3:ListBucket |
| DataBrew -> S3 | DataBrew writes output | DataBrew (job output) | s3:PutObject, s3:ListBucket |
| DataBrew -> DynamoDB | DataBrew writes output | DataBrew | dynamodb:PutItem, BatchWriteItem |
| DataBrew -> Redshift | DataBrew writes output | DataBrew | redshift:DescribeClusters |
| DataBrew -> Glue Catalog | Read schema/write tables | DataBrew | glue:GetTable, CreateTable |
| Step Functions -> DataBrew | SF starts DataBrew job | Step Functions | databrew:StartJobRun |
| Lambda -> DataBrew | Lambda starts job | Lambda | databrew:StartJobRun |

### Common Pipeline Patterns

1. **S3 -> DataBrew -> S3**: Raw data in, clean data out. Most common pattern.
2. **S3 -> Glue Crawler -> DataBrew**: Crawler catalogs data, DataBrew uses
   catalog as dataset source.
3. **DataBrew -> Athena**: DataBrew writes Parquet to S3, Athena queries it.
4. **S3 -> DataBrew (profile) -> S3**: Data quality assessment before ETL.

---

## 7. IAM Permissions

### DataBrew Execution Role

Every DataBrew project and job needs an IAM role with `databrew.amazonaws.com`
as the service principal.

**Always required** (from spec):
- CloudWatch Logs: `logs:CreateLogGroup`, `logs:CreateLogStream`,
  `logs:PutLogEvents`
- Glue Catalog: `glue:GetDatabase`, `glue:GetTable`, `glue:CreateTable`,
  `glue:UpdateTable`

**Additional based on integrations**:
- S3 input: `s3:GetObject`, `s3:ListBucket`
- S3 output: `s3:PutObject`, `s3:GetBucketLocation`
- DynamoDB output: `dynamodb:PutItem`, `dynamodb:BatchWriteItem`
- Redshift output: `redshift:DescribeClusters`,
  `redshift:GetClusterCredentials`, `redshift-data:ExecuteStatement`

### PassRole

The user or service starting a DataBrew job needs `iam:PassRole` permission for
the DataBrew execution role.

---

## 8. Monitoring and Logging

### CloudWatch Logs

DataBrew job logs are written to CloudWatch when log subscription is enabled.
Log group pattern: `/aws-glue-databrew/jobs/{job_name}`

### CloudWatch Metrics

Key metrics:
- Job duration
- Records processed
- Bytes read/written
- Errors

### Pipeline Run Monitor

The pipeline log aggregator monitors DataBrew via CloudWatch Logs at
`/aws-glue-databrew/jobs/{resource_name}`.

---

## 9. Quotas and Limits

| Resource | Default Limit |
|---|---|
| Projects per account | 100 |
| Datasets per account | 100 |
| Recipes per account | 100 |
| Recipe versions per recipe | 100 |
| Recipe steps per recipe | 100 |
| Jobs per account | 100 |
| Concurrent job runs | 10 |
| Schedules per account | 10 |
| Rulesets per account | 100 |
| Rules per ruleset | 100 |
| Columns per dataset | 2,000 |
| Dataset size (interactive) | 20 GB |

---

## 10. Common Errors and Troubleshooting

### AccessDenied on S3
**Cause**: DataBrew role lacks S3 permissions for input or output bucket.
**Fix**: Add `s3:GetObject`, `s3:ListBucket`, `s3:PutObject` to the role.

### EntityNotFoundException
**Cause**: Dataset, recipe, or job not found.
**Fix**: Verify resource names. Check if terraform apply completed successfully.

### ConflictException (published recipe)
**Cause**: Attempting to modify a published recipe version.
**Fix**: Edit the working version, then publish a new version.

### FAILED Job Run
**Cause**: Various -- check CloudWatch Logs for details.
**Fix**: Review logs at `/aws-glue-databrew/jobs/{job_name}`. Common causes:
input data format mismatch, S3 permissions, recipe step errors.

### ServiceQuotaExceededException
**Cause**: Account quota exceeded.
**Fix**: Request a quota increase via AWS Service Quotas.

---

## 11. Best Practices

1. **Always publish recipes** before creating recipe jobs
2. **Use PROFILE jobs** first to understand data quality before transforming
3. **Start with 3 nodes** (minimum) and scale up if jobs are slow
4. **Use Parquet output** for downstream analytics (Athena, Redshift Spectrum)
5. **Enable log subscription** for debugging job failures
6. **Version recipes** to track transformation changes over time
7. **Use path options** to filter input files by date for incremental processing
8. **Test with interactive sessions** before running full dataset jobs

---

## 12. Developer Agent: Working with DataBrew

### Updating Recipe Steps
```python
databrew = boto3.client('databrew', region_name=region)

# Get current recipe
recipe = databrew.describe_recipe(Name=resource_name)
steps = recipe['Steps']

# Add a new transformation step
steps.append({
    'Action': {
        'Operation': 'UPPER_CASE',
        'Parameters': {'sourceColumn': 'customer_name'}
    }
})

# Update working version
databrew.update_recipe(Name=resource_name, Steps=steps)

# Publish for job use (REQUIRED before job can use it)
databrew.publish_recipe(Name=resource_name)
```

### Starting a Job Run
```python
response = databrew.start_job_run(Name=job_name)
run_id = response['RunId']

# Poll for completion
while True:
    run = databrew.describe_job_run(Name=job_name, RunId=run_id)
    if run['State'] in ['SUCCEEDED', 'FAILED', 'STOPPED', 'TIMEOUT']:
        break
    time.sleep(30)
```

### Creating a Profile Job
```python
databrew.create_profile_job(
    Name=f'{resource_name}-profile',
    DatasetName=resource_name,
    RoleArn=role_arn,
    OutputLocation={'Bucket': output_bucket, 'Key': 'profiles/'},
    Configuration={
        'EntityDetectorConfiguration': {
            'EntityTypes': ['USA_ALL'],
            'AllowedStatistics': [{'Statistics': ['ALL']}]
        }
    }
)
```
