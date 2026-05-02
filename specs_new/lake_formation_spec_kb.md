# AWS Lake Formation -- Complete Knowledge Base

> This document is the plain-English reference for Lake Formation that the
> pipeline engine framework and developer agent can consult when handling any
> Lake Formation-related request in a pipeline. It covers what Lake Formation is,
> how it works, every feature, integration patterns, security, and
> troubleshooting -- written for an agent that needs to reason about Lake
> Formation in context, not just look up API parameters.

---

## 1. What Is Lake Formation?

AWS Lake Formation is a managed service for building, securing, and managing
data lakes. It provides **centralized governance** over data stored in Amazon S3
and cataloged in the AWS Glue Data Catalog.

The key idea: instead of managing S3 bucket policies + IAM policies for every
table and every user, you use Lake Formation's simpler **grant/revoke permission
model** at the database, table, and column level.

### Core Concepts
- **Data Lake**: A centralized repository of structured and unstructured data stored in S3.
- **Glue Data Catalog**: The metadata catalog that Lake Formation governs (databases, tables, schemas).
- **Registered Location**: An S3 path that Lake Formation manages access to.
- **Permission**: A grant (e.g. SELECT on a table) from a grantor to a principal.
- **LF-Tag**: A key-value pair for tag-based access control.
- **Data Lake Admin**: An IAM principal with full governance control.
- **Credential Vending**: Lake Formation issues temporary S3 credentials scoped to authorized data.

### Free Tier
Lake Formation itself is **completely free**. There are no charges for Lake
Formation APIs, permissions, or governance. You only pay for the underlying
services: S3 storage, Glue crawlers/jobs, Athena queries, EMR clusters, etc.

### How It Differs from IAM-Only Access Control
Without Lake Formation, controlling access to S3 data lake data requires:
- S3 bucket policies per bucket
- IAM policies per role for Glue, S3, and Athena actions
- No column-level or row-level security
- No central audit of who accessed what

With Lake Formation:
- Central grant/revoke at database/table/column level
- Row-level and cell-level security via data filters
- Tag-based access control (LF-Tags) for scalability
- Credential vending (no long-lived S3 permissions needed)
- Audit logging of all data access

---

## 2. Architecture

```
                          Lake Formation
                     (Governance & Permissions)
                              |
                    +---------+---------+
                    |                   |
             Glue Data Catalog     S3 Data Lake
             (Metadata: DBs,      (Actual data files:
              Tables, Schemas)     Parquet, CSV, ORC, etc.)
                    |                   |
          +---------+---------+         |
          |         |         |         |
        Athena   Redshift    EMR     Glue ETL
       (Query)   Spectrum   (Spark)  (Transform)
          |         |         |         |
          +-------- +---------+---------+
                              |
                     Lake Formation checks
                     permissions & vends
                     temporary S3 credentials
```

When a service like Athena queries a table:
1. Athena asks Lake Formation for credentials
2. Lake Formation checks if the principal has SELECT permission on the table
3. If authorized, Lake Formation vends temporary S3 credentials scoped to exactly the data the principal can access
4. Athena uses these credentials to read from S3

---

## 3. Data Lake Settings

Data lake settings are the central configuration for your data lake:

### Data Lake Admins
IAM principals with full Lake Formation admin privileges:
- Grant/revoke any permission to any principal
- Register/deregister S3 locations
- Create databases without explicit permission
- Manage LF-Tags
- Up to 30 admins per account
- AWS account root is always an implicit admin

### Default Permissions
Controls what happens when new databases and tables are created:

**Hybrid mode (default)**: `IAM_ALLOWED_PRINCIPALS` gets `ALL` on new resources.
This means any IAM principal with Glue API permissions can access the data.
Lake Formation permissions are effectively bypassed.

**LF-only mode**: Remove `IAM_ALLOWED_PRINCIPALS` from defaults. Now every
principal needs an explicit Lake Formation grant, even if they have IAM
permissions for Glue APIs.

The pipeline engine uses **hybrid mode** for maximum compatibility.

---

## 4. Resource Registration

Registering an S3 location tells Lake Formation to manage access to that data.

### How It Works
```python
lf = boto3.client('lakeformation')
lf.register_resource(ResourceArn='arn:aws:s3:::my-data-lake-bucket')
```

Once registered:
- Lake Formation controls who can read/write to that location
- Services access data through credential vending (temporary scoped credentials)
- No need for S3 bucket policies or direct S3 IAM permissions

### Registration Modes
1. **Service-linked role** (default): Lake Formation uses its own role (`AWSServiceRoleForLakeFormationDataAccess`) to access S3
2. **Custom role**: Specify your own IAM role for S3 access

### In the Pipeline Engine
The Lake Formation renderer creates `aws_lakeformation_resource` for each S3
bucket that Lake Formation governs:
```hcl
resource "aws_lakeformation_resource" "governance_raw_data" {
  arn = aws_s3_bucket.raw_data.arn
}
```

---

## 5. Permissions Model

Lake Formation uses a grant/revoke model similar to SQL GRANT statements.

### Permission Types

**Database permissions**: ALL, ALTER, CREATE_TABLE, DESCRIBE, DROP

**Table permissions**: ALL, ALTER, DELETE, DESCRIBE, DROP, INSERT, SELECT

**Column permissions**: SELECT (column-level only)

**Data location permissions**: DATA_LOCATION_ACCESS (required to create tables at registered locations)

### Granting Permissions
```python
lf.grant_permissions(
    Principal={'DataLakePrincipalIdentifier': 'arn:aws:iam::123456789012:role/AnalystRole'},
    Resource={'Table': {'DatabaseName': 'analytics', 'Name': 'sales'}},
    Permissions=['SELECT', 'DESCRIBE']
)
```

### WITH GRANT OPTION
You can allow a grantee to re-grant their permissions to others:
```python
lf.grant_permissions(
    Principal={'DataLakePrincipalIdentifier': role_arn},
    Resource={'Database': {'Name': 'analytics'}},
    Permissions=['CREATE_TABLE'],
    PermissionsWithGrantOption=['CREATE_TABLE']
)
```

### Permission Evaluation Rules
1. Permissions are **additive** -- there is no explicit DENY
2. A principal needs BOTH IAM permissions (for API access) AND LF permissions (for data access)
3. In hybrid mode, IAM permissions alone are sufficient
4. Column-level permissions override table-level SELECT
5. Super permission (ALL) grants all applicable permissions for the resource type

---

## 6. LF-Tags (Tag-Based Access Control)

LF-Tags are the scalable way to manage permissions when you have hundreds or
thousands of tables.

### How It Works
1. Create tag keys with possible values:
   ```python
   lf.create_lf_tag(TagKey='classification', TagValues=['public', 'confidential', 'restricted'])
   lf.create_lf_tag(TagKey='department', TagValues=['engineering', 'finance', 'marketing'])
   ```

2. Assign tags to databases and tables:
   ```python
   lf.add_lf_tags_to_resource(
       Resource={'Table': {'DatabaseName': 'analytics', 'Name': 'sales'}},
       LFTags=[{'TagKey': 'classification', 'TagValues': ['confidential']},
               {'TagKey': 'department', 'TagValues': ['finance']}]
   )
   ```

3. Grant permissions based on tags:
   ```python
   lf.grant_permissions(
       Principal={'DataLakePrincipalIdentifier': analyst_role_arn},
       Resource={'LFTagPolicy': {
           'ResourceType': 'TABLE',
           'Expression': [{'TagKey': 'classification', 'TagValues': ['public']}]
       }},
       Permissions=['SELECT', 'DESCRIBE']
   )
   ```

Now any table tagged `classification=public` is automatically accessible to
the analyst role. When new tables are created and tagged, they inherit
permissions automatically.

### Tag Inheritance
- Database tags are inherited by all tables in the database
- Table tags can override inherited database tags for the same key

### Limits
- 1,000 LF-Tags per account
- 1,000 values per tag key
- 50 tags per resource

---

## 7. Data Filters (Column/Row/Cell-Level Security)

### Column-Level Security
Restrict which columns a principal can see:

**Include list**: Principal can only see specified columns
```hcl
resource "aws_lakeformation_permissions" "analyst_select" {
  principal = aws_iam_role.analyst.arn
  table_with_columns {
    database_name = "analytics"
    name          = "customers"
    column_names  = ["customer_id", "name", "city"]  # only these columns visible
  }
  permissions = ["SELECT"]
}
```

**Exclude list**: Principal can see all columns EXCEPT specified ones
```hcl
table_with_columns {
  database_name       = "analytics"
  name                = "customers"
  excluded_column_names = ["ssn", "credit_card"]  # these columns hidden
}
```

### Row-Level Security
Restrict which rows a principal can see using a filter expression:
```python
lf.create_data_cells_filter(TableData={
    'DatabaseName': 'analytics',
    'TableName': 'orders',
    'Name': 'engineering_only',
    'RowFilter': {'FilterExpression': "department = 'engineering'"},
    'ColumnWildcard': {}  # all columns
})
```

### Cell-Level Security
Combine row AND column filters on the same table for the most restrictive access.

Limits: 100 data filters per table.

---

## 8. Catalog Integration (Glue Data Catalog)

Lake Formation governs the **Glue Data Catalog** -- the central metadata
repository for your data lake.

### Relationship
- Databases and tables are created in the Glue Data Catalog
- Lake Formation adds a permissions layer on top
- Without Lake Formation, access is IAM-only (coarser)

### Catalog Resources
- **Database**: Logical grouping of tables. Does NOT contain data -- just metadata.
- **Table**: Metadata definition for data in S3 (columns, types, location, format).
- **Partition**: Subdivision of a table by partition key values.
- **Crawler**: Glue component that discovers schema and creates/updates tables.

### Supported Data Formats
Parquet, ORC, Avro, JSON, CSV, Text, Hudi, Delta Lake, Iceberg

### Creating a Governed Table
1. Register the S3 location with Lake Formation
2. Create a Glue database (or use existing)
3. Create a Glue table pointing to the S3 location
4. Grant Lake Formation permissions on the table

---

## 9. Cross-Account Data Sharing

Lake Formation supports sharing data across AWS accounts.

### Named Resource Sharing
1. Grantor grants permission to an external account ID
2. External account accepts the RAM invitation (auto-accepted within an Organization)
3. External account creates a **resource link** (pointer) in their catalog
4. External account grants permissions to their own principals

### LF-Tag-Based Sharing
Share based on tags -- any resource matching the tag is automatically shared
with the other account. Most scalable approach for organizations.

### Constraints
- Shared resources must be registered in Lake Formation
- Data location permissions cannot be shared cross-account
- Max 100 cross-account grants per resource
- External accounts query through resource links, not directly

---

## 10. Hybrid Mode vs. LF-Only Mode

This is the most important architectural decision when using Lake Formation.

### Hybrid Mode (Pipeline Engine Default)
- `IAM_ALLOWED_PRINCIPALS` has `ALL` on new databases and tables
- Any IAM principal with Glue permissions can access data
- Lake Formation permissions are effectively optional
- **Pros**: Easy to set up, backward compatible
- **Cons**: No centralized access control benefit

### LF-Only Mode
- Remove `IAM_ALLOWED_PRINCIPALS` from default permissions
- Every principal needs explicit Lake Formation grant
- **Pros**: Full centralized governance, audit trail, column/row security
- **Cons**: Must migrate all existing access to LF grants first

### Migration Steps (Hybrid to LF-Only)
1. Identify all IAM principals that currently access data
2. Create equivalent Lake Formation grants for each principal
3. Remove IAM_ALLOWED_PRINCIPALS from default permissions
4. Test access for all principals
5. Remove direct S3/Glue permissions from IAM policies

---

## 11. Credential Vending

When a service accesses registered data, Lake Formation checks permissions and
vends **temporary S3 credentials** scoped to exactly the tables/columns the
principal is authorized to access.

This means:
- No long-lived S3 permissions needed on the service's IAM role
- Credentials are automatically scoped (e.g. only specific prefixes in S3)
- Access is logged for audit
- Column/row restrictions are enforced at the credential level

Services that support credential vending: Athena, Glue, EMR, Redshift Spectrum.

---

## 12. Terraform Resources

The Lake Formation renderer in `engine/hcl_renderer.py` creates:

1. `aws_lakeformation_resource` -- registers each S3 bucket as a data lake location
2. `aws_lakeformation_data_lake_settings` -- configures data lake settings (admins, default permissions)

If no S3 integration exists, a placeholder resource is created:
```hcl
resource "aws_lakeformation_resource" "governance_placeholder" {
  arn = "arn:aws:s3:::placeholder-data-lake-bucket"
}
```

**Note**: Lake Formation resources do NOT support AWS resource tags (unlike most
other services). The `_tags_block(bp)` helper is not used in the Lake Formation
renderer.

### Additional Resources (Not in Default Renderer)
- `aws_lakeformation_permissions` -- explicit grants
- `aws_lakeformation_lf_tag` -- LF-Tag definitions
- `aws_lakeformation_resource_lf_tags` -- LF-Tag assignments
- `aws_lakeformation_data_cells_filter` -- row/column filters

---

## 13. IAM for Lake Formation

### Lake Formation Is Not a Principal
Lake Formation is a governance layer, not a compute service. It does not have
its own execution role in the pipeline engine. The `is_principal: false` setting
means no IAM role is created for Lake Formation itself.

### Service-Linked Role
Lake Formation uses a service-linked role (`AWSServiceRoleForLakeFormationDataAccess`)
to access registered S3 locations. This role is created automatically and has
S3 read/write permissions.

### IAM Actions for Lake Formation Administration
Key actions:
- `lakeformation:GetDataLakeSettings` / `PutDataLakeSettings`
- `lakeformation:GrantPermissions` / `RevokePermissions`
- `lakeformation:RegisterResource` / `DeregisterResource`
- `lakeformation:CreateLFTag` / `DeleteLFTag` / `UpdateLFTag`
- `lakeformation:AddLFTagsToResource` / `RemoveLFTagsFromResource`
- `lakeformation:CreateDataCellsFilter` / `DeleteDataCellsFilter`

### IAM for Services Querying Through Lake Formation
Services that query data governed by Lake Formation need:
- `lakeformation:GetDataAccess` -- triggers credential vending
- Glue catalog permissions (`glue:GetTable`, `glue:GetDatabase`, etc.)

---

## 14. Integration Patterns

### Lake Formation Registers S3
The most common integration: Lake Formation registers S3 buckets as data lake
storage locations.

### Services Querying Through Lake Formation

| Service | How It Works | IAM Needed |
|---|---|---|
| Athena | Queries catalog tables; LF vends S3 credentials | lakeformation:GetDataAccess, glue:Get* |
| Glue ETL | Jobs access registered data; LF vends credentials | lakeformation:GetDataAccess |
| Glue Crawler | Discovers schema in S3; needs LF permission | lakeformation:GetDataAccess, glue:Get* |
| EMR | Spark/Hive access via LF credential vending | lakeformation:GetDataAccess |
| Redshift Spectrum | External tables query through LF | lakeformation:GetDataAccess, glue:Get* |

### Wiring Ownership
Lake Formation renderer **owns**:
- `aws_lakeformation_resource` (S3 registration)
- `aws_lakeformation_data_lake_settings`

Other renderers own their own LF-related IAM permissions
(`lakeformation:GetDataAccess`, etc.).

---

## 15. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `AccessDeniedException (lakeformation)` | Principal lacks LF permission | Grant SELECT/DESCRIBE via grant_permissions |
| `InvalidInputException (principal)` | Bad principal ARN | Verify IAM user/role ARN format |
| `EntityNotFoundException (database/table)` | Resource not in Glue catalog | Create database/table first |
| `AlreadyExistsException` | LF-Tag or filter already exists | Use update instead of create |
| `ResourceNotReadyException` | Concurrent modification | Retry with backoff |
| `OperationTimeoutException` | API timeout | Retry with backoff |
| `ConcurrentModificationException` | Another operation in progress | Retry with backoff |
| `InvalidInputException (not registered)` | S3 location not registered | Call register_resource |
| `GlueEncryptionException` | Catalog encryption key issue | Add KMS permissions |

### Troubleshooting Steps
1. Check data lake settings: `lf.get_data_lake_settings()`
2. List registered resources: `lf.list_resources()`
3. Check permissions: `lf.list_permissions(Resource={...})`
4. Verify effective permissions: `lf.get_effective_permissions_for_path(ResourceArn=s3_arn)`
5. Check if in hybrid or LF-only mode (look at default permissions)

---

## 16. Developer Agent Operations

### Checking Data Lake Configuration
```python
lf = boto3.client('lakeformation', region_name=region)
settings = lf.get_data_lake_settings()['DataLakeSettings']
print(f"Admins: {settings.get('DataLakeAdmins', [])}")
print(f"Default DB perms: {settings.get('CreateDatabaseDefaultPermissions', [])}")
print(f"Default table perms: {settings.get('CreateTableDefaultPermissions', [])}")
```

### Listing Registered Resources
```python
resources = lf.list_resources()['ResourceInfoList']
for r in resources:
    print(f"Resource: {r['ResourceArn']}, Role: {r.get('RoleArn', 'SLR')}")
```

### Granting Permissions
```python
lf.grant_permissions(
    Principal={'DataLakePrincipalIdentifier': role_arn},
    Resource={'Table': {'DatabaseName': 'my_db', 'Name': 'my_table'}},
    Permissions=['SELECT', 'DESCRIBE']
)
```

### Revoking Permissions
```python
lf.revoke_permissions(
    Principal={'DataLakePrincipalIdentifier': role_arn},
    Resource={'Table': {'DatabaseName': 'my_db', 'Name': 'my_table'}},
    Permissions=['SELECT']
)
```

### Creating LF-Tags
```python
lf.create_lf_tag(TagKey='sensitivity', TagValues=['low', 'medium', 'high'])
lf.add_lf_tags_to_resource(
    Resource={'Table': {'DatabaseName': 'analytics', 'Name': 'logs'}},
    LFTags=[{'TagKey': 'sensitivity', 'TagValues': ['low']}]
)
```

---

## 17. Best Practices

1. **Start with hybrid mode**, migrate to LF-only when ready
2. **Use LF-Tags** for permission management at scale (100+ tables)
3. **Define a tag taxonomy** before assigning tags (classification, department, sensitivity)
4. **Register all data lake S3 locations** for centralized access control
5. **Use data filters** for column-level and row-level security on sensitive data
6. **Set up audit logging** to track who accesses what data
7. **Use credential vending** instead of direct S3 IAM permissions
8. **Grant with minimum permissions** -- SELECT + DESCRIBE for read-only access
9. **Use grant option sparingly** -- only for delegation scenarios
10. **Monitor with CloudTrail** -- all Lake Formation API calls are logged

---

## 18. Service Quotas

| Quota | Limit |
|---|---|
| Databases per catalog | 10,000 (adjustable) |
| Tables per database | 200,000 (adjustable) |
| Partitions per table | 10,000,000 (adjustable) |
| LF-Tags per account | 1,000 (adjustable) |
| Values per LF-Tag key | 1,000 |
| LF-Tags per resource | 50 |
| Data lake admins | 30 |
| Registered S3 locations | 10,000 |
| Data filters per table | 100 |
| Cross-account grants per resource | 100 |
| Blueprints per account | 10,000 |
| GrantPermissions TPS | 15 |
| ListPermissions TPS | 15 |

---

## 19. Governed Tables vs. Apache Iceberg

Lake Formation offers "governed tables" for ACID transactions on S3. However,
the industry has largely converged on **Apache Iceberg** as the standard for
transactional data lakes:

| Feature | Governed Tables | Apache Iceberg |
|---|---|---|
| ACID transactions | Yes | Yes |
| Time travel | Yes | Yes |
| Engine support | LF-aware only | Athena, Spark, Flink, Trino, Presto, Hive |
| Ecosystem | AWS-only | Open standard, multi-cloud |
| Terraform support | Limited | Full (via Glue catalog) |

**Recommendation**: For new data lakes, use Apache Iceberg tables with Lake
Formation for governance. Iceberg provides the transactional capabilities,
Lake Formation provides the access control.

---

## 20. Pipeline Run Monitoring

Lake Formation is a metadata-only service -- it does not have runtime logs
or CloudWatch metrics of its own. In the pipeline log aggregator:
- Monitoring method: **None** (metadata-only)
- Lake Formation API calls are logged in CloudTrail but not streamed to
  the pipeline run monitor

CloudTrail events of interest:
- `GrantPermissions` / `RevokePermissions`
- `RegisterResource` / `DeregisterResource`
- `GetTemporaryGlueTableCredentials` (indicates data access)
