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
resource "aws_s3_bucket" "s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket" {
  bucket        = "s3-sqs-lambda-event-processor-engineering-cc001-s3-sour-518e69b"
  force_destroy = true

  tags = {
    Pipeline      = "s3_sqs_lambda_event_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket_versioning" {
  bucket = aws_s3_bucket.s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket_sse" {
  bucket = aws_s3_bucket.s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_notification" "s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket_notification" {
  bucket = aws_s3_bucket.s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket.id

  queue {
    queue_arn = aws_sqs_queue.s3_sqs_lambda_event_processor_engineering_cc001_sqs_message_queue.arn
    events   = ["s3:ObjectCreated:*"]
  }
}

# --- message_queue ---
resource "aws_sqs_queue" "s3_sqs_lambda_event_processor_engineering_cc001_sqs_message_queue" {
  name                       = "s3-sqs-lambda-event-processor-engineering-cc001-sqs-message-queue"
  visibility_timeout_seconds = 5
  message_retention_seconds  = 3600

  tags = {
    Pipeline      = "s3_sqs_lambda_event_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sqs_queue_policy" "s3_sqs_lambda_event_processor_engineering_cc001_sqs_message_queue_policy" {
  queue_url = aws_sqs_queue.s3_sqs_lambda_event_processor_engineering_cc001_sqs_message_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.s3_sqs_lambda_event_processor_engineering_cc001_sqs_message_queue.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_s3_bucket.s3_sqs_lambda_event_processor_engineering_cc001_s3_source_bucket.arn
        }
      }
    }
    ]
  })
}

# --- message_processor ---
data "archive_file" "s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_role" {
  name = "s3-sqs-lambda-event-processor-engineering-cc001-lam-1a892c8-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_sqs_lambda_event_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_policy" {
  name = "s3-sqs-lambda-event-processor-engineering-cc001-l-1a892c8-policy"
  role = aws_iam_role.s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_role.id

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
          "sqs:GetQueueAttributes"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_lg" {
  name              = "/aws/lambda/s3-sqs-lambda-event-processor-engineering-cc001-lambda-m-053f804"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_sqs_lambda_event_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor" {
  function_name    = "s3-sqs-lambda-event-processor-engineering-cc001-lambda-m-053f804"
  role             = aws_iam_role.s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 1024
  timeout          = 300
  filename         = data.archive_file.s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_placeholder.output_path
  source_code_hash = data.archive_file.s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_placeholder.output_base64sha256

  tags = {
    Pipeline      = "s3_sqs_lambda_event_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_lg]
}

resource "aws_lambda_event_source_mapping" "s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor_esm_s3_sqs_lambda_event_processor_engineering_cc001_sqs_message_queue" {
  event_source_arn = aws_sqs_queue.s3_sqs_lambda_event_processor_engineering_cc001_sqs_message_queue.arn
  function_name    = aws_lambda_function.s3_sqs_lambda_event_processor_engineering_cc001_lambda_message_processor.arn
  batch_size       = 10
}
