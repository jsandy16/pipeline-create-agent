# AWS IAM -- Complete Knowledge Base

> This document is the plain-English reference for IAM that the pipeline engine
> framework and developer agent can consult when handling any IAM-related
> request in a pipeline. It covers what IAM is, how it works, policy evaluation
> logic, trust relationships, and how IAM underpins every service in the
> pipeline as the security backbone.

---

## 1. What Is IAM?

AWS Identity and Access Management (IAM) controls who can do what in your AWS
account. It is the security backbone of every AWS deployment. IAM manages:

- **Authentication**: Proving who you are (users, roles, federated identities)
- **Authorization**: What you are allowed to do (policies, permissions)
- **Auditing**: What you actually did (CloudTrail integration)

IAM is a **global service** -- not region-specific. Roles, users, and policies
are available in all regions. IAM is **always free** with no charges for any
IAM operations.

### Core Concepts
- **Principal**: An entity that can make requests (user, role, federated identity, AWS service)
- **Policy**: A JSON document that defines permissions (Allow/Deny on Actions for Resources)
- **Role**: An identity with permissions that can be assumed by services, users, or accounts
- **Trust Policy**: Defines WHO can assume a role
- **Permission Policy**: Defines WHAT the role can do
- **Resource-based Policy**: Attached to a resource (S3 bucket, SQS queue) defining who can access it

### IAM in Our Pipeline Engine

IAM appears in two forms in the pipeline engine:

1. **Standalone IAM role** (`iam` service type): The `_render_iam()` function
   creates a single `aws_iam_role` with a default Lambda trust policy. Used
   for cross-service permissions or custom trust relationships.

2. **Infrastructure for all principal services**: Every compute service
   (Lambda, Glue, EMR, SageMaker, Step Functions, etc.) automatically gets
   an IAM execution role and inline policy. The `_iam_role(bp, principal)`
   helper creates the role with the correct trust policy, and
   `_iam_policy(bp)` creates an inline policy with actions computed from
   the integration graph.

---

## 2. IAM Roles

Roles are the primary mechanism for granting permissions in our pipeline
engine. Unlike users (which have long-term credentials), roles provide
temporary credentials when assumed.

### Service Roles
When an AWS service needs to act on your behalf, it assumes a service role.
The trust policy specifies which service can assume the role.

**Common service principals in our pipeline:**

| Service | Trust Principal |
|---|---|
| Lambda | `lambda.amazonaws.com` |
| Glue | `glue.amazonaws.com` |
| EC2 | `ec2.amazonaws.com` |
| EMR | `elasticmapreduce.amazonaws.com` |
| EMR Serverless | `emr-serverless.amazonaws.com` |
| SageMaker | `sagemaker.amazonaws.com` |
| Step Functions | `states.amazonaws.com` |
| Kinesis Firehose | `firehose.amazonaws.com` |
| Kinesis Analytics | `kinesisanalytics.amazonaws.com` |
| DMS | `dms.amazonaws.com` |
| Redshift | `redshift.amazonaws.com` |
| MSK | `kafka.amazonaws.com` |
| Lake Formation | `lakeformation.amazonaws.com` |
| Glue DataBrew | `databrew.amazonaws.com` |
| EventBridge | `events.amazonaws.com` |

### Cross-Account Roles
Allow principals in another AWS account to assume a role in your account.
The trust policy specifies the source account:
```json
{
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::123456789012:root"},
  "Action": "sts:AssumeRole"
}
```

### Federation Roles
Allow external identities (OIDC, SAML) to assume a role:
- **OIDC**: GitHub Actions, GitLab CI, Google, EKS service accounts
- **SAML**: Active Directory, Okta, OneLogin

### Session Duration
Roles have a configurable maximum session duration (1-12 hours, default 1
hour). When a service or user assumes the role, credentials expire after
the session duration.

### EC2 Instance Profiles
EC2 instances cannot directly assume a role. They need an **instance profile**
-- a wrapper resource that contains the role. The instance profile is attached
to the EC2 instance at launch.

---

## 3. IAM Policies

### Policy Types

**Identity-based policies** (attached to users, groups, or roles):
- **AWS-managed**: Pre-built by AWS, maintained by AWS (e.g., `AmazonS3ReadOnlyAccess`)
- **Customer-managed**: You create and manage (max 6144 bytes, up to 5 versions)
- **Inline**: Embedded directly in a user, group, or role (max 2048 bytes each)

**Resource-based policies** (attached to resources):
- S3 bucket policies
- SQS queue policies
- SNS topic policies
- Lambda resource-based policies (`aws_lambda_permission`)
- KMS key policies
- IAM role trust policies

### Policy Structure
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

### Policy Evaluation Logic

IAM evaluates policies in this order:

1. **Explicit Deny**: If ANY policy says Deny, the request is DENIED. Period.
   This cannot be overridden.
2. **Organization SCP**: If no Allow in the SCP, DENIED.
3. **Resource-based policy**: If the resource policy Allows AND the request is
   same-account, ALLOWED (even without identity policy Allow).
4. **Permission boundary**: If set and no Allow, DENIED.
5. **Session policy**: If set and no Allow, DENIED.
6. **Identity-based policy**: If Allow, ALLOWED.
7. **Implicit Deny**: If nothing explicitly allows, DENIED.

**Cross-account**: Both the identity-based policy (in the caller's account)
AND the resource-based policy (in the resource's account) must Allow.

### Our Pipeline Engine's Approach

The engine uses **inline policies** on roles, computed from the integration
graph. The `_iam_policy(bp)` helper collects all IAM actions from:
- `spec.iam.always` -- actions every instance of this type needs
- `spec.iam.as_target_of.<peer_type>` -- actions needed when receiving from a peer
- `spec.iam.as_source_to.<peer_type>` -- actions needed when sending to a peer

This produces a single inline policy with all required permissions. The
actions are table lookups from spec YAML files, never LLM-generated.

---

## 4. Trust Policies

The trust policy (AssumeRolePolicyDocument) defines WHO can assume a role.
It is a JSON policy attached to the role itself.

### Service Trust Policy (most common in pipelines)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
```

### Common Conditions on Trust Policies
- **External ID** (`sts:ExternalId`): Prevents confused deputy in
  cross-account. The assuming principal must provide this value.
- **Source Account** (`aws:SourceAccount`): Restrict to specific account.
- **Source ARN** (`aws:SourceArn`): Restrict to specific resource.
- **MFA** (`aws:MultiFactorAuthPresent`): Require MFA authentication.

### iam:PassRole

The `iam:PassRole` permission is critical in pipeline contexts. When you
create a Lambda function and assign it an execution role, you need
`iam:PassRole` permission on that role. Without it, you get an
"AccessDenied" error.

Best practice: scope PassRole with the `iam:PassedToService` condition:
```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::ACCOUNT:role/my-lambda-role",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "lambda.amazonaws.com"
    }
  }
}
```

---

## 5. Permission Boundaries

A permission boundary is a managed policy that sets the MAXIMUM permissions
a role or user can have. The effective permissions are the INTERSECTION of
the identity policy and the boundary.

**Use case**: Delegated administration. Allow team leads to create IAM roles
for their services, but ensure those roles cannot exceed certain permissions
(e.g., cannot access production databases).

---

## 6. IAM Users and Groups

### Users
IAM users have long-term credentials (password and/or access keys). Best
practice is to minimize IAM user usage:
- Use **IAM Identity Center (SSO)** for human access
- Use **IAM roles** for application access
- If users are necessary, enable MFA and rotate access keys regularly

### Groups
Groups organize users and simplify permission management. Attach policies
to groups, not individual users.

**Constraints**:
- Groups cannot be nested
- A user can be in up to 10 groups
- Groups cannot be principals in resource policies

---

## 7. Identity Providers

### OIDC (OpenID Connect)
Connect external identity providers to AWS:
- **GitHub Actions**: Allow CI/CD workflows to assume IAM roles without
  storing AWS credentials
- **GitLab CI**: Same pattern
- **EKS**: IAM Roles for Service Accounts (IRSA) via EKS OIDC provider
- **Google/Okta**: Employee identity federation

### SAML
Connect enterprise identity systems (Active Directory, Okta, OneLogin) to
AWS. Users authenticate with their corporate credentials and get temporary
AWS credentials.

### IAM Identity Center (SSO)
AWS's recommended approach for human access. Provides:
- Single sign-on across multiple AWS accounts
- Integration with external identity providers
- Permission sets (templates for IAM permissions)

---

## 8. Service-Linked Roles

AWS services can create and manage roles on your behalf. These have:
- Fixed trust policies
- Fixed permissions
- Cannot be modified by users
- Path: `/aws-service-role/`

Common examples: EMR (`AWSServiceRoleForEMR`), Redshift
(`AWSServiceRoleForRedshift`), Auto Scaling
(`AWSServiceRoleForAutoScaling`).

---

## 9. IAM Access Analyzer

Helps identify resources shared with external entities:
- S3 buckets shared publicly or cross-account
- IAM roles with overly permissive trust policies
- KMS keys accessible from outside the account
- SQS queues with public access

**Policy generation**: Can generate least-privilege policies based on 90
days of CloudTrail activity data.

**Policy validation**: Validate policies against IAM best practices before
deployment.

---

## 10. Common Condition Keys

### Global Condition Keys (available for all services)
| Key | Description |
|---|---|
| `aws:SourceAccount` | Account making the request |
| `aws:SourceArn` | ARN of the requesting resource |
| `aws:SourceIp` | IP address of the requester |
| `aws:SourceVpc` | VPC of the requester |
| `aws:PrincipalOrgID` | Organization ID |
| `aws:PrincipalTag/${TagKey}` | Tag on the principal (ABAC) |
| `aws:ResourceTag/${TagKey}` | Tag on the resource |
| `aws:SecureTransport` | HTTPS vs HTTP |
| `aws:MultiFactorAuthPresent` | MFA was used |
| `aws:RequestedRegion` | Target AWS region |
| `aws:CalledVia` | Service making request on behalf |

### IAM-Specific Keys
| Key | Description |
|---|---|
| `iam:PassedToService` | Restricts which service a role can be passed to |
| `iam:PermissionsBoundary` | ARN of the permissions boundary |
| `iam:ResourceTag/${TagKey}` | Tag on the IAM resource |
| `sts:ExternalId` | External ID for cross-account assumption |
| `sts:RoleSessionName` | Session name when assuming role |

---

## 11. Naming Constraints

| Resource | Max Length | Valid Characters |
|---|---|---|
| Role name | 64 | `a-zA-Z0-9+=,.@_-` |
| Policy name | 128 | `a-zA-Z0-9+=,.@_-` |
| User name | 64 | `a-zA-Z0-9+=,.@_-` |
| Group name | 128 | `a-zA-Z0-9+=,.@_-` |
| Instance profile | 128 | `a-zA-Z0-9+=,.@_-` |
| Path | 512 | Must begin and end with `/` |

**Important**: Role names are case-sensitive but the pipeline engine uses
lowercase with hyphens consistently.

---

## 12. Service Quotas

| Quota | Default | Adjustable |
|---|---|---|
| Roles per account | 1,000 | Yes (to 5,000) |
| Users per account | 5,000 | Yes |
| Groups per account | 300 | Yes |
| Managed policies per role | 10 | Yes (to 20) |
| Inline policies per role | 250 | No (but 10,240 byte combined limit) |
| Managed policy size | 6,144 bytes | No |
| Inline policy size | 2,048 bytes | No |
| Trust policy size | 2,048 bytes | No |
| Policy versions | 5 | No |
| Groups per user | 10 | No |
| Access keys per user | 2 | No |
| Tags per role | 50 | No |

---

## 13. Terraform Resources

### Created by `_render_iam()` (Standalone IAM Service Type)
- `aws_iam_role` -- role with trust policy and tags

### Created by `_iam_role()` and `_iam_policy()` Helpers
For every principal service:
- `aws_iam_role` (label: `{resource_label}_role`)
- `aws_iam_role_policy` (label: `{resource_label}_policy`)

### Additional IAM Resources in Pipelines
- `aws_iam_role_policy_attachment` -- for attaching managed policies
  (e.g., `AmazonSageMakerFullAccess`)
- `aws_iam_instance_profile` -- for EC2 instances
- `aws_lambda_permission` -- resource-based policy for Lambda
- `aws_sqs_queue_policy` -- resource-based policy for SQS

---

## 14. Common Errors and Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `NoSuchEntityException` | Role/user/policy doesn't exist | Verify name, check terraform apply |
| `AccessDenied` | Missing permissions | Add required actions to inline/managed policy |
| `MalformedPolicyDocument` | Bad policy JSON | Fix syntax (Version, Effect, Action, Resource) |
| `EntityAlreadyExists` | Resource already exists | Use update operations instead |
| `DeleteConflict` | Dependencies exist | Detach policies, remove from profiles first |
| `LimitExceeded` (roles) | >1000 roles | Delete unused or request quota increase |
| `PassRole not authorized` | Missing `iam:PassRole` | Add PassRole with role ARN as Resource |
| `PolicyLengthExceeded` | Policy too large | Split policies, use wildcards |
| `InvalidInput` (trust) | Bad trust policy | Fix principal format, verify account/service |

### Debugging Permission Issues

1. **Check CloudTrail**: Look for `AccessDenied` events -- they show the
   exact action and resource that was denied
2. **Use `sts:GetCallerIdentity`**: Verify which role/user is making the
   request
3. **Check policy evaluation**: Remember explicit Deny always wins. Check
   SCPs, permission boundaries, resource policies, and identity policies
4. **Use IAM Policy Simulator**: Test policies without making actual API calls
5. **Use Access Analyzer**: Check for unused permissions and generate
   least-privilege policies

---

## 15. Security Best Practices

1. **Use roles, not users** -- for applications and services
2. **Least privilege** -- grant only the permissions needed
3. **Use conditions** -- restrict by source, region, or tags
4. **Enable MFA** -- for all human access
5. **Rotate credentials** -- access keys should be rotated regularly
6. **Use permission boundaries** -- for delegated admin scenarios
7. **Monitor with CloudTrail** -- audit all IAM API calls
8. **Use Access Analyzer** -- identify overly permissive policies
9. **Tag everything** -- for ABAC and cost allocation
10. **Use SCPs** -- organization-level guardrails
11. **Prefer managed policies** -- easier to audit and maintain
12. **Use iam:PassedToService condition** -- when granting PassRole

---

## 16. Monitoring

IAM has no CloudWatch Log Group or native metrics. IAM activities are
audited exclusively via **CloudTrail**:

- All IAM API calls are logged as management events
- `AssumeRole` calls are logged in both the calling and target accounts
- `AccessDenied` events are logged with the denied action and resource

In our pipeline engine, IAM is in the "no monitoring" category -- the log
aggregator does not poll for IAM events.

---

## 17. ARN Formats

| Resource | Format |
|---|---|
| Role | `arn:aws:iam::ACCOUNT:role/[PATH/]ROLE_NAME` |
| User | `arn:aws:iam::ACCOUNT:user/[PATH/]USER_NAME` |
| Group | `arn:aws:iam::ACCOUNT:group/[PATH/]GROUP_NAME` |
| Policy | `arn:aws:iam::ACCOUNT:policy/[PATH/]POLICY_NAME` |
| Instance profile | `arn:aws:iam::ACCOUNT:instance-profile/[PATH/]NAME` |
| OIDC provider | `arn:aws:iam::ACCOUNT:oidc-provider/PROVIDER_URL` |
| SAML provider | `arn:aws:iam::ACCOUNT:saml-provider/NAME` |
| Root | `arn:aws:iam::ACCOUNT:root` |

Note: IAM ARNs do not include a region (IAM is a global service).
