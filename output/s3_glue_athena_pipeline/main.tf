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


# --- src ---
resource "aws_s3_bucket" "s3_glue_athena_pipeline_engineering_cc001_s3_src" {
  bucket        = "s3-glue-athena-pipeline-engineering-cc001-s3-src"
  force_destroy = true

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_glue_athena_pipeline_engineering_cc001_s3_src_versioning" {
  bucket = aws_s3_bucket.s3_glue_athena_pipeline_engineering_cc001_s3_src.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_glue_athena_pipeline_engineering_cc001_s3_src_sse" {
  bucket = aws_s3_bucket.s3_glue_athena_pipeline_engineering_cc001_s3_src.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "s3_glue_athena_pipeline_engineering_cc001_s3_src_invoke_s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam" {
  statement_id  = "AllowS3-s3_glue_athena_pipeline_engineering_cc001_s3_src-s3_glue_athena_pipeline_engineerin-b982bd44"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_glue_athena_pipeline_engineering_cc001_s3_src.arn
}

resource "aws_s3_bucket_notification" "s3_glue_athena_pipeline_engineering_cc001_s3_src_notification" {
  bucket = aws_s3_bucket.s3_glue_athena_pipeline_engineering_cc001_s3_src.id

  lambda_function {
    id                  = "s3_glue_athena_pipeline_engineering_cc001_s3_src_s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam"
    filter_prefix       = "case/"
    lambda_function_arn = aws_lambda_function.s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3_glue_athena_pipeline_engineering_cc001_s3_src_invoke_s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam]
}

# --- src_lam ---
data "archive_file" "s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_role" {
  name = "s3-glue-athena-pipeline-engineering-cc001-lambda-src-lam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_policy" {
  name = "s3-glue-athena-pipeline-engineering-cc001-lambda-src-lam-policy"
  role = aws_iam_role.s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_role.id

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

resource "aws_cloudwatch_log_group" "s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_lg" {
  name              = "/aws/lambda/s3-glue-athena-pipeline-engineering-cc001-lambda-src-lam"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam" {
  function_name    = "s3-glue-athena-pipeline-engineering-cc001-lambda-src-lam"
  role             = aws_iam_role.s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_placeholder.output_path
  source_code_hash = data.archive_file.s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_placeholder.output_base64sha256

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_glue_athena_pipeline_engineering_cc001_lambda_src_lam_lg]
}

# --- src_glue_catalog ---
resource "aws_glue_catalog_database" "s3_glue_athena_pipeline_engineering_cc001_glue_data_catalog_src_glue_catalog" {
  name        = "s3_glue_athena_pipeline_engineering_cc001_glue_data_cat_84e4d1b"
  description = "Glue Data Catalog database"
}

# --- case_table_crawler ---
resource "aws_cloudwatch_log_group" "s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_lg" {
  name              = "/aws-glue/jobs/s3-glue-athena-pipeline-engineering-cc001-glue-case-table-crawler"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_db" {
  name = "s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_db"

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_role" {
  name = "s3-glue-athena-pipeline-engineering-cc001-glue-case-5a99f9b-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_policy" {
  name = "s3-glue-athena-pipeline-engineering-cc001-glue-ca-5a99f9b-policy"
  role = aws_iam_role.s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_role.id

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

resource "aws_glue_crawler" "s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler" {
  name          = "s3-glue-athena-pipeline-engineering-cc001-glue-case-table-crawler"
  database_name = aws_glue_catalog_database.s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_db.name
  role          = aws_iam_role.s3_glue_athena_pipeline_engineering_cc001_glue_case_table_crawler_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.s3_glue_athena_pipeline_engineering_cc001_s3_src.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- src_athena ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "s3_glue_athena_pipeline_engineering_cc001_athena_src_athena_lg" {
  name              = "/aws/athena/s3-glue-athena-pipeline-engineering-cc001-athena-src-athena"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "s3_glue_athena_pipeline_engineering_cc001_athena_src_athena" {
  name = "s3-glue-athena-pipeline-engineering-cc001-athena-src-athena"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://s3-glue-athena-pipeline-engineering-cc001-athena-src-athena-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "s3_glue_athena_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
