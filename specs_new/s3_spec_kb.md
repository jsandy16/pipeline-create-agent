# Amazon S3 — Complete Knowledge Base

> This document is the plain-English reference for S3 that the pipeline engine
> framework and developer agent can consult when handling any S3-related request
> in a pipeline. It covers what S3 is, how it works, every feature, integration
> patterns, security, performance, and troubleshooting — written for an agent
> that needs to reason about S3 in context, not just look up API parameters.

---

## 1. What Is S3?

Amazon Simple Storage Service (S3) is an object storage service. You store data
as **objects** (files + metadata) inside **buckets** (named containers). Every
object has a unique **key** (its path within the bucket). S3 is designed for
99.999999999% (eleven 9s) durability and 99.99% availability.

S3 is **not** a filesystem — there are no real directories. The "/" in a key
like `data/2024/report.csv` is just a character. However, the ListObjectsV2 API
supports a "delimiter" parameter that lets you simulate folder-like browsing.

### Core Concepts
- **Bucket**: A globally unique named container. Region-specific.
- **Object**: A file + metadata, identified by a key (up to 1024 bytes UTF-8).
- **Key**: The full "path" of an object within a bucket.
- **Version ID**: When versioning is enabled, each object version gets a unique ID.
- **ETag**: A hash of the object content (MD5 for non-multipart, composite for multipart).
- **Metadata**: System metadata (Content-Type, Last-Modified) + up to 2 KB user-defined.

### Free Tier
S3 is always-free tier eligible: 5 GB Standard storage, 20,000 GET requests,
and 2,000 PUT requests per month. Beyond that, you pay per GB stored per month,
per request, and per GB transferred out.

---

## 2. Bucket Naming Rules

Bucket names must be **globally unique** across all AWS accounts in the partition.
This is one of the most common sources of errors.

**Rules:**
- 3–63 characters long
- Only lowercase letters (a-z), digits (0-9), and hyphens (-)
- Must start and end with a letter or digit
- No consecutive hyphens (`my--bucket` is invalid)
- Cannot look like an IP address (e.g., `192.168.1.1`)
- No underscores, no uppercase, no dots (we exclude dots because they break
  SSL virtual-hosted-style addressing and Transfer Acceleration)
- Cannot start with `xn--`, `sthree-`, or `amzn-s3-demo-`
- Cannot end with `-s3alias`, `--ol-s3`, `.mrap`, `--x-s3`, or `--table-s3`

**Best practice**: Use account-regional namespace buckets
(`name-ACCOUNT-REGION-an`) for guaranteed uniqueness to your account.

---

## 3. Storage Classes

S3 offers multiple storage classes for different access patterns and cost
trade-offs. The default is STANDARD. Our pipeline engine always uses STANDARD
(free tier) unless the user explicitly requests otherwise.

| Storage Class | Access Pattern | Retrieval Time | Min Duration | Retrieval Fee |
|---|---|---|---|---|
| **STANDARD** | Frequent | Milliseconds | None | No |
| **INTELLIGENT_TIERING** | Unknown/changing | Variable | None | No (monitoring fee) |
| **STANDARD_IA** | Infrequent (monthly) | Milliseconds | 30 days | Yes |
| **ONEZONE_IA** | Infrequent, recreatable | Milliseconds | 30 days | Yes |
| **GLACIER_IR** | Rare (quarterly) | Milliseconds | 90 days | Yes |
| **GLACIER** | Rare (yearly) | Minutes to hours | 90 days | Yes |
| **DEEP_ARCHIVE** | Very rare (<yearly) | Hours | 180 days | Yes |
| **EXPRESS_ONEZONE** | Ultra-low latency | Sub-millisecond | None | No |

**Key insight for agents**: Glacier and Deep Archive objects cannot be read
directly — you must call `restore_object` first and wait for the restore to
complete. This is a common source of "InvalidObjectState" errors.

### Storage Class Transitions (Lifecycle)

Objects can only transition "downward" in the waterfall:

```
STANDARD
  → INTELLIGENT_TIERING, STANDARD_IA, ONEZONE_IA, GLACIER_IR, GLACIER, DEEP_ARCHIVE

STANDARD_IA
  → INTELLIGENT_TIERING, ONEZONE_IA, GLACIER_IR, GLACIER, DEEP_ARCHIVE

INTELLIGENT_TIERING
  → ONEZONE_IA, GLACIER_IR, GLACIER, DEEP_ARCHIVE

ONEZONE_IA
  → GLACIER, DEEP_ARCHIVE

GLACIER_IR
  → GLACIER, DEEP_ARCHIVE

GLACIER
  → DEEP_ARCHIVE

DEEP_ARCHIVE
  → (nothing — terminal)
```

**Constraint**: Objects must stay in STANDARD for at least 30 days before
transitioning to STANDARD_IA or ONEZONE_IA. Objects < 128 KB won't transition
by default.

---

## 4. Encryption

**Every S3 bucket is encrypted by default** since January 5, 2023. The default
is SSE-S3 (AES-256, Amazon-managed keys, free).

### Encryption Types

| Type | Keys Managed By | Cost | Audit | Cross-Account |
|---|---|---|---|---|
| **SSE-S3** | Amazon S3 | Free | No CloudTrail key logs | N/A |
| **SSE-KMS** | AWS KMS | KMS API charges | Full CloudTrail audit | Requires customer-managed key |
| **DSSE-KMS** | AWS KMS | Higher KMS charges | Full audit | Requires customer-managed key |
| **SSE-C** | Customer (you) | Free | You manage keys | N/A |

**When to use SSE-KMS**: When you need audit trail for key usage, key rotation
control, or cross-account data sharing with encryption.

**S3 Bucket Keys**: When using SSE-KMS, enable Bucket Keys to reduce KMS API
calls by up to 99%. This is a significant cost optimization.

**Important**: SSE-KMS encrypted objects cannot be served via S3 static website
hosting endpoints. Use CloudFront with Origin Access Control instead.

### KMS Permissions Required
- For uploads (`PutObject`): `kms:GenerateDataKey`
- For downloads (`GetObject`): `kms:Decrypt`
- For multipart uploads: both `kms:GenerateDataKey` and `kms:Decrypt`

---

## 5. Versioning

Versioning keeps every version of every object. Once enabled, it **cannot be
turned off** — only suspended.

**Three states**: Unversioned (default) → Enabled → Suspended

**How deletes work with versioning enabled**:
- A simple DELETE (no version ID) creates a "delete marker" — the object
  appears deleted but all previous versions still exist
- A DELETE with a specific version ID permanently removes that version
- To truly delete: remove every version + every delete marker

**Cost impact**: Each version is stored as a complete object and billed
separately. A 1 MB file overwritten 10 times = 10 MB billed.

**MFA Delete**: Optional extra protection requiring MFA for permanent deletes
and versioning state changes.

**Required for**: S3 Replication and S3 Object Lock both require versioning.

---

## 6. Lifecycle Management

Lifecycle rules automate transitioning objects between storage classes and
deleting expired objects. Up to 1,000 rules per bucket.

### Rule Actions
1. **Transition** — move to a cheaper storage class after N days
2. **Expiration** — delete objects after N days
3. **Noncurrent version transition** — transition old versions
4. **Noncurrent version expiration** — delete old versions
5. **Abort incomplete multipart upload** — clean up abandoned uploads

### Filtering
Rules can target objects by:
- Key prefix (`logs/`)
- Object tags (`environment=production`)
- Object size range
- Combination of all three with AND logic

**Important**: Lifecycle rules cannot be blocked by bucket policies. S3
lifecycle operates regardless of policy restrictions.

**Best practice**: Always set an "abort incomplete multipart upload" rule
(e.g., 7 days) to prevent storage charges from abandoned uploads.

---

## 7. Event Notifications

S3 can notify other services when objects are created, deleted, or modified.
This is the primary mechanism for building event-driven pipelines.

### Destinations
1. **AWS Lambda** — invoke a function (most common in our pipelines)
2. **Amazon SQS** — send message to a queue (standard only, NOT FIFO)
3. **Amazon SNS** — publish to a topic (standard only, NOT FIFO)
4. **Amazon EventBridge** — route to any EventBridge target

### Event Types
The most commonly used:
- `s3:ObjectCreated:*` — any new object (Put, Post, Copy, CompleteMultipartUpload)
- `s3:ObjectRemoved:*` — any deletion
- `s3:ObjectCreated:Put` — only PUT uploads
- `s3:ObjectRestore:Completed` — Glacier restore done
- `s3:LifecycleTransition` — object moved to different storage class

Full list includes: ObjectCreated (Put/Post/Copy/CompleteMultipartUpload),
ObjectRemoved (Delete/DeleteMarkerCreated), ObjectRestore (Post/Completed/Delete),
Replication events, LifecycleExpiration, LifecycleTransition,
IntelligentTiering, ObjectTagging (Put/Delete), ObjectAcl:Put, TestEvent,
ReducedRedundancyLostObject.

### Filtering
Notifications can be filtered by key prefix and/or suffix. For example:
- Prefix: `uploads/` — only objects under the uploads/ prefix
- Suffix: `.csv` — only CSV files

### EventBridge Fan-Out Pattern
When multiple Lambda functions need to react to the same event type on the same
bucket, S3 native notifications have a limitation: you can't have two
`lambda_function` blocks with the same event type and no distinct prefix/suffix
filters. Our pipeline engine detects this overlap and automatically switches to
EventBridge fan-out:
1. Enable `eventbridge = true` on the bucket notification
2. Create an EventBridge rule per event type
3. Add each Lambda as a target on the rule

### Delivery Guarantees
- **At-least-once delivery** — events may be delivered more than once
- **Typical latency**: seconds, but can take a minute or longer
- **No ordering guarantee**

### Warning: Avoid Recursive Loops
Never configure a notification that writes back to the same bucket that
triggered it without prefix/suffix filtering. This creates an infinite loop.

---

## 8. Replication

### Types
- **CRR (Cross-Region Replication)**: Copy objects to a bucket in another region.
  Used for compliance, latency reduction, disaster recovery.
- **SRR (Same-Region Replication)**: Copy objects to another bucket in the same
  region. Used for log aggregation, prod/test sync, data sovereignty.
- **Batch Replication**: Replicate existing objects on demand.

### Requirements
- Versioning must be enabled on **both** source and destination buckets
- An IAM role with permissions to read from source and write to destination
- If cross-account: destination bucket policy must allow the source role

### What Gets Replicated
- New objects created after replication is enabled
- Object metadata, tags, and ACLs
- **NOT** pre-existing objects (use Batch Replication for those)
- **NOT** objects encrypted with SSE-C
- **NOT** objects in Glacier/Deep Archive (unless restored first)

### Replication Time Control (RTC)
SLA-backed guarantee: 99.99% of objects replicated within 15 minutes.
Additional cost. Use when predictable replication time is required.

---

## 9. Access Control

S3 has multiple layers of access control. The recommended approach (and our
pipeline engine default) is: **bucket policies + IAM policies, with ACLs
disabled**.

### Block Public Access (BPA)
Four settings, all enabled by default on new buckets:
1. **BlockPublicAcls** — reject PUT calls with public ACLs
2. **IgnorePublicAcls** — ignore existing public ACLs
3. **BlockPublicPolicy** — reject bucket policies that grant public access
4. **RestrictPublicBuckets** — restrict cross-account access to public buckets

**Recommendation**: Keep all four enabled. Only disable selectively for
specific use cases like static website hosting.

### Object Ownership
- **BucketOwnerEnforced** (default, recommended): ACLs disabled. Bucket owner
  owns all objects. Access controlled only via policies.
- **BucketOwnerPreferred**: If upload includes `bucket-owner-full-control` ACL,
  bucket owner owns the object.
- **ObjectWriter**: Uploading account owns objects. ACLs active.

### Bucket Policies
JSON-based policies attached to the bucket. Max 20 KB. Common patterns:
- **SSL enforcement**: Deny all actions where `aws:SecureTransport = false`
- **IP restriction**: Allow/deny based on `aws:SourceIp`
- **VPC endpoint**: Restrict to `aws:sourceVpce`
- **Cross-account**: Allow specific principal ARN from another account
- **Organization**: Allow based on `aws:PrincipalOrgID`
- **MFA required**: Deny where `aws:MultiFactorAuthAge` is null

### Access Points
Named network endpoints attached to a bucket. Used to simplify access
management for shared datasets:
- Each access point has its own policy (max 20 KB)
- Can restrict to VPC-only access
- Support object-level operations only (not bucket-level)
- ARN format: `arn:aws:s3:REGION:ACCOUNT:accesspoint/NAME`

### VPC Endpoints
S3 supports Gateway VPC Endpoints — traffic stays within the AWS network,
never traversing the public internet. Recommended for security-sensitive
workloads.

---

## 10. IAM Permissions Reference

S3 has 150+ IAM actions. Here are the ones most relevant to pipeline work:

### Object Operations
| Action | What It Controls |
|---|---|
| `s3:GetObject` | Download objects (also HeadObject, SelectObjectContent) |
| `s3:PutObject` | Upload objects (also multipart upload) |
| `s3:DeleteObject` | Delete objects (without version ID) |
| `s3:DeleteObjectVersion` | Permanently delete specific version |
| `s3:GetObjectVersion` | Download specific version |
| `s3:RestoreObject` | Restore from Glacier |
| `s3:GetObjectTagging` | Read object tags |
| `s3:PutObjectTagging` | Write object tags |
| `s3:AbortMultipartUpload` | Cancel incomplete multipart uploads |

### Bucket Operations
| Action | What It Controls |
|---|---|
| `s3:ListBucket` | List objects (ListObjectsV2, HeadBucket) |
| `s3:ListBucketVersions` | List object versions |
| `s3:GetBucketLocation` | Get bucket region |
| `s3:CreateBucket` | Create new bucket |
| `s3:DeleteBucket` | Delete empty bucket |
| `s3:PutBucketPolicy` | Set bucket policy |
| `s3:PutBucketNotification` | Configure event notifications |
| `s3:PutLifecycleConfiguration` | Set lifecycle rules |
| `s3:PutReplicationConfiguration` | Configure replication |
| `s3:PutEncryptionConfiguration` | Set default encryption |
| `s3:PutBucketVersioning` | Enable/suspend versioning |

### Replication-Specific
| Action | What It Controls |
|---|---|
| `s3:ReplicateObject` | Write replicated objects to destination |
| `s3:ReplicateDelete` | Replicate delete markers |
| `s3:ReplicateTags` | Replicate object tags |
| `s3:GetObjectVersionForReplication` | Read objects for replication |

### Common Permission Sets in Our Pipeline
- **Reader**: `s3:GetObject`, `s3:ListBucket`, `s3:GetBucketLocation`
- **Writer**: `s3:PutObject`, `s3:ListBucket`, `s3:GetBucketLocation`
- **Full access**: Reader + Writer + `s3:DeleteObject`
- **Firehose to S3**: Writer + `s3:AbortMultipartUpload`, `s3:ListBucketMultipartUploads`

### ARN Formats
- Bucket: `arn:aws:s3:::BUCKET-NAME`
- All objects: `arn:aws:s3:::BUCKET-NAME/*`
- Prefix: `arn:aws:s3:::BUCKET-NAME/PREFIX/*`
- Access point: `arn:aws:s3:REGION:ACCOUNT:accesspoint/NAME`

---

## 11. Performance

### Request Rate Limits
- **5,500 GET/HEAD** requests per second per prefix
- **3,500 PUT/COPY/POST/DELETE** requests per second per prefix
- No limit on the number of prefixes in a bucket

**Scaling strategy**: Spread objects across many prefixes to multiply throughput.
Example: 10 prefixes = 55,000 reads/second.

### Multipart Upload
For objects larger than 100 MB, use multipart upload:
- Split into 5 MB–5 GB parts (up to 10,000 parts)
- Upload parts in parallel for maximum throughput
- If a part fails, only retry that part
- **Always** configure an `AbortIncompleteMultipartUpload` lifecycle rule

### Transfer Acceleration
Uses CloudFront edge locations to speed up long-distance transfers:
- Endpoint: `BUCKET.s3-accelerate.amazonaws.com`
- Bucket name must not contain dots
- Takes ~20 minutes to activate

### Single Connection
- Up to 100 Gbps on a single EC2 instance
- First-byte latency: 100–200 ms
- Use byte-range fetches (`Range` header) for parallel downloads of large objects

---

## 12. Static Website Hosting

S3 can serve static websites (HTML, CSS, JS, images) directly:
- Endpoint: `BUCKET.s3-website-REGION.amazonaws.com` (HTTP only)
- Configure index document (e.g., `index.html`) and error document
- Requires public read access (via bucket policy)

**Limitations**:
- HTTP only — for HTTPS, put CloudFront in front
- SSE-KMS objects cannot be served
- No server-side processing (static content only)

**Recommendation**: Use AWS Amplify Hosting or CloudFront distribution for
production websites.

---

## 13. Object Lock (WORM)

Write-Once-Read-Many model for regulatory compliance:

### Retention Modes
- **Governance**: Most users can't delete. Users with
  `s3:BypassGovernanceRetention` can override.
- **Compliance**: Nobody can delete, not even root. Period cannot be shortened.
  Meets SEC 17a-4, CFTC, FINRA.

### Legal Hold
An indefinite lock with no expiration date. Independent of retention period.
Both must be satisfied for an object to be deletable.

**Requirements**: Versioning must be enabled. Object Lock is set at bucket
creation time and cannot be added later.

---

## 14. CORS

Cross-Origin Resource Sharing configuration for browser-based access:
- Define allowed origins, methods, and headers
- Rules evaluated in order — first match wins
- CORS does not override bucket policies or ACLs
- S3 Object Lambda automatically adds `AllowedOrigins: *`

---

## 15. Service Quotas

| Quota | Limit |
|---|---|
| Max object size | 5 TiB |
| Max object size (console upload) | 160 GB |
| Max buckets per account | 10,000 (adjustable) |
| Max object key length | 1,024 bytes |
| Max metadata per object | 2 KB |
| Max tags per object | 10 |
| Max tags per bucket | 50 |
| Max bucket policy size | 20 KB |
| Max event notification configs | 100 per bucket |
| Max lifecycle rules | 1,000 per bucket |
| Max replication rules | 1,000 per bucket |
| Max replication destinations | 28 per source |
| Max access points per region | 10,000 |
| Max multipart parts | 10,000 |
| Min multipart part size | 5 MB |
| Max multipart part size | 5 GB |

---

## 16. Integration Patterns in Our Pipeline Engine

### S3 as Event Source (S3 → other services)

**S3 → Lambda** (most common):
The S3 renderer creates `aws_s3_bucket_notification` (lambda_function block)
and `aws_lambda_permission` (principal: s3.amazonaws.com). When overlapping
event types are detected, it automatically switches to EventBridge fan-out.

**S3 → SQS**:
The S3 renderer creates the notification (queue block). The SQS renderer
creates `aws_sqs_queue_policy` allowing `s3.amazonaws.com`.

**S3 → SNS**:
The S3 renderer creates the notification (topic block).

### S3 as Data Store (other services → S3)

These services need IAM permissions to read/write S3:

| Service | Reads S3 | Writes S3 | Key Permissions |
|---|---|---|---|
| Lambda | Yes | Yes | GetObject, PutObject, ListBucket |
| Glue (Crawler) | Yes | No | GetObject, ListBucket, GetBucketLocation |
| Kinesis Firehose | No | Yes | PutObject, ListBucket, AbortMultipartUpload |
| Athena | Yes | Yes (results) | GetObject, PutObject, ListBucket |
| EMR | Yes | Yes | GetObject, PutObject, ListBucket, DeleteObject |
| SageMaker | Yes | Yes | GetObject, PutObject, ListBucket |
| Lake Formation | Yes | Yes | GetObject, PutObject, ListBucket |
| Glue DataBrew | Yes | Yes | GetObject, PutObject, ListBucket |
| QuickSight | Yes | No | GetObject, ListBucket |
| DMS | Yes | Yes | GetObject, PutObject, ListBucket, DeleteObject |
| Step Functions | Yes | Yes | GetObject, PutObject, ListBucket |
| Redshift (COPY/UNLOAD) | Yes | Yes | GetObject, PutObject, ListBucket |

### Wiring Ownership
The S3 renderer **owns** notification wiring (it creates `aws_s3_bucket_notification`
and `aws_lambda_permission`). Other service renderers own their own IAM policies
that include S3 permissions.

---

## 17. Terraform Resources

### Always Created by S3 Renderer
1. `aws_s3_bucket` — the bucket with force_destroy=true and tags
2. `aws_s3_bucket_versioning` — versioning config (default: Suspended)
3. `aws_s3_bucket_server_side_encryption_configuration` — SSE config (default: AES256)

### Conditionally Created
- `aws_s3_bucket_notification` — when there are Lambda/SQS/SNS/EventBridge integrations
- `aws_lambda_permission` — when S3 triggers Lambda
- `aws_cloudwatch_event_rule` + `aws_cloudwatch_event_target` — EventBridge fan-out

### Available but Not Currently in Default Renderer
These can be added to the renderer when needed:
- `aws_s3_bucket_lifecycle_configuration`
- `aws_s3_bucket_replication_configuration`
- `aws_s3_bucket_cors_configuration`
- `aws_s3_bucket_logging`
- `aws_s3_bucket_website_configuration`
- `aws_s3_bucket_accelerate_configuration`
- `aws_s3_bucket_policy`
- `aws_s3_bucket_public_access_block`
- `aws_s3_bucket_ownership_controls`
- `aws_s3_bucket_object_lock_configuration`

---

## 18. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `NoSuchBucket` | Bucket doesn't exist | Check terraform apply, re-deploy |
| `NoSuchKey` | Object key doesn't exist | Verify key path, list bucket contents |
| `AccessDenied` | Missing IAM permissions | Add s3:GetObject/PutObject/etc. to role |
| `BucketAlreadyExists` | Name taken globally | Choose different name |
| `InvalidBucketName` | Naming rule violation | Fix: 3-63 chars, lowercase+digits+hyphens |
| `EntityTooLarge` | Object > 5 GB in single PUT | Use multipart upload |
| `SlowDown` | Request rate exceeded | Exponential backoff, spread across prefixes |
| `InvalidObjectState` | Glacier object not restored | Call restore_object, wait for completion |
| `KMS.NotFoundException` | KMS key missing/disabled | Verify key, check kms:Decrypt permissions |
| `BucketNotEmpty` | Cannot delete non-empty bucket | Empty bucket first, or force_destroy=true |
| `InvalidRequest` (SSE-C) | SSE-C disabled on bucket | Use SSE-S3 or SSE-KMS instead |
| `RequestTimeout` | Upload/download too slow | Check network, use Transfer Acceleration |

---

## 19. Security Best Practices

1. **Keep Block Public Access enabled** — all 4 settings
2. **Use BucketOwnerEnforced** — disable ACLs
3. **Enforce HTTPS** — bucket policy denying `aws:SecureTransport = false`
4. **Enable versioning** — protect against accidental deletes
5. **Use SSE-KMS with Bucket Keys** for sensitive data — audit trail + cost optimization
6. **Set lifecycle rules** — transition to cheaper storage, expire old data
7. **Abort incomplete multipart uploads** — lifecycle rule at 7 days
8. **Use VPC Endpoints** — keep traffic off the public internet
9. **Least privilege IAM** — only grant specific s3: actions on specific bucket ARNs
10. **Enable CloudTrail data events** — audit object-level API calls
11. **Consider Object Lock** for compliance data
12. **Use S3 Storage Lens** for visibility into storage usage and optimization

---

## 20. URL and Endpoint Formats

| Type | Format |
|---|---|
| Virtual-hosted (standard) | `https://BUCKET.s3.REGION.amazonaws.com/KEY` |
| Path-style (deprecated) | `https://s3.REGION.amazonaws.com/BUCKET/KEY` |
| Transfer Acceleration | `https://BUCKET.s3-accelerate.amazonaws.com/KEY` |
| Dual-stack (IPv4+IPv6) | `https://BUCKET.s3.dualstack.REGION.amazonaws.com/KEY` |
| Website | `http://BUCKET.s3-website-REGION.amazonaws.com/KEY` |
| Access Point | `https://AP-NAME-ACCOUNT.s3-accesspoint.REGION.amazonaws.com/KEY` |
| FIPS | `https://s3-fips.REGION.amazonaws.com/BUCKET/KEY` |

---

## 21. Pre-Signed URLs

Generate temporary URLs that grant access to specific objects without requiring
AWS credentials. Useful for:
- Sharing private objects with external users
- Browser-based uploads from untrusted clients
- Time-limited download links

**Parameters**: method (get_object/put_object), bucket, key, expiration (default
3600s, max 604800s = 7 days).

Two types:
- `generate_presigned_url()` — for GET/PUT via URL
- `generate_presigned_post()` — for browser form-based uploads

---

## 22. Monitoring in Our Pipeline

S3 has no native CloudWatch Log Group. For pipeline run monitoring, the log
aggregator uses **CloudTrail LookupEvents** filtered by bucket ARN. This has a
5–15 minute delivery delay compared to real-time CloudWatch Logs.

CloudWatch metrics are available under the `AWS/S3` namespace:
BucketSizeBytes, NumberOfObjects, AllRequests, GetRequests, PutRequests,
DeleteRequests, 4xxErrors, 5xxErrors, FirstByteLatency, TotalRequestLatency.
