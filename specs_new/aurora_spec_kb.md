# Aurora Knowledge Base

## What Is Amazon Aurora

Amazon Aurora is a fully managed relational database engine compatible with MySQL and PostgreSQL. It provides up to 5x the throughput of standard MySQL and 3x the throughput of standard PostgreSQL, without requiring application changes. Aurora combines the performance and availability of commercial databases with the simplicity and cost-effectiveness of open-source databases.

Aurora is part of Amazon RDS and uses the same management console, CLI, and API operations. It automates provisioning, patching, backup, recovery, failure detection, and repair.

Aurora is never part of the AWS Free Tier. The minimum cost is approximately $0.12 per ACU-hour for Serverless v2 with a 0.5 ACU minimum.

## Cluster Architecture

An Aurora DB cluster consists of one or more DB instances and a cluster volume that manages the underlying data.

### Writer Instance
Every cluster has exactly one primary (writer) DB instance that handles both read and write operations. All data modifications go through the writer. If the writer fails, Aurora automatically promotes a reader to become the new writer.

### Reader Instances (Aurora Replicas)
A cluster can have up to 15 Aurora Replicas. These are read-only instances that connect to the same cluster volume as the writer. They serve read queries, offloading work from the writer. Each replica can have a configurable failover priority (tier 0 is highest). Replicas should be placed in different Availability Zones for high availability.

### Storage
Aurora uses a distributed, fault-tolerant, self-healing storage system. Data is replicated 6 ways across 3 Availability Zones. The cluster volume grows automatically in 10 GB increments up to 128 TiB. Storage automatically repairs data blocks by comparing against the other 5 copies. I/O operations are counted identically for writer and reader instances.

## Endpoints

### Cluster Endpoint (Writer)
DNS format: `CLUSTER-ID.cluster-RANDOM.REGION.rds.amazonaws.com`
Connects to the primary instance. Use for all write operations (DDL, DML, ETL, INSERT/UPDATE/DELETE). Automatically points to the new primary after failover.

### Reader Endpoint
DNS format: `CLUSTER-ID.cluster-ro-RANDOM.REGION.rds.amazonaws.com`
Load-balanced across all Aurora Replicas. Use for read-only queries, reporting, and analytics. Connection-level balancing (not query-level). May temporarily route to the new primary immediately after failover.

### Custom Endpoint
User-defined endpoint mapping to a subset of instances. Up to 5 per cluster. Useful for routing workloads to specific instance sizes or isolating workloads.

### Instance Endpoint
Direct connection to a specific DB instance. No automatic failover. Use only for diagnosis, troubleshooting, and performance tuning. Not recommended for production traffic.

### Global Writer Endpoint
Special endpoint for Aurora Global Database. Automatically switches to the new primary cluster in another region during failover.

## Aurora Serverless v2

Aurora Serverless v2 provides automatic, fine-grained scaling of compute capacity. It uses the `db.serverless` instance class within a provisioned-mode cluster (not the deprecated "serverless" engine mode from v1).

### ACU (Aurora Capacity Units)
Each ACU is approximately 2 GB of memory. Serverless v2 scales in 0.5 ACU increments, from a minimum of 0.5 ACU to a maximum of 256 ACU. Scaling takes seconds, occurs with no pause in processing, and can happen while SQL statements are running and transactions are open.

### Pricing
Pay per ACU-second based on actual capacity consumed. Minimum cost approximately $0.12 per ACU-hour (varies by region).

### Supported Features
Reader DB instances (horizontal scaling), multi-AZ clusters, Aurora Global Databases, RDS Proxy (connection pooling), IAM database authentication, Performance Insights, cloning, snapshot restore, and failover.

### Terraform Configuration
```
engine_mode = "provisioned"
instance_class = "db.serverless"
serverlessv2_scaling_configuration {
  min_capacity = 0.5
  max_capacity = 8
}
```

## Engine Compatibility

### Aurora PostgreSQL
Engine value: `aurora-postgresql`. Default port: 5432. Supported versions include 13.x through 16.x. CloudWatch log exports: postgresql. Data API supported.

### Aurora MySQL
Engine value: `aurora-mysql`. Default port: 3306. Supported versions include MySQL 8.0 compatible (3.x series). CloudWatch log exports: audit, error, general, slowquery. Data API supported.

## Global Databases

Aurora Global Database provides multi-region deployment for disaster recovery and low-latency reads. A primary cluster in one region handles read/write operations. Up to 5 secondary regions provide read-only access with storage-based replication (sub-second lag).

Failover options:
- Planned switchover (SwitchoverGlobalCluster): Zero data loss
- Unplanned failover (FailoverGlobalCluster): RPO of approximately 1 second

Write forwarding allows secondary clusters to forward write requests to the primary region.

## Backups

### Automated Backups
Continuous backups to S3, retained 1-35 days (default 1 day). Incremental -- only changed data is backed up. Configurable backup window.

### Manual Snapshots
User-initiated full cluster snapshots. Maximum 100 per region. Retained until explicitly deleted.

### Point-in-Time Recovery (PITR)
Restore the cluster to any point within the backup retention window with 5-minute granularity. Creates a new cluster.

### Backtrack (MySQL only)
Rewind the cluster to a previous point without creating a new cluster. Maximum 72-hour window. Faster than PITR.

## Encryption

### At Rest
AES-256 encryption of the cluster volume, snapshots, and replicas. Enabled by default. Key options: AWS-managed KMS key (aws/rds) or customer-managed CMK. Must be enabled at cluster creation time -- cannot enable later. All instances inherit the encryption setting.

### In Transit
SSL/TLS encryption for client connections. Enabled by default. Can be enforced via the `rds.force_ssl` parameter (PostgreSQL) or `require_secure_transport` (MySQL).

### IAM Database Authentication
Authenticate using IAM credentials instead of passwords. Authentication tokens expire in 15 minutes. IAM action: `rds-db:connect`. ARN format: `arn:aws:rds-db:REGION:ACCOUNT:dbuser:DBI-RESOURCE-ID/DB-USER-NAME`.

## Data API

The Data API provides an HTTP endpoint for executing SQL without persistent database connections. It uses Secrets Manager for credential management. Ideal for Lambda and serverless applications.

Constraints: max request size 64 KB, max response size 1 MB, transaction timeout 3 minutes. Boto3 client: `rds-data`. Operations: execute_statement, batch_execute_statement, begin_transaction, commit_transaction, rollback_transaction.

Enable via Terraform: `enable_http_endpoint = true` on the aws_rds_cluster resource. Or via API: `rds.modify_db_cluster(DBClusterIdentifier=id, EnableHttpEndpoint=True)`.

## Integration Patterns with Pipeline Services

### Lambda
Lambda queries Aurora via the Data API (recommended -- no VPC or connection pooling needed). Needs rds-data:ExecuteStatement, secretsmanager:GetSecretValue. Alternatively, Lambda can connect via JDBC/psycopg2 in VPC.

### Step Functions
SDK integration with Data API for direct SQL execution from state machine tasks.

### Glue
Glue ETL jobs read from Aurora via JDBC connections. Requires VPC connectivity and security group access. Needs rds:DescribeDBClusters.

### EMR
EMR reads Aurora via JDBC. Requires VPC connectivity. Needs rds:DescribeDBClusters.

### DMS
DMS uses Aurora as a source or target for database migration/replication. Requires VPC security group to allow DMS replication instance access. Needs rds:DescribeDBClusters, rds:DescribeDBInstances.

### S3
Aurora can export query results or snapshots to S3. Requires an IAM role associated with the cluster with s3:PutObject, s3:GetObject, s3:ListBucket.

### SageMaker Notebook
Connects to Aurora for data exploration via JDBC. Requires VPC connectivity.

### Redshift (Zero-ETL)
Aurora zero-ETL integration continuously replicates data to Redshift for analytics without building ETL pipelines.

## Terraform Resources

The Aurora renderer creates:
- `aws_cloudwatch_log_group` (always): Log group for Aurora error/slow query logs
- `aws_security_group` (always): Security group for Aurora cluster
- `aws_db_subnet_group` (always): Subnet group for Aurora cluster
- `random_password` (always): Random master password
- `aws_rds_cluster` (always): Aurora cluster with Serverless v2 scaling configuration
- `aws_rds_cluster_instance` (always): Serverless v2 instance (db.serverless class)

Conditional resources:
- `aws_rds_cluster_parameter_group`: Custom cluster parameters
- `aws_db_parameter_group`: Custom instance parameters
- `aws_rds_cluster_endpoint`: Custom endpoints
- `aws_rds_global_cluster`: Global database
- `aws_rds_integration`: Zero-ETL integration with Redshift

## IAM Patterns

Aurora is a passive service (is_principal: false) -- it has no execution role. Callers need permissions on their own roles.

Key IAM actions:
- Cluster management: rds:CreateDBCluster, ModifyDBCluster, DescribeDBClusters, DeleteDBCluster
- Data API: rds-data:ExecuteStatement, BatchExecuteStatement, BeginTransaction, CommitTransaction
- IAM auth: rds-db:connect
- Snapshots: rds:CreateDBClusterSnapshot, RestoreDBClusterFromSnapshot

ARN formats:
- Cluster: `arn:aws:rds:REGION:ACCOUNT:cluster:CLUSTER-ID`
- Instance: `arn:aws:rds:REGION:ACCOUNT:db:INSTANCE-ID`
- IAM DB user: `arn:aws:rds-db:REGION:ACCOUNT:dbuser:DBI-RESOURCE-ID/DB-USER`

## Common Errors and Troubleshooting

| Error | Cause | Resolution |
|-------|-------|------------|
| Communications link failure / timeout | VPC security group blocks DB port | Add inbound rule for TCP 5432 (PG) or 3306 (MySQL) |
| Data API is not enabled | HTTP endpoint not enabled | modify_db_cluster(EnableHttpEndpoint=True) |
| DBClusterNotFoundFault | Cluster does not exist | Verify cluster ID and region |
| too many connections | Max connections exceeded | Use RDS Proxy or increase max_capacity ACUs |
| password authentication failed | Invalid credentials | Check Secrets Manager secret value |
| InvalidDBClusterStateFault | Cluster not in available state | Wait for cluster to become available |

## Security Best Practices

1. Always encrypt at rest (enabled by default)
2. Enforce SSL/TLS for all connections via parameter group settings
3. Use IAM database authentication instead of static passwords
4. Use Secrets Manager for credential rotation
5. Place Aurora in private subnets with no public accessibility
6. Use security groups to restrict access to only authorized callers
7. Enable audit logging (aurora-mysql) or pgAudit (aurora-postgresql)
8. Use Data API for serverless callers to avoid managing connections
9. Enable deletion protection for production clusters
10. Enable automated backups with appropriate retention period

## Monitoring

Aurora publishes CloudWatch metrics under the AWS/RDS namespace. Key metrics: CPUUtilization, DatabaseConnections, FreeableMemory, ReadIOPS, WriteIOPS, ReadLatency, WriteLatency. For Serverless v2: ServerlessDatabaseCapacity (current ACUs) and ACUUtilization.

Performance Insights provides deep visibility into database load with wait event analysis. Enhanced Monitoring provides OS-level metrics at 1-60 second intervals.

For the pipeline run monitor, Aurora logs are exported to CloudWatch Logs. Log group pattern: `/aws/rds/cluster/CLUSTER-NAME/LOG-TYPE` where LOG-TYPE is postgresql, error, slowquery, audit, or general.

## Quotas Summary

| Resource | Limit |
|----------|-------|
| Clusters per region | 40 (adjustable) |
| Instances per cluster | 15 readers + 1 writer |
| Custom endpoints per cluster | 5 |
| Max cluster volume | 128 TiB |
| Manual snapshots per region | 100 |
| Automated backup retention | 1-35 days |
| Parameter groups | 50 each (cluster + instance) |
| Tags per resource | 50 |
| Serverless v2 ACU range | 0.5 - 256 |
