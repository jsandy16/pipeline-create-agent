terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


# --- source_bucket ---
resource "aws_s3_bucket" "s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1" {
  bucket        = "s3-sqs-lambda-processor-engineering-cc001-s3-source-bucket-1"
  force_destroy = true

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1_versioning" {
  bucket = aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1_sse" {
  bucket = aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_notification" "s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1_notification" {
  bucket = aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1.id

  queue {
    queue_arn = aws_sqs_queue.s3_sqs_lambda_processor_engineering_cc001_sqs_message_queue.arn
    events   = ["s3:ObjectCreated:*"]
  }
}

# --- message_queue ---
resource "aws_sqs_queue" "s3_sqs_lambda_processor_engineering_cc001_sqs_message_queue" {
  name                       = "s3-sqs-lambda-processor-engineering-cc001-sqs-message-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sqs_queue_policy" "s3_sqs_lambda_processor_engineering_cc001_sqs_message_queue_policy" {
  queue_url = aws_sqs_queue.s3_sqs_lambda_processor_engineering_cc001_sqs_message_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.s3_sqs_lambda_processor_engineering_cc001_sqs_message_queue.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1.arn
        }
      }
    }
    ]
  })
}

# --- message_processor ---
data "archive_file" "s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_placeholder.zip"
  source {
    content  = "import json\nimport os\nimport boto3\n\ndef handler(event, context):\n    s3_client = boto3.client('s3')\n    target_bucket = os.environ.get('TGT_BUCKET_NAME')\n    \n    for record in event['Records']:\n        body = json.loads(record['body'])\n        message = json.loads(body['Message'])\n        bucket = message['Records'][0]['s3']['bucket']['name']\n        key = message['Records'][0]['s3']['object']['key']\n        print(f'Processing object: s3://{bucket}/{key}')\n        \n        # Write to target bucket\n        processed_data = json.dumps({'source_bucket': bucket, 'source_key': key, 'processed': True})\n        s3_client.put_object(\n            Bucket=target_bucket,\n            Key=f'processed/{key}',\n            Body=processed_data\n        )\n    \n    return {'statusCode': 200, 'body': 'Messages processed successfully'}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_role" {
  name = "s3-sqs-lambda-processor-engineering-cc001-lambda-me-af21d60-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_policy" {
  name = "s3-sqs-lambda-processor-engineering-cc001-lambda-af21d60-policy"
  role = aws_iam_role.s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_lg" {
  name              = "/aws/lambda/s3-sqs-lambda-processor-engineering-cc001-lambda-message-4794c9a"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor" {
  function_name    = "s3-sqs-lambda-processor-engineering-cc001-lambda-message-4794c9a"
  role             = aws_iam_role.s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_placeholder.output_path
  source_code_hash = data.archive_file.s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_placeholder.output_base64sha256

  environment {
    variables = {
      TGT_BUCKET = aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_tgt_2.id
    }
  }

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_lg]
}

resource "aws_lambda_event_source_mapping" "s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor_esm_s3_sqs_lambda_processor_engineering_cc001_sqs_message_queue" {
  event_source_arn = aws_sqs_queue.s3_sqs_lambda_processor_engineering_cc001_sqs_message_queue.arn
  function_name    = aws_lambda_function.s3_sqs_lambda_processor_engineering_cc001_lambda_message_processor.arn
  batch_size       = 10
}

# --- tgt ---
resource "aws_s3_bucket" "s3_sqs_lambda_processor_engineering_cc001_s3_tgt_2" {
  bucket        = "s3-sqs-lambda-processor-engineering-cc001-s3-tgt-2"
  force_destroy = true

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_sqs_lambda_processor_engineering_cc001_s3_tgt_2_versioning" {
  bucket = aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_tgt_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_sqs_lambda_processor_engineering_cc001_s3_tgt_2_sse" {
  bucket = aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_tgt_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- glue_job ---
resource "aws_cloudwatch_log_group" "s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_lg" {
  name              = "/aws-glue/jobs/s3-sqs-lambda-processor-engineering-cc001-glue-glue-job"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_db" {
  name = "s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_db"

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_role" {
  name = "s3-sqs-lambda-processor-engineering-cc001-glue-glue-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_policy" {
  name = "s3-sqs-lambda-processor-engineering-cc001-glue-glue-job-policy"
  role = aws_iam_role.s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_glue_crawler" "s3_sqs_lambda_processor_engineering_cc001_glue_glue_job" {
  name          = "s3-sqs-lambda-processor-engineering-cc001-glue-glue-job"
  database_name = aws_glue_catalog_database.s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_db.name
  role          = aws_iam_role.s3_sqs_lambda_processor_engineering_cc001_glue_glue_job_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.s3_sqs_lambda_processor_engineering_cc001_s3_source_bucket_1.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- ec2_instance ---
data "aws_ami" "s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_role" {
  name = "s3-sqs-lambda-processor-engineering-cc001-ec2-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_policy" {
  name = "s3-sqs-lambda-processor-engineering-cc001-ec2-ec2-47da00b-policy"
  role = aws_iam_role.s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_profile" {
  name = "s3-sqs-lambda-processor-engineering-cc001-ec2-ec-47da00b-profile"
  role = aws_iam_role.s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_role.name
}

resource "aws_security_group" "s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_sg" {
  name        = "s3-sqs-lambda-processor-engineering-cc001-ec2-ec2-instance-sg"
  description = "SG for s3-sqs-lambda-processor-engineering-cc001-ec2-ec2-instance"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_instance" "s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance" {
  ami                    = data.aws_ami.s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_ami.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_profile.name
  vpc_security_group_ids = [aws_security_group.s3_sqs_lambda_processor_engineering_cc001_ec2_ec2_instance_sg.id]

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- athena_workgroup ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "s3_sqs_lambda_processor_engineering_cc001_athena_athena_workgroup_lg" {
  name              = "/aws/athena/s3-sqs-lambda-processor-engineering-cc001-athena-athena-workgroup"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "s3_sqs_lambda_processor_engineering_cc001_athena_athena_workgroup" {
  name = "s3-sqs-lambda-processor-engineering-cc001-athena-athena-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://s3-sqs-lambda-processor-engineering-cc001-athena-athena-workgroup-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "s3_sqs_lambda_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
