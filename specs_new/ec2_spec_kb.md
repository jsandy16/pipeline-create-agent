# Amazon EC2 -- Complete Knowledge Base

> This document is the plain-English reference for EC2 that the pipeline engine
> framework and developer agent can consult when handling any EC2-related request
> in a pipeline. It covers what EC2 is, how it works, every feature, integration
> patterns, security, performance, and troubleshooting -- written for an agent
> that needs to reason about EC2 in context, not just look up API parameters.

---

## 1. What Is EC2?

Amazon Elastic Compute Cloud (EC2) provides resizable virtual servers (instances)
in the cloud. You choose an Amazon Machine Image (AMI) for the operating system,
an instance type for CPU/memory/network, and attach storage (EBS volumes). Each
instance runs inside a VPC with security groups controlling network access.

EC2 is a **principal** service in our pipeline engine -- it has an IAM instance
profile (execution role) that grants it permissions to interact with other AWS
services. The pipeline engine creates the instance, its IAM role, instance
profile, and security group.

### Core Concepts
- **Instance**: A virtual server running in AWS.
- **AMI**: Amazon Machine Image -- a template containing the OS and pre-installed software.
- **Instance Type**: Defines CPU, memory, storage, and network capacity (e.g. t3.micro).
- **Instance Profile**: A container for an IAM role that passes credentials to the instance.
- **Security Group**: A virtual firewall controlling inbound/outbound traffic.
- **Key Pair**: SSH key for Linux login (optional -- prefer SSM Session Manager).
- **User Data**: A script that runs on first boot.
- **EBS Volume**: Persistent block storage attached to the instance.

### Free Tier
EC2 is free for 12 months: 750 hours/month of t2.micro or t3.micro (Linux or
Windows). This is approximately 1 instance running 24/7. The pipeline engine
defaults to t3.micro.

Additionally: 30 GB of EBS General Purpose (gp2/gp3) storage per month for
12 months.

---

## 2. Instance Types

EC2 has hundreds of instance types organized into families:

| Family | Purpose | Example Types |
|---|---|---|
| **General Purpose** (t, m) | Balanced compute/memory | t3.micro, m6i.large |
| **Compute Optimized** (c) | High CPU | c6i.xlarge, c7g.large |
| **Memory Optimized** (r, x, z) | High memory | r6i.large, x2iedn.xlarge |
| **Storage Optimized** (i, d, h) | High disk I/O | i3.large, d3.xlarge |
| **Accelerated** (p, g, inf, trn) | GPU/ML hardware | p4d.24xlarge, g5.xlarge |

### Burstable Instances (T-series)

T2, T3, T3a, and T4g instances are burstable -- they earn CPU credits when
idle and spend them when bursting above baseline.

- **Standard mode**: Credits expire after 24 hours. Instance throttled when empty.
- **Unlimited mode** (default for T3/T3a/T4g): Can burst beyond credit balance
  at a small per-vCPU-hour charge.

The free-tier t3.micro has a baseline of 10% CPU. This is sufficient for light
workloads like small web servers, development environments, and pipeline
coordinator instances.

### Graviton (ARM) Instances

Instance types ending in "g" (t4g, m7g, c7g, r7g) use AWS Graviton processors
(ARM64). They offer up to 40% better price-performance compared to x86
equivalents. Use them when your software supports ARM64.

---

## 3. AMIs (Amazon Machine Images)

An AMI is a template for the instance's root volume. The pipeline engine uses a
`data.aws_ami` data source to look up the latest AMI dynamically:

**Default**: Amazon Linux 2 (`amzn2-ami-hvm-*-x86_64-gp2`, owned by "amazon")

**Common AMIs**:
- Amazon Linux 2: `amzn2-ami-hvm-*-x86_64-gp2`
- Amazon Linux 2023: `al2023-ami-*-x86_64`
- Ubuntu 22.04: `ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*` (owner: 099720109477)
- Ubuntu 24.04: `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*`
- Windows Server 2022: `Windows_Server-2022-English-Full-Base-*`
- ECS Optimized: `amzn2-ami-ecs-hvm-*-x86_64-ebs`

**Key rules**:
- AMIs are region-specific -- the same image has different IDs per region
- Always use `data.aws_ami` with `most_recent = true` rather than hardcoding IDs
- Custom AMIs can be created from running instances via `create_image`

---

## 4. EBS Volumes (Block Storage)

Every EC2 instance has at least one EBS volume (the root volume). EBS provides
persistent block storage that survives instance stop/start.

### Volume Types

| Type | Use Case | IOPS | Throughput | Cost |
|---|---|---|---|---|
| **gp3** (recommended) | General purpose | 3000 base, up to 16000 | 125 base, up to 1000 MiB/s | Cheapest SSD |
| **gp2** (legacy) | General purpose | 3/GB (100-16000) | Up to 250 MiB/s | Slightly more than gp3 |
| **io1** | High performance DB | Up to 64000 | Up to 1000 MiB/s | Expensive |
| **io2** | Highest performance | Up to 256000 | Up to 4000 MiB/s | Most expensive SSD |
| **st1** | Throughput (big data) | N/A | Up to 500 MiB/s | Cheap HDD |
| **sc1** | Cold data | N/A | Up to 250 MiB/s | Cheapest |

The pipeline engine defaults to gp3 with 8 GB for the root volume.

### EBS Encryption
- All volumes should be encrypted (terraform attribute: `encrypted = true`)
- Default key: `aws/ebs` (AWS-managed, free)
- Custom KMS keys for compliance or cross-account scenarios
- Encrypted volumes produce encrypted snapshots
- Data in transit is encrypted automatically on Nitro-based instances

### Instance Store (Ephemeral Storage)
Some instance types include locally-attached NVMe drives with extremely high
IOPS. **Data is lost when the instance stops, terminates, or the host fails.**
Only use for temporary data, caches, or replicated data.

---

## 5. Security Groups

Security groups are virtual firewalls that control traffic to/from instances.

**Key characteristics**:
- **Stateful**: If you allow inbound traffic, the response is automatically allowed
- **Default deny inbound**: No inbound traffic unless you add a rule
- **Default allow outbound**: All outbound traffic is allowed
- **Allow-only**: You cannot create deny rules
- **Immediate effect**: Changes apply instantly

The pipeline engine creates a security group with **egress-only** (all outbound
allowed, no inbound rules). This is the most secure default. Ingress rules can
be added post-deployment by the developer agent.

### Common Port Rules
| Protocol | Port | Service |
|---|---|---|
| TCP | 22 | SSH |
| TCP | 80 | HTTP |
| TCP | 443 | HTTPS |
| TCP | 3389 | RDP (Windows) |
| TCP | 5432 | PostgreSQL |
| TCP | 3306 | MySQL |

**Limits**: 5 security groups per instance, 60 rules per group (adjustable to 200).

---

## 6. Key Pairs and Access

### SSH Key Pairs
- RSA (2048-bit) or Ed25519 key types
- Private key returned only at creation time
- The pipeline engine does **NOT** create key pairs (keys should not be in Terraform state)

### SSM Session Manager (Recommended)
Session Manager provides secure shell access without SSH:
- No open inbound ports needed
- No key pairs needed
- Full audit logging in CloudTrail
- Requires: SSM Agent on the instance + `AmazonSSMManagedInstanceCore` IAM policy

For pipeline engine use, SSM is the preferred method for running commands:
```python
ssm.send_command(
    InstanceIds=[instance_id],
    DocumentName='AWS-RunShellScript',
    Parameters={'commands': ['your-command']}
)
```

---

## 7. User Data (Bootstrap Scripts)

User data runs on the first boot of an instance. Maximum 16 KB (uncompressed).

**Formats**:
- Shell script: starts with `#!/bin/bash`
- Cloud-init config: starts with `#cloud-config`

**Key behaviors**:
- Runs as root
- Output logged to `/var/log/cloud-init-output.log`
- Non-zero exit code does NOT prevent the instance from starting
- Only runs on first launch (not on stop/start) unless configured otherwise

---

## 8. Instance Metadata Service (IMDS)

Every instance can access metadata at `http://169.254.169.254/latest/meta-data/`:
- Instance ID, type, AMI ID
- Public and private IP addresses
- IAM role credentials
- Placement information

**Security**: Always use **IMDSv2** (session-oriented, requires PUT token first).
IMDSv1 is vulnerable to SSRF attacks. The pipeline engine sets
`http_tokens = "required"` to enforce IMDSv2.

---

## 9. Networking

### VPC and Subnets
Every EC2 instance runs in a VPC subnet. The pipeline engine uses the default
VPC and subnets unless the pipeline requires VPC placement (triggered by
integrations with Aurora, Redshift, or MSK).

### Elastic IPs
Static IPv4 addresses. Free while associated with a running instance. Cost
$0.005/hour when not attached to a running instance.

### Public IPv4 Addresses
As of February 2024, public IPv4 addresses cost $0.005/hour. For cost
optimization, use private subnets with NAT Gateway or VPC endpoints.

### Placement Groups
- **Cluster**: All instances in one AZ, lowest network latency (HPC)
- **Spread**: Instances on different hardware, max 7 per AZ (critical apps)
- **Partition**: Instances in logical partitions on separate racks (Hadoop, Cassandra)

---

## 10. Auto Scaling

While the pipeline engine creates single instances by default, EC2 supports
Auto Scaling for production workloads.

### Components
1. **Launch Template**: Defines instance configuration (AMI, type, security groups, etc.)
2. **Auto Scaling Group (ASG)**: Manages a fleet of instances with min/max/desired counts
3. **Scaling Policies**: Rules for when to add/remove instances

### Scaling Types
- **Target tracking**: Maintain a metric (e.g. 50% CPU utilization)
- **Step scaling**: Scale by different amounts based on alarm severity
- **Scheduled**: Scale at specific times (e.g. business hours)

---

## 11. Spot Instances

Spot instances use unused EC2 capacity at up to 90% discount. They can be
interrupted with 2-minute notice.

**Best for**: Batch processing, CI/CD, data analysis, stateless web servers
**Not for**: Databases, stateful apps without checkpointing

**Best practices**:
- Diversify across instance types and AZs
- Implement graceful shutdown handling (2-minute interruption notice)
- Use Spot Fleet with allocation strategy for reliability

---

## 12. Monitoring

### CloudWatch Metrics
Basic monitoring (free, 5-minute intervals):
- CPUUtilization, DiskReadOps, DiskWriteOps, NetworkIn, NetworkOut
- StatusCheckFailed (system + instance)

Detailed monitoring ($3.50/month, 1-minute intervals): Same metrics at higher
resolution.

### CloudWatch Agent
Install the CloudWatch Agent for OS-level metrics not available by default:
- Memory utilization, disk space, swap usage
- Custom application metrics
- Log file collection

### Pipeline Run Monitoring
EC2 has no native CloudWatch Log Group. The pipeline log aggregator uses
**CloudTrail LookupEvents** filtered by instance ARN. This has a 5-15 minute
delivery delay compared to real-time CloudWatch Logs.

---

## 13. IAM for EC2

### Instance Profile
EC2 accesses other AWS services via an **instance profile** -- a container that
holds an IAM role. The pipeline engine always creates:

1. **IAM Role** with trust policy for `ec2.amazonaws.com`
2. **IAM Policy** with permissions computed from the integration graph
3. **Instance Profile** linking the role to the instance

### Integration Permissions
When the pipeline declares EC2 integrations, the engine automatically adds
the required IAM permissions:

| Integration Target | Permissions Added |
|---|---|
| S3 | s3:GetObject, s3:PutObject, s3:ListBucket, s3:DeleteObject |
| SQS | sqs:SendMessage, sqs:ReceiveMessage, sqs:DeleteMessage, sqs:GetQueueAttributes |
| DynamoDB | dynamodb:PutItem, GetItem, UpdateItem, Query, Scan, DeleteItem |
| SNS | sns:Publish |
| Kinesis Streams | kinesis:PutRecord, kinesis:PutRecords |
| Kinesis Firehose | firehose:PutRecord, firehose:PutRecordBatch |
| Redshift | redshift-data:ExecuteStatement, GetStatementResult, DescribeStatement |
| Aurora | rds-data:ExecuteStatement, BatchExecuteStatement, secretsmanager:GetSecretValue |
| Lambda | lambda:InvokeFunction |
| Step Functions | states:StartExecution, states:DescribeExecution |
| SageMaker | sagemaker:InvokeEndpoint |
| Athena | athena:StartQueryExecution, GetQueryExecution, GetQueryResults |
| MSK | kafka:DescribeCluster, kafka:GetBootstrapBrokers |

**Always included**: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

### VPC Triggers
EC2 requires VPC configuration when integrated with: Aurora, Redshift, MSK.

---

## 14. Terraform Resources Created

The EC2 renderer in `engine/hcl_renderer.py` creates:

1. `data "aws_ami"` -- latest Amazon Linux 2 lookup
2. `aws_iam_role` -- trust policy for ec2.amazonaws.com
3. `aws_iam_role_policy` -- inline policy with computed permissions
4. `aws_iam_instance_profile` -- links role to instance
5. `aws_security_group` -- egress-only (all outbound, no inbound)
6. `aws_instance` -- the EC2 instance itself

**Note**: The EC2 renderer does NOT currently create a CloudWatch Log Group
(EC2 uses CloudTrail for pipeline monitoring). This is one of the few services
without a native CW Log Group in the renderer.

---

## 15. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `AccessDenied` / `not authorized` | Instance profile missing permissions | Add required IAM actions to the instance role |
| `InstanceLimitExceeded` | Account quota reached for this instance type | Request quota increase or use different type |
| `InsufficientInstanceCapacity` | No capacity in the AZ for this type | Try different AZ or instance type |
| `InvalidAMIID` | AMI not found in this region | Use data.aws_ami data source instead of hardcoded IDs |
| `InvalidParameterValue (instance type)` | Instance type unavailable in AZ | Check with describe_instance_type_offerings |
| `UnauthorizedOperation` | Deploying role lacks ec2:RunInstances | Add ec2:* permissions to deploying role |
| `VPCIdNotSpecified` | No default VPC in region | Specify subnet_id in configuration |
| `InvalidKeyPair.NotFound` | Key pair doesn't exist | Create key pair or remove key_name |
| `IncorrectInstanceState` | Instance must be stopped for operation | Stop instance first, then modify, then start |
| `InvalidInstanceID.NotFound` | Instance terminated | Use Pipeline tag filter to find current instance |

---

## 16. Developer Agent Operations

### Finding the Instance
```python
ec2 = boto3.client('ec2', region_name=region)
resp = ec2.describe_instances(
    Filters=[
        {'Name': 'tag:Pipeline', 'Values': [pipeline_name]},
        {'Name': 'instance-state-name', 'Values': ['running']}
    ]
)
instance_id = resp['Reservations'][0]['Instances'][0]['InstanceId']
```

### Running Commands (via SSM)
```python
ssm = boto3.client('ssm', region_name=region)
cmd = ssm.send_command(
    InstanceIds=[instance_id],
    DocumentName='AWS-RunShellScript',
    Parameters={'commands': ['echo hello', 'ls -la /opt']}
)
# Poll for completion
result = ssm.get_command_invocation(
    CommandId=cmd['Command']['CommandId'],
    InstanceId=instance_id
)
# result['Status'] in ['Pending', 'InProgress', 'Success', 'Failed', 'TimedOut']
```

### Modifying Instance Type
```python
ec2.stop_instances(InstanceIds=[instance_id])
# Wait for stopped state
ec2.modify_instance_attribute(
    InstanceId=instance_id,
    InstanceType={'Value': 't3.small'}
)
ec2.start_instances(InstanceIds=[instance_id])
```

---

## 17. Security Best Practices

1. **Use IMDSv2** (http_tokens = required) -- prevents SSRF attacks
2. **Use SSM Session Manager** instead of SSH -- no open ports, full audit
3. **Minimal security group rules** -- egress-only by default, add ingress as needed
4. **Encrypt EBS volumes** -- enabled by default in pipeline engine
5. **Use instance profiles** -- never store AWS credentials on instances
6. **Use private subnets** with NAT Gateway for internet access
7. **Enable termination protection** for production instances
8. **Patch regularly** -- use Systems Manager Patch Manager
9. **Use gp3** instead of gp2 -- better performance, lower cost
10. **Monitor with CloudWatch Agent** for memory and disk metrics

---

## 18. Service Quotas

| Quota | Limit |
|---|---|
| On-demand instances per region | 20 (per type, adjustable) |
| Security groups per instance | 5 |
| Rules per security group | 60 (adjustable to 200) |
| Elastic IPs per region | 5 (adjustable) |
| Key pairs per region | 5,000 |
| EBS volumes per instance | 40 (Nitro) |
| Max EBS volume size | 16 TiB |
| User data size | 16 KB (uncompressed) |
| Tags per resource | 50 |
| Launch templates per region | 5,000 |
| Placement groups per account | 500 |

---

## 19. Cost Optimization

1. **Right-size instances** -- use CloudWatch metrics to identify underutilized instances
2. **Use Graviton (ARM)** -- t4g/m7g/c7g for up to 40% better price-performance
3. **Spot instances** for fault-tolerant workloads (up to 90% savings)
4. **Reserved Instances** or **Savings Plans** for steady-state workloads (up to 72% savings)
5. **Stop idle instances** -- use Lambda + CloudWatch to auto-stop dev instances
6. **Use gp3 EBS** -- pay only for IOPS and throughput you need
7. **Clean up snapshots** -- old EBS snapshots accumulate cost
8. **Avoid public IPv4** -- $0.005/hour per address since Feb 2024
