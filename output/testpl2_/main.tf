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


# --- s3_1 ---
resource "aws_s3_bucket" "testpl2__engineering_cc001_s3_s3_1_1" {
  bucket        = "testpl2-engineering-cc001-s3-s3-1-1"
  force_destroy = true

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "testpl2__engineering_cc001_s3_s3_1_1_versioning" {
  bucket = aws_s3_bucket.testpl2__engineering_cc001_s3_s3_1_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "testpl2__engineering_cc001_s3_s3_1_1_sse" {
  bucket = aws_s3_bucket.testpl2__engineering_cc001_s3_s3_1_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "testpl2__engineering_cc001_s3_s3_1_1_invoke_testpl2__engineering_cc001_lambda_lambda_1" {
  statement_id  = "AllowS3-testpl2__engineering_cc001_s3_s3_1_1-testpl2__engineering_cc001_lambda_lambda_1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.testpl2__engineering_cc001_lambda_lambda_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.testpl2__engineering_cc001_s3_s3_1_1.arn
}

resource "aws_s3_bucket_notification" "testpl2__engineering_cc001_s3_s3_1_1_notification" {
  bucket = aws_s3_bucket.testpl2__engineering_cc001_s3_s3_1_1.id

  lambda_function {
    id                  = "testpl2__engineering_cc001_s3_s3_1_1_testpl2__engineering_cc001_lambda_lambda_1"
    lambda_function_arn = aws_lambda_function.testpl2__engineering_cc001_lambda_lambda_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.testpl2__engineering_cc001_s3_s3_1_1_invoke_testpl2__engineering_cc001_lambda_lambda_1]
}

# --- lambda_1 ---
data "archive_file" "testpl2__engineering_cc001_lambda_lambda_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/testpl2__engineering_cc001_lambda_lambda_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "testpl2__engineering_cc001_lambda_lambda_1_role" {
  name = "testpl2--engineering-cc001-lambda-lambda-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "testpl2__engineering_cc001_lambda_lambda_1_policy" {
  name = "testpl2--engineering-cc001-lambda-lambda-1-policy"
  role = aws_iam_role.testpl2__engineering_cc001_lambda_lambda_1_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:ListBucket"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "testpl2__engineering_cc001_lambda_lambda_1_lg" {
  name              = "/aws/lambda/testpl2--engineering-cc001-lambda-lambda-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "testpl2__engineering_cc001_lambda_lambda_1" {
  function_name    = "testpl2--engineering-cc001-lambda-lambda-1"
  role             = aws_iam_role.testpl2__engineering_cc001_lambda_lambda_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.testpl2__engineering_cc001_lambda_lambda_1_placeholder.output_path
  source_code_hash = data.archive_file.testpl2__engineering_cc001_lambda_lambda_1_placeholder.output_base64sha256

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.testpl2__engineering_cc001_lambda_lambda_1_lg]
}

# --- emr_serverless_1 ---
# ⚠️  WARNING: emr_serverless is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_iam_role" "testpl2__engineering_cc001_emr_serverless_emr_serverless_1_role" {
  name = "testpl2--engineering-cc001-emr-serverless-emr-serverless-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "emr-serverless.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "testpl2__engineering_cc001_emr_serverless_emr_serverless_1_policy" {
  name = "testpl2--engineering-cc001-emr-serverless-emr-ser-6d85631-policy"
  role = aws_iam_role.testpl2__engineering_cc001_emr_serverless_emr_serverless_1_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "emr-serverless:StartApplication",
          "emr-serverless:StopApplication",
          "emr-serverless:StartJobRun",
          "emr-serverless:GetJobRun",
          "emr-serverless:ListJobRuns",
          "emr-serverless:CancelJobRun",
          "emr-serverless:GetApplication",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketLocation"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "testpl2__engineering_cc001_emr_serverless_emr_serverless_1_lg" {
  name              = "/aws/emr-serverless/testpl2--engineering-cc001-emr-serverless-emr-serverless-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# ⚠️ PREREQUISITE: Enable EMR Serverless in your AWS account first.
# Go to: AWS Console → EMR → EMR Serverless → Get started (one-time per account/region).
# Without this step, terraform apply will fail with SubscriptionRequiredException.
resource "aws_emrserverless_application" "testpl2__engineering_cc001_emr_serverless_emr_serverless_1" {
  name          = "testpl2--engineering-cc001-emr-serverless-emr-serverless-1"
  release_label = "emr-6.15.0"
  type          = "SPARK"

  initial_capacity {
    initial_capacity_type = "Driver"

    initial_capacity_config {
      worker_count = 1
      worker_configuration {
        cpu    = "1vCPU"
        memory = "2gb"
      }
    }
  }

  initial_capacity {
    initial_capacity_type = "Executor"

    initial_capacity_config {
      worker_count = 1
      worker_configuration {
        cpu    = "1vCPU"
        memory = "2gb"
      }
    }
  }

  maximum_capacity {
    cpu    = "4vCPU"
    memory = "8gb"
    disk   = "40gb"
  }

  auto_start_configuration {
    enabled = true
  }

  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 15
  }

  architecture = "X86_64"

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- s3_2 ---
resource "aws_s3_bucket" "testpl2__engineering_cc001_s3_s3_2_2" {
  bucket        = "testpl2-engineering-cc001-s3-s3-2-2"
  force_destroy = true

  tags = {
    Pipeline      = "testpl2_"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "testpl2__engineering_cc001_s3_s3_2_2_versioning" {
  bucket = aws_s3_bucket.testpl2__engineering_cc001_s3_s3_2_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "testpl2__engineering_cc001_s3_s3_2_2_sse" {
  bucket = aws_s3_bucket.testpl2__engineering_cc001_s3_s3_2_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
