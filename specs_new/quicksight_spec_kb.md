# Amazon QuickSight — Complete Knowledge Base

> This document is the plain-English reference for QuickSight that the pipeline
> engine framework and developer agent can consult when handling any
> QuickSight-related request in a pipeline. It covers what QuickSight is, how
> it works, data sources, datasets, dashboards, embedding, and troubleshooting.

---

## 1. What Is QuickSight?

Amazon QuickSight is a serverless business intelligence (BI) and data
visualization service. It connects to your data sources (Athena, S3, Redshift,
Aurora, and many others), lets you build interactive analyses with charts and
tables, and publishes them as shareable dashboards.

### Core Concepts
- **Data Source**: A connection definition to an external data store (Athena
  workgroup, S3 bucket, Redshift cluster, Aurora database, etc.)
- **Dataset**: A prepared view of data from one or more data sources, with
  optional joins, calculated fields, and filters. Can be imported into SPICE
  (in-memory) or queried directly.
- **Analysis**: The authoring workspace where you build visualizations. Contains
  sheets (tabs) with visuals (charts, tables, KPIs).
- **Dashboard**: A published, read-only version of an analysis. Shared with
  readers via QuickSight, email, or embedding.
- **SPICE**: Super-fast, Parallel, In-memory Calculation Engine — QuickSight's
  columnar in-memory store for fast queries.

### Cost Warning — NEVER Free Tier
QuickSight has **NO** free tier. Standard Edition costs $9/month per author.
Readers pay $0.30 per session (capped at $5/month). Enterprise Edition is
$18/month per author. SPICE capacity: 10 GB per user included, additional at
$0.25-0.38/GB/month.

### Prerequisite
QuickSight must be set up in your AWS account before Terraform can create any
resources. This is a one-time step done via the console
(QuickSight -> Sign up for QuickSight) or the `create_account_subscription` API.

---

## 2. How Our Pipeline Engine Renders QuickSight

The renderer (`_render_quicksight`) creates these Terraform resources:

1. **IAM role** — assumed by `quicksight.amazonaws.com`, with an inline policy
   for data access permissions based on integrations.
2. **Data source** — `aws_quicksight_data_source` with type and parameters
   auto-detected from the pipeline integration graph.

### Auto-Detection of Data Source Type
The renderer walks `integrations_as_target` and finds the first recognized peer
type. The mapping:

| Peer Type | QuickSight Data Source Type |
|---|---|
| `athena` | ATHENA |
| `glue_data_catalog` | ATHENA (queries Glue via Athena) |
| `s3` | S3 |
| `redshift` | REDSHIFT |
| `aurora` | AURORA_POSTGRESQL |

If no peer is found, the default is ATHENA with the "primary" workgroup.

### Parameter Blocks by Type
- **ATHENA**: `parameters { athena { work_group = "..." } }`
- **S3**: `parameters { s3 { manifest_file_location { bucket = "...", key = "..." } } }`
- **REDSHIFT**: `parameters { redshift { cluster_id = "...", database = "..." } }`
- **AURORA**: `parameters { rds_parameters { instance_id = "...", database = "..." } }`

SSL is always enabled (`ssl_properties { disable_ssl = false }`).

---

## 3. Editions

### Standard ($9/author/month)
- SPICE in-memory engine
- AutoGraph (automatic visual type selection)
- Calculated fields and conditional formatting
- Email reports and data alerts
- **Missing**: Row/column-level security, VPC connectivity, AD integration

### Enterprise ($18/author/month)
- All Standard features plus:
- Row-level and column-level security
- VPC connectivity (access private databases)
- Active Directory / SAML / IAM federation
- Encrypted SPICE (SSE at rest, optional CMK)
- ML Insights (anomaly detection, forecasting, narratives)
- API access for embedding
- Hourly SPICE refresh (vs. daily in Standard)
- Paginated reports (PDF generation)
- Anonymous embedding (pay-per-session, no login)

---

## 4. Data Sources

A data source is a connection to where your data lives. Our pipeline engine
supports four source types:

### ATHENA (Most Common)
Queries data in S3 via the Athena SQL engine and Glue Data Catalog:
- Connect to an Athena workgroup
- Tables defined in Glue Data Catalog
- Data stored in S3 (Parquet, CSV, JSON, etc.)
- **Permissions needed**: Athena query execution, Glue catalog read, S3 read

### S3 (Direct)
Read data files directly from S3 via a manifest file:
- Manifest JSON defines file URIs and format settings
- Supports CSV, TSV, JSON, ELF (log), CLF (log)
- **Permissions needed**: S3 read on bucket

### REDSHIFT
Connect to a Redshift cluster:
- Specify cluster ID and database name
- Authentication via database credentials or IAM
- **VPC required** — triggers VPC placement in our pipeline engine
- **Permissions needed**: Redshift credentials, cluster describe

### AURORA (PostgreSQL/MySQL)
Connect to an Aurora cluster:
- Specify cluster endpoint and database name
- Authentication via database credentials
- **VPC required** — triggers VPC placement
- **Permissions needed**: RDS describe, Secrets Manager for credentials

### Additional Types (Not in Renderer)
QuickSight also supports: MySQL, PostgreSQL, MariaDB, SQL Server, Oracle,
Presto, Spark, Snowflake, Databricks, Timestream, Twitter, Jira, Salesforce,
ServiceNow, and more. These would need renderer additions.

---

## 5. Datasets

A dataset sits between the data source and the analysis. It defines what data
to use and how to prepare it.

### Import Modes

**SPICE** (recommended for most cases):
- Data imported into QuickSight's in-memory engine
- Fast query performance regardless of source
- Refresh manually or on schedule (daily in Standard, hourly in Enterprise)
- 10 GB per user included, expandable
- Max 500 million rows per dataset

**DIRECT_QUERY**:
- Every user interaction queries the live source
- Real-time data (no stale cache)
- Performance depends on the source database
- Puts load on the source system
- Use when data changes frequently and must be live

### Calculated Fields
Computed columns using QuickSight expressions:
- Aggregation: `sum`, `avg`, `min`, `max`, `count`, `distinct_count`
- String: `concat`, `substring`, `trim`, `toLower`, `toUpper`
- Date: `extract`, `addDateTime`, `dateDiff`, `truncDate`
- Conditional: `ifelse`, `coalesce`, `nullIf`
- Math: `ceil`, `floor`, `round`, `log`, `sqrt`

Up to 500 calculated fields per dataset.

### Joins
- Up to 32 tables per dataset
- Join types: INNER, LEFT, RIGHT, FULL
- Defined in `LogicalTableMap` via `JoinInstruction`

---

## 6. Analyses and Dashboards

### Analyses (Authoring)
The workspace where you build visualizations:
- Up to 20 sheets (tabs) per analysis
- Up to 30 visuals per sheet
- Up to 100 parameters per analysis
- Up to 20 filters per analysis

### Visual Types
Bar charts, line charts, scatter plots, pie/donut charts, pivot tables, tables,
KPIs, gauges, tree maps, heat maps, histograms, box plots, waterfall charts,
funnel charts, Sankey diagrams, combo charts, geospatial maps, filled maps,
word clouds, and ML-generated insight narratives.

### Dashboards (Published)
- Read-only published version of an analysis
- Each publish creates a new version (can roll back)
- Share with QuickSight users/groups
- Schedule email delivery (PDF/CSV)
- Embed in web applications

---

## 7. SPICE

### What It Is
SPICE (Super-fast, Parallel, In-memory Calculation Engine) is QuickSight's
columnar in-memory data store. When you import data into SPICE, queries run
against the in-memory copy rather than the source, providing fast response
times.

### Capacity
- 10 GB per user included with subscription
- Additional: $0.25/GB/month (Standard), $0.38/GB/month (Enterprise)
- Shared across all datasets in the account

### Refresh
- **Manual**: Via console or API (`create_ingestion`)
- **Scheduled**: Daily (Standard), hourly minimum (Enterprise)
- **Incremental**: Only new/modified data (Enterprise, requires date column)
- **Full**: Re-ingest all data

### Limits
- Max 2,000 columns per dataset
- Max 500 million rows per dataset
- Max 500 GB per dataset
- Max 2 MB per row
- Max 131,072 characters per field

### Encryption
- Standard: AWS-managed encryption at rest
- Enterprise: Optional customer-managed KMS key

---

## 8. Embedding

QuickSight dashboards can be embedded in external web applications:

### Authenticated Embedding
1. User authenticates to your application
2. Backend assumes IAM role, calls `get_dashboard_embed_url`
3. Backend returns URL to frontend
4. Frontend loads URL in an iframe

### Anonymous Embedding (Enterprise Only)
1. No user login required
2. Backend calls `generate_embed_url_for_anonymous_user`
3. Cost: $0.30 per 30-minute session (capped at $5/reader/month)

### Embedding SDK
JavaScript SDK (`amazon-quicksight-embedding-sdk`) provides:
- Parameter passing to dashboards
- Event handling (visual selected, filter changed)
- Resize handling
- Theme customization

---

## 9. IAM Permissions

### QuickSight Service Role
Our renderer creates an IAM role assumed by `quicksight.amazonaws.com` for
accessing data sources.

### Always-Required Permissions
```
quicksight:CreateDataSource, DescribeDataSource, UpdateDataSource, DeleteDataSource
quicksight:CreateDataSet, DescribeDataSet, UpdateDataSet, DeleteDataSet
quicksight:PassDataSet, PassDataSource
```

### Data Source Access Permissions

**For ATHENA source**:
```
athena:StartQueryExecution, GetQueryExecution, GetQueryResults, GetWorkGroup
glue:GetDatabase, GetDatabases, GetTable, GetTables, GetPartition, GetPartitions
s3:GetObject, ListBucket, GetBucketLocation, PutObject (for query results)
```

**For S3 source**:
```
s3:GetObject, ListBucket, GetBucketLocation
```

**For REDSHIFT source**:
```
redshift:GetClusterCredentials, DescribeClusters, DescribeClusterSubnetGroups
```

**For AURORA source**:
```
rds:DescribeDBInstances, DescribeDBClusters
secretsmanager:GetSecretValue
```

### QuickSight-Level Permissions
QuickSight has its own permission system separate from IAM. Resources (data
sources, datasets, analyses, dashboards) have permission lists that grant
QuickSight-specific actions to QuickSight principals (users/groups).

---

## 10. Users and Groups

### User Roles
- **ADMIN**: Full management access
- **AUTHOR**: Create/edit analyses, dashboards, datasets ($9-18/month)
- **READER**: View dashboards only ($0.30/session, max $5/month)

### Identity Types
- **IAM**: Federated from IAM users/roles (Standard + Enterprise)
- **QUICKSIGHT**: Native email/password users
- **ACTIVE_DIRECTORY**: Enterprise only
- **SAML**: Enterprise only

### Namespaces
Logical isolation of users within an account. Use for multi-tenant SaaS apps.

---

## 11. VPC Configuration

QuickSight can connect to data sources in private VPCs (Enterprise only):
- Create a VPC connection in QuickSight
- Specify security groups and subnets
- QuickSight creates ENIs in your VPC

Our pipeline engine triggers VPC placement when QuickSight integrates with:
- **Redshift** (cluster in VPC)
- **Aurora** (cluster in VPC)

---

## 12. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `QuickSight not subscribed` | Account not set up | Sign up in console or call create_account_subscription |
| `AccessDeniedException` | IAM or QuickSight permissions missing | Check IAM role + QuickSight permissions |
| `DataSourceConnection Failed` | Cannot reach data source | Check security groups, VPC, credentials |
| `SPICE capacity exceeded` | Out of SPICE storage | Purchase more SPICE capacity |
| `IngestionFailed` | SPICE refresh failed | Check data format, source availability |
| `InvalidParameterValue (DataSourceParameters)` | Wrong connection params | Verify workgroup, bucket, cluster ID |
| `ConflictException already exists` | Resource ID collision | Use unique IDs or import to state |
| `ThrottlingException` | API rate limit | Exponential backoff |

### Prerequisite Errors
The most common error is trying to create QuickSight Terraform resources before
the account is subscribed. QuickSight requires a one-time account setup before
any resources can be created. This is done via the console or
`create_account_subscription` API.

---

## 13. Integration Patterns in Our Pipeline Engine

### Athena -> QuickSight (Most Common)
QuickSight creates an ATHENA data source pointing to the Athena workgroup.
Data lives in S3, cataloged in Glue, queried via Athena, visualized in
QuickSight.

### S3 -> QuickSight (Direct)
QuickSight reads data directly from S3 via manifest files. Best for simple
CSV/JSON datasets that don't need SQL querying.

### Glue Data Catalog -> QuickSight
Treated as ATHENA type — QuickSight queries Glue catalog tables via Athena.

### Redshift -> QuickSight
QuickSight connects directly to the Redshift cluster for SQL queries.
Requires VPC connectivity.

### Aurora -> QuickSight
QuickSight connects to Aurora cluster endpoint. Requires VPC connectivity.

### QuickSight as Terminal Service
QuickSight is always a **consumer** in the pipeline graph — it reads data from
upstream sources and produces visualizations. It has no downstream targets
(`as_source_to` is empty).

---

## 14. Terraform Resources Created by Our Renderer

### Always Created
1. `aws_iam_role` — service role for quicksight.amazonaws.com
2. `aws_iam_role_policy` — inline policy with data access permissions
3. `aws_quicksight_data_source` — the data source connection

### Not Created (Available)
- `aws_quicksight_data_set` — dataset definition
- `aws_quicksight_analysis` — analysis (visuals, sheets)
- `aws_quicksight_dashboard` — published dashboard
- `aws_quicksight_template` — reusable template
- `aws_quicksight_user` — user registration
- `aws_quicksight_group` — group management
- `aws_quicksight_vpc_connection` — VPC connection (Enterprise)
- `aws_quicksight_refresh_schedule` — SPICE refresh schedule

---

## 15. Monitoring

QuickSight is a BI/visualization service, not a pipeline execution service.
It is **not monitored** by the pipeline run log aggregator. It falls under the
"metadata-only / no monitoring" category.

QuickSight does not write to CloudWatch Log Groups. Limited metrics are
available via the QuickSight admin console and the `AWS/QuickSight` CloudWatch
namespace.

---

## 16. Service Quotas

| Quota | Limit |
|---|---|
| Data sources per account | 200 |
| Datasets per account | 500 |
| Analyses per account | 500 |
| Dashboards per account | 500 |
| Folders per account | 1,000 |
| Columns per dataset | 2,000 |
| Calculated fields per dataset | 500 |
| Joined tables per dataset | 32 |
| Visuals per sheet | 30 |
| Sheets per analysis | 20 |
| Parameters per analysis | 100 |
| Filters per analysis | 20 |
| SPICE rows per dataset | 500 million |
| SPICE size per dataset | 500 GB |
| Email report recipients | 500 |

---

## 17. Best Practices

1. **Use SPICE** for dashboards accessed by many users — it offloads queries
   from the source and provides consistent performance
2. **Schedule SPICE refresh** at off-peak hours to minimize source load
3. **Use DIRECT_QUERY** only when real-time data is essential
4. **Use row-level security** (Enterprise) to share one dashboard with
   different user groups while filtering data per group
5. **Set up QuickSight account** before running Terraform — it's a prerequisite
6. **Use Athena** as the default data source type — it's the most flexible
   and doesn't require VPC connectivity
7. **Monitor SPICE capacity** — ingestion failures are often caused by
   insufficient SPICE storage
8. **Use parameters** in dashboards for drill-through navigation
9. **Embed dashboards** in applications using the QuickSight Embedding SDK
   rather than sharing direct console URLs

---

## 18. QuickSight vs. Other BI Tools

| Feature | QuickSight | Grafana | Tableau |
|---|---|---|---|
| Hosting | Serverless (AWS) | Self-hosted or managed | Cloud or server |
| Pricing | Per-user + SPICE | Per-user or free (OSS) | Per-user |
| In-memory engine | SPICE | None (queries source) | Hyper engine |
| ML Insights | Yes (Enterprise) | No | Some |
| Embedding | Yes (SDK) | Yes (iframe) | Yes |
| AWS integration | Native | Via plugins | Via connectors |
| Our renderer | Supported | Not supported | Not supported |
