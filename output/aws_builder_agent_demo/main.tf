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
resource "aws_s3_bucket" "aws_builder_agent_demo_engineering_cc001_s3_s3_1_1" {
  bucket        = "aws-builder-agent-demo-engineering-cc001-s3-s3-1-1"
  force_destroy = true

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "aws_builder_agent_demo_engineering_cc001_s3_s3_1_1_versioning" {
  bucket = aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_1_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_builder_agent_demo_engineering_cc001_s3_s3_1_1_sse" {
  bucket = aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_1_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "aws_builder_agent_demo_engineering_cc001_s3_s3_1_1_invoke_aws_builder_agent_demo_engineering_cc001_lambda_lambda_1" {
  statement_id  = "AllowS3-aws_builder_agent_demo_engineering_cc001_s3_s3_1_1-aws_builder_agent_demo_engineeri-3e827bcd"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aws_builder_agent_demo_engineering_cc001_lambda_lambda_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_1_1.arn
}

resource "aws_s3_bucket_notification" "aws_builder_agent_demo_engineering_cc001_s3_s3_1_1_notification" {
  bucket = aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_1_1.id

  lambda_function {
    id                  = "aws_builder_agent_demo_engineering_cc001_s3_s3_1_1_aws_builder_agent_demo_engineering_cc001_lambda_lambda_1"
    lambda_function_arn = aws_lambda_function.aws_builder_agent_demo_engineering_cc001_lambda_lambda_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.aws_builder_agent_demo_engineering_cc001_s3_s3_1_1_invoke_aws_builder_agent_demo_engineering_cc001_lambda_lambda_1]
}

# --- lambda_1 ---
data "archive_file" "aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_role" {
  name = "aws-builder-agent-demo-engineering-cc001-lambda-lambda-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_policy" {
  name = "aws-builder-agent-demo-engineering-cc001-lambda-lambda-1-policy"
  role = aws_iam_role.aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_lg" {
  name              = "/aws/lambda/aws-builder-agent-demo-engineering-cc001-lambda-lambda-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "aws_builder_agent_demo_engineering_cc001_lambda_lambda_1" {
  function_name    = "aws-builder-agent-demo-engineering-cc001-lambda-lambda-1"
  role             = aws_iam_role.aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_placeholder.output_path
  source_code_hash = data.archive_file.aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_placeholder.output_base64sha256

  environment {
    variables = {
      S3_2_BUCKET = aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_2_2.id
    }
  }

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.aws_builder_agent_demo_engineering_cc001_lambda_lambda_1_lg]
}

# --- s3_2 ---
resource "aws_s3_bucket" "aws_builder_agent_demo_engineering_cc001_s3_s3_2_2" {
  bucket        = "aws-builder-agent-demo-engineering-cc001-s3-s3-2-2"
  force_destroy = true

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "aws_builder_agent_demo_engineering_cc001_s3_s3_2_2_versioning" {
  bucket = aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_2_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_builder_agent_demo_engineering_cc001_s3_s3_2_2_sse" {
  bucket = aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_2_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- glue_1 ---
resource "aws_cloudwatch_log_group" "aws_builder_agent_demo_engineering_cc001_glue_glue_1_lg" {
  name              = "/aws-glue/jobs/aws-builder-agent-demo-engineering-cc001-glue-glue-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "aws_builder_agent_demo_engineering_cc001_glue_glue_1_db" {
  name = "aws_builder_agent_demo_engineering_cc001_glue_glue_1_db"

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "aws_builder_agent_demo_engineering_cc001_glue_glue_1_role" {
  name = "aws-builder-agent-demo-engineering-cc001-glue-glue-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "aws_builder_agent_demo_engineering_cc001_glue_glue_1_policy" {
  name = "aws-builder-agent-demo-engineering-cc001-glue-glue-1-policy"
  role = aws_iam_role.aws_builder_agent_demo_engineering_cc001_glue_glue_1_role.id

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
          "glue:BatchDeletePartition",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_glue_crawler" "aws_builder_agent_demo_engineering_cc001_glue_glue_1" {
  name          = "aws-builder-agent-demo-engineering-cc001-glue-glue-1"
  database_name = aws_glue_catalog_database.aws_builder_agent_demo_engineering_cc001_glue_glue_1_db.name
  role          = aws_iam_role.aws_builder_agent_demo_engineering_cc001_glue_glue_1_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.aws_builder_agent_demo_engineering_cc001_s3_s3_2_2.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- athena_1 ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "aws_builder_agent_demo_engineering_cc001_athena_athena_1_lg" {
  name              = "/aws/athena/aws-builder-agent-demo-engineering-cc001-athena-athena-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "aws_builder_agent_demo_engineering_cc001_athena_athena_1" {
  name = "aws-builder-agent-demo-engineering-cc001-athena-athena-1"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://aws-builder-agent-demo-engineering-cc001-s3-s3-2-2/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "aws_builder_agent_demo"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
