# Amazon MSK (Managed Streaming for Apache Kafka) -- Complete Knowledge Base

> This document is the plain-English reference for Amazon MSK that the pipeline
> engine framework and developer agent can consult when handling any MSK-related
> request in a pipeline. It covers what MSK is, how it works, every feature,
> integration patterns, networking, security, and troubleshooting.

---

## 1. What Is Amazon MSK?

Amazon MSK is a fully managed Apache Kafka service. You create a cluster, MSK
provisions and manages the Kafka brokers and ZooKeeper nodes, and you connect
using standard Kafka clients. MSK handles patching, scaling, and monitoring.

Unlike AWS-native streaming services (Kinesis Streams, SQS), MSK runs real
Apache Kafka. This means you use standard Kafka client libraries (kafka-python,
confluent-kafka, Java Kafka clients) and the full Kafka ecosystem (Kafka
Connect, Kafka Streams, Schema Registry, etc.).

### Core Concepts

- **Cluster**: A set of Kafka broker nodes managed by MSK. Can be provisioned
  (fixed instances) or serverless (auto-scaled).
- **Broker**: A Kafka server instance. Each broker runs on an EC2 instance with
  EBS storage. A cluster has 2-90 brokers distributed across AZs.
- **Topic**: A named category for messages. Topics are partitioned and replicated
  across brokers. Managed via Kafka AdminClient, NOT AWS APIs.
- **Partition**: An ordered, immutable sequence of messages within a topic.
  Parallelism unit for producers and consumers.
- **Consumer Group**: A set of consumers that cooperate to consume a topic.
  Each partition is assigned to exactly one consumer in the group.
- **Bootstrap Brokers**: Connection strings used by Kafka clients. Different
  strings for different authentication methods (plaintext, TLS, SASL/SCRAM, IAM).
- **ZooKeeper**: Metadata management service (hidden behind MSK -- you typically
  do not interact with it directly). Being replaced by KRaft in newer versions.

### NOT Free Tier

MSK is never free tier eligible. Costs:
- **Provisioned**: ~$0.11/broker-hour (kafka.t3.small, smallest) + EBS storage
- **Serverless**: ~$0.01/cluster-hour + $0.10/partition-hour + $0.10/GB in/out
- Additional: inter-AZ data transfer, enhanced monitoring

---

## 2. Cluster Types

### Provisioned Clusters

Traditional MSK clusters with fixed broker instances. You choose:
- **Instance type**: kafka.t3.small (dev) to kafka.m5.24xlarge (production)
- **Number of brokers**: Must be a multiple of the number of AZs (subnets)
- **EBS volume size**: 1 GB to 16 TiB per broker

You manage capacity by adding brokers, increasing storage, or changing instance
types. All changes trigger rolling restarts (no downtime for multi-AZ clusters).

### Serverless Clusters

Auto-scaling MSK clusters. No broker management, no capacity planning. Pay per
partition-hour and data throughput.

**Limitations**:
- IAM authentication only (no SASL/SCRAM or mTLS)
- Cannot configure broker settings
- Max 120 partitions per cluster (default)
- Limited Kafka version selection
- No ZooKeeper access

**Best for**: Variable workloads, development, or when you want zero operations.

### Choosing Between Provisioned and Serverless

| Factor | Provisioned | Serverless |
|---|---|---|
| **Cost model** | Per broker-hour (predictable) | Per partition-hour + data (variable) |
| **Scaling** | Manual (add brokers, increase storage) | Automatic |
| **Authentication** | IAM, SASL/SCRAM, mTLS, plaintext | IAM only |
| **Configuration** | Full server.properties control | Limited |
| **Operations** | Medium (you manage capacity) | Zero |
| **Best for** | Production, high throughput, custom config | Dev, variable load |

---

## 3. Broker Instance Types

| Type | vCPU | Memory | Max Partitions | Network | Cost/hr |
|---|---|---|---|---|---|
| kafka.t3.small | 2 | 2 GB | 300 | Up to 5 Gbps | ~$0.11 |
| kafka.m5.large | 2 | 8 GB | 1000 | Up to 10 Gbps | ~$0.21 |
| kafka.m5.xlarge | 4 | 16 GB | 1500 | Up to 10 Gbps | ~$0.42 |
| kafka.m5.2xlarge | 8 | 32 GB | 2000 | Up to 10 Gbps | ~$0.84 |
| kafka.m5.4xlarge | 16 | 64 GB | 4000 | 10 Gbps | ~$1.68 |
| kafka.m7g.large | 2 | 8 GB | 1000 | Up to 12.5 Gbps | ~$0.19 |

The pipeline engine defaults to `kafka.t3.small` (smallest, cheapest) for
minimum cost. Production clusters typically use `kafka.m5.large` or larger.

Graviton3-based instances (kafka.m7g.*) offer ~20% better price-performance
than m5 instances.

---

## 4. Topics and Partitions

Topics and partitions are managed using standard Kafka tools, NOT AWS APIs (boto3).

### Creating Topics

```python
from kafka.admin import KafkaAdminClient, NewTopic

admin = KafkaAdminClient(
    bootstrap_servers=bootstrap_brokers,
    security_protocol='SASL_SSL',
    sasl_mechanism='AWS_MSK_IAM',
    # ... IAM auth config
)

topic = NewTopic(
    name='my-topic',
    num_partitions=3,
    replication_factor=3
)
admin.create_topics([topic])
```

### Key Topic Configurations

| Config | Default | Description |
|---|---|---|
| `retention.ms` | 604800000 (7d) | How long messages are kept |
| `retention.bytes` | -1 (unlimited) | Max bytes per partition |
| `cleanup.policy` | delete | `delete` or `compact` |
| `compression.type` | producer | `none`, `gzip`, `snappy`, `lz4`, `zstd` |
| `max.message.bytes` | 1048588 | Max record batch size |
| `min.insync.replicas` | 1 | Min ISR for `acks=all` (set to RF-1) |

### Partition Guidelines

- More partitions = more parallelism (one consumer per partition in a group)
- Typical: 3-12 partitions per topic for moderate throughput
- Each partition adds memory and file handle overhead on brokers
- Max ~4000 partitions per broker (depends on instance type)

---

## 5. Authentication

MSK supports four authentication methods. You can enable multiple simultaneously.

### IAM Authentication (Recommended)

Uses AWS IAM policies and SigV4 signing. No passwords to manage. Each Kafka
operation maps to an IAM action.

| Kafka Operation | IAM Action |
|---|---|
| Connect to cluster | `kafka-cluster:Connect` |
| Create topic | `kafka-cluster:CreateTopic` |
| Produce messages | `kafka-cluster:WriteData` |
| Consume messages | `kafka-cluster:ReadData` |
| Join consumer group | `kafka-cluster:AlterGroup` |
| Describe topic | `kafka-cluster:DescribeTopic` |

Port: 9098. Bootstrap attribute: `BootstrapBrokerStringSaslIam`.

### SASL/SCRAM-SHA-512

Username/password authentication via AWS Secrets Manager. Each secret contains
`{"username": "...", "password": "..."}` and is associated with the cluster via
`aws_msk_scram_secret_association`.

Port: 9096. Bootstrap attribute: `BootstrapBrokerStringSaslScram`.

### Mutual TLS (mTLS)

Client certificate authentication using AWS Private Certificate Authority. Clients
present a certificate signed by the configured CA.

Port: 9094. Bootstrap attribute: `BootstrapBrokerStringTls`.

### Unauthenticated (Development Only)

No authentication. Not recommended for production.

Port: 9092. Bootstrap attribute: `BootstrapBrokerString`.

---

## 6. Encryption

### At Rest

All data on EBS volumes is encrypted with KMS. By default, uses the AWS-managed
key `aws/kafka`. You can specify a customer-managed KMS key.

### In Transit

TLS encryption between clients and brokers. Three options:
- `TLS`: Encrypted connections only (recommended)
- `TLS_PLAINTEXT`: Both encrypted and plaintext (for migration)
- `PLAINTEXT`: No encryption (development only)

Broker-to-broker traffic is always TLS-encrypted (cannot be disabled).

---

## 7. Networking

### VPC Requirement

MSK clusters MUST be deployed in a VPC. This is the most important networking
constraint. Brokers are placed in private subnets across availability zones.

### Subnets

- One subnet per AZ
- Number of subnets determines the number of AZs
- Number of broker nodes must be a multiple of the number of subnets
- Use private subnets (MSK does not support public subnets for brokers)

Example: 3 subnets (us-east-1a, 1b, 1c) with 6 brokers = 2 brokers per AZ.

### Security Groups

The MSK security group controls which clients can connect:

```hcl
resource "aws_security_group" "msk_sg" {
  ingress {
    from_port   = 9092
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]   # or specific client SG
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

The pipeline engine renderer creates this security group with ports 9092-9096
open to 10.0.0.0/8 by default.

### Cross-VPC Access

For services in different VPCs:
- **VPC Peering**: Connect VPCs directly
- **PrivateLink** (Multi-VPC Connectivity): AWS-managed PrivateLink endpoints
- **Transit Gateway**: Hub-and-spoke connectivity

### Lambda Connectivity

Lambda functions connecting to MSK need:
- VPC configuration (same VPC or connected VPC)
- Security group with access to MSK broker ports
- ENI permissions (`ec2:CreateNetworkInterface`, etc.)

---

## 8. Integration Patterns in the Pipeline Engine

### MSK as a Data Source (Services Read from MSK)

| Consumer | How It Connects | Terraform Resource |
|---|---|---|
| **Lambda** | Event source mapping | `aws_lambda_event_source_mapping` |
| **Kinesis Firehose** | MSK source config | `msk_source_configuration` block |
| **Kinesis Analytics (Flink)** | Kafka connector in code | VPC config on application |
| **EMR (Spark/Flink)** | Kafka connector | VPC connectivity |
| **EC2** | kafka-python/confluent-kafka | Security group access |
| **MSK Connect** | Kafka Connect source | `aws_mskconnect_connector` |

### MSK as a Data Sink (Services Write to MSK)

| Producer | How It Connects |
|---|---|
| **Lambda** | kafka-python client in VPC |
| **EC2** | kafka-python/confluent-kafka |
| **EMR** | Kafka connector |
| **Kinesis Analytics (Flink)** | Kafka sink connector |
| **DMS** | MSK target endpoint |
| **MSK Connect** | Kafka Connect sink |

### Wiring Ownership

The MSK renderer (`_render_msk`) owns:
- The MSK cluster resource
- CloudWatch Log Group for broker logs
- Security group for broker access

Other renderers own the wiring:
- Lambda renderer: `aws_lambda_event_source_mapping` for MSK topics
- Firehose renderer: `msk_source_configuration` block
- Analytics renderer: VPC configuration for Flink applications

---

## 9. Terraform Pattern in the Pipeline Engine

The `_render_msk` function generates:

1. **CloudWatch Log Group** (`/aws/msk/{name}`) for broker logs
2. **Security Group** with ingress 9092-9096, egress all
3. **MSK Cluster** with:
   - Kafka version (default 3.5.1)
   - Broker node group info (instance type, subnets, security groups, EBS)
   - Encryption in transit (TLS)
   - Logging to CloudWatch Logs

```hcl
resource "aws_msk_cluster" "LABEL" {
  cluster_name           = "NAME"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = data.aws_subnets.default.ids
    security_groups = [aws_security_group.LABEL_sg.id]
    storage_info {
      ebs_storage_info { volume_size = 1 }
    }
  }

  encryption_info {
    encryption_in_transit { client_broker = "TLS" }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.LABEL_lg.name
      }
    }
  }

  tags = { ... }
}
```

Note: The renderer uses `data.aws_subnets.default.ids` for subnets, which is
the default VPC's subnets. For production, this should be replaced with
specific private subnet IDs.

---

## 10. MSK Connect

MSK Connect is a managed Kafka Connect service. It lets you deploy connectors
(source and sink) without managing Connect infrastructure.

### Common Connectors

**Source connectors** (read data INTO Kafka):
- Debezium CDC (MySQL, PostgreSQL, MongoDB)
- S3 Source Connector
- JDBC Source Connector

**Sink connectors** (write data OUT of Kafka):
- S3 Sink Connector
- Elasticsearch/OpenSearch Sink
- JDBC Sink Connector
- Redshift Sink Connector

### How to Deploy a Connector

1. Package connector JARs into a ZIP
2. Upload to S3
3. Create a custom plugin: `aws_mskconnect_custom_plugin`
4. Create a connector: `aws_mskconnect_connector` referencing the plugin

---

## 11. Cluster Configuration

Custom Kafka broker configuration is managed via MSK Configuration resources.

### Important Settings for Production

```properties
auto.create.topics.enable = false      # Prevent accidental topic creation
default.replication.factor = 3         # For 3-AZ clusters
min.insync.replicas = 2                # Requires 2 of 3 replicas for acks=all
num.partitions = 3                     # Default partitions for auto-created topics
log.retention.hours = 168              # 7 days default
unclean.leader.election.enable = false # Prevent data loss on leader failure
```

### Applying Configuration Changes

Configuration changes trigger a rolling restart of brokers. In a multi-AZ
cluster, one broker restarts at a time, so there is no downtime. The update
takes ~15-30 minutes depending on cluster size.

---

## 12. Monitoring

### CloudWatch Metrics (AWS/Kafka namespace)

**DEFAULT level (free)**:
- `ActiveControllerCount`: Should always be 1
- `OfflinePartitionsCount`: Should always be 0
- `KafkaDataLogsDiskUsed`: Storage utilization
- `GlobalPartitionCount` / `GlobalTopicCount`: Cluster-wide counts

**PER_BROKER level (extra cost)**:
- `BytesInPerSec` / `BytesOutPerSec`: Throughput per broker
- `CpuUser` / `CpuSystem`: CPU utilization
- `MemoryFree`: Available memory
- `MessagesInPerSec`: Message rate
- `UnderReplicatedPartitions`: Replication health

**PER_TOPIC_PER_BROKER level (highest cost)**:
- Same metrics broken down by topic

### Broker Logs

Broker logs can be sent to:
- CloudWatch Logs (`/aws/msk/{cluster_name}`)
- S3 bucket
- Kinesis Firehose delivery stream

The pipeline engine enables CloudWatch Logs by default.

### Open Monitoring (Prometheus)

MSK can export JMX and Node metrics to Prometheus. Useful when you have an
existing Prometheus/Grafana monitoring stack.

---

## 13. Common Error Patterns and Fixes

### Connection Refused

**Cause**: Client cannot reach MSK brokers. Security group does not allow
the client's IP/security group on ports 9092-9098.

**Fix**: Add inbound rule to MSK security group allowing TCP 9092-9098 from
the client's security group.

### TopicAuthorizationException

**Cause**: IAM policy missing `kafka-cluster:ReadData` or `kafka-cluster:WriteData`.

**Fix**: Add the required `kafka-cluster:*` actions to the client's IAM policy.
The resource ARN format is:
```
arn:aws:kafka:REGION:ACCOUNT:topic/CLUSTER-NAME/UUID/TOPIC-NAME
```

### SSL Handshake Failed

**Cause**: Client not configured for TLS, or using the wrong port.

**Fix**: Use port 9094 (TLS), 9096 (SASL/SCRAM), or 9098 (IAM). Set
`security.protocol=SASL_SSL` or `security.protocol=SSL`.

### UnknownTopicOrPartitionException

**Cause**: Topic does not exist.

**Fix**: Create the topic first:
```python
admin.create_topics([NewTopic('my-topic', num_partitions=3, replication_factor=3)])
```
Or set `auto.create.topics.enable=true` in cluster configuration (not
recommended for production).

### NotEnoughReplicasException

**Cause**: Not enough in-sync replicas (ISR) to satisfy `min.insync.replicas`.

**Fix**: Check broker health. Wait for brokers to recover. If a broker is
permanently lost, increase broker count.

### Broker Count Validation Error

**Cause**: `number_of_broker_nodes` is not a multiple of the number of AZs.

**Fix**: If you have 3 subnets (3 AZs), use 3, 6, 9, etc. brokers.

---

## 14. Best Practices

1. **Use IAM authentication** for simplicity. No passwords to manage, no
   certificate infrastructure. Works with Lambda, EC2, EMR, etc.

2. **Use 3 AZs** for production clusters. This provides high availability
   and allows `min.insync.replicas = 2` with `replication_factor = 3`.

3. **Size broker instances based on throughput**. kafka.t3.small for dev,
   kafka.m5.large for production, kafka.m5.4xlarge for high throughput.

4. **Monitor disk usage**. EBS volumes cannot be shrunk, and running out of
   disk causes broker failures. Set up CloudWatch alarms on
   `KafkaDataLogsDiskUsed`.

5. **Set `min.insync.replicas` to replication_factor - 1**. This prevents
   data loss when a broker fails while still allowing writes.

6. **Use `auto.create.topics.enable = false`** in production. Accidental
   topic creation from typos is a common issue.

7. **Plan for MSK Connect** if you need CDC from databases. Debezium + MSK
   Connect is the standard pattern for real-time database replication.

8. **Keep broker count as a multiple of AZ count**. Uneven distribution
   causes hot spots and wastes capacity.

---

## 15. MSK vs Kinesis Streams vs SQS

| Feature | MSK | Kinesis Streams | SQS |
|---|---|---|---|
| **Protocol** | Apache Kafka | AWS proprietary | AWS proprietary |
| **Ecosystem** | Full Kafka ecosystem | AWS SDK only | AWS SDK only |
| **Ordering** | Per-partition | Per-shard | FIFO only |
| **Retention** | Unlimited (configurable) | 24h-365d | 4d-14d |
| **Consumers** | Consumer groups | Multiple (EFO) | Single (competing) |
| **Authentication** | IAM, SASL/SCRAM, mTLS | IAM | IAM |
| **Networking** | VPC required | Regional (no VPC) | Regional (no VPC) |
| **Operations** | Medium (manage capacity) | Low (ON_DEMAND) | Zero |
| **Cost** | Per broker-hour | Per shard-hour | Per request |
| **Best for** | Kafka ecosystem, high throughput, CDC | Real-time analytics | Task queues |

Choose MSK when you:
- Need the Kafka ecosystem (Connect, Streams, Schema Registry)
- Have existing Kafka expertise
- Need unlimited retention
- Need CDC from databases (Debezium)
- Need high throughput with many consumer groups

Choose Kinesis Streams when:
- You want a simpler, fully managed service
- You do not need the Kafka ecosystem
- You want ON_DEMAND auto-scaling

---

## 16. Developer Agent Patterns

**Getting bootstrap brokers**:
```python
kafka_client = boto3.client('kafka')
clusters = kafka_client.list_clusters_v2(ClusterNameFilter='my-cluster')
cluster_arn = clusters['ClusterInfoList'][0]['ClusterArn']

brokers = kafka_client.get_bootstrap_brokers(ClusterArn=cluster_arn)
bootstrap = brokers['BootstrapBrokerStringSaslIam']
```

**Producing messages** (using kafka-python with IAM):
```python
from kafka import KafkaProducer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

tp = MSKAuthTokenProvider(region='us-east-1')
producer = KafkaProducer(
    bootstrap_servers=bootstrap_brokers.split(','),
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=tp,
    value_serializer=lambda v: json.dumps(v).encode()
)
producer.send('my-topic', {'key': 'value'})
producer.flush()
```

**Consuming messages**:
```python
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers=bootstrap_brokers.split(','),
    group_id='my-group',
    auto_offset_reset='earliest',
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=tp,
    value_deserializer=lambda v: json.loads(v.decode())
)
for message in consumer:
    print(message.value)
```

**Checking cluster status**:
```python
cluster = kafka_client.describe_cluster_v2(ClusterArn=cluster_arn)
state = cluster['ClusterInfo']['State']  # ACTIVE, CREATING, DELETING, etc.
```

**Creating topics** (not boto3 -- uses Kafka AdminClient):
```python
from kafka.admin import KafkaAdminClient, NewTopic

admin = KafkaAdminClient(
    bootstrap_servers=bootstrap_brokers.split(','),
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=tp,
)
admin.create_topics([
    NewTopic('events', num_partitions=6, replication_factor=3)
])
```
