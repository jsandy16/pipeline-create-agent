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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


# --- source_data_bucket ---
resource "aws_s3_bucket" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af" {
  bucket        = "s3-prefix-processing-pipeline-cc071-rd-s3-source-data-b-e567a17"
  force_destroy = true

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_versioning" {
  bucket = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_sse" {
  bucket = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudwatch_event_rule" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all" {
  name          = "s3-prefix-processing-pipeline-cc071-rd-s3-so-bd4bf13-eb-objectcr"
  description   = "S3 EventBridge fan-out: s3-prefix-processing-pipeline-cc071-rd-s3-source-data-b-e567a17 / s3:ObjectCreated:*"
  event_pattern = "{\"source\": [\"aws.s3\"], \"detail\": {\"bucket\": {\"name\": [\"s3-prefix-processing-pipeline-cc071-rd-s3-source-data-b-e567a17\"]}}, \"detail-type\": [\"Object Created\"]}"

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_cloudwatch_event_target" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all_to_s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe" {
  rule      = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.name
  target_id = "objectcreated_al-s3_prefix_processing_pipeline_cc071_rd-d0996a4c"
  arn       = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe.arn
}

resource "aws_lambda_permission" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_allow_eb_s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af" {
  statement_id  = "AllowS3EB-s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af-s3_prefix_proce-2227944b"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all_to_s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3" {
  rule      = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.name
  target_id = "objectcreated_al-s3_prefix_processing_pipeline_cc071_rd-f0cdb1ba"
  arn       = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3.arn
}

resource "aws_lambda_permission" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_allow_eb_s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af" {
  statement_id  = "AllowS3EB-s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af-s3_prefix_proce-1934c33d"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all_to_s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78" {
  rule      = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.name
  target_id = "objectcreated_al-s3_prefix_processing_pipeline_cc071_rd-1bef98a6"
  arn       = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78.arn
}

resource "aws_lambda_permission" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_allow_eb_s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af" {
  statement_id  = "AllowS3EB-s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af-s3_prefix_proce-9de0ced4"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all_to_s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c" {
  rule      = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.name
  target_id = "objectcreated_al-s3_prefix_processing_pipeline_cc071_rd-06d3a45b"
  arn       = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c.arn
}

resource "aws_lambda_permission" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_allow_eb_s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af" {
  statement_id  = "AllowS3EB-s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af-s3_prefix_proce-95f55efd"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_eb_objectcreated_all.arn
}

resource "aws_s3_bucket_notification" "s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af_notification" {
  bucket      = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af.id
  eventbridge = true

}

# --- process_prefix1 ---
data "archive_file" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_role" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-proce-2f04073-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_policy" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-pro-2f04073-policy"
  role = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_lg" {
  name              = "/aws/lambda/s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-6ee428a"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe" {
  function_name    = "s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-6ee428a"
  role             = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix1_1afe_lg]
}

# --- process_prefix2 ---
data "archive_file" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_role" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-proce-533618f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_policy" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-pro-533618f-policy"
  role = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_lg" {
  name              = "/aws/lambda/s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-35465f5"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3" {
  function_name    = "s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-35465f5"
  role             = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix2_18c3_lg]
}

# --- process_prefix3 ---
data "archive_file" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_role" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-proce-f001e9a-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_policy" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-pro-f001e9a-policy"
  role = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_lg" {
  name              = "/aws/lambda/s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-4221716"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78" {
  function_name    = "s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-4221716"
  role             = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix3_2b78_lg]
}

# --- process_prefix4 ---
data "archive_file" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_role" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-proce-57b80b8-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_policy" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-pro-57b80b8-policy"
  role = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_lg" {
  name              = "/aws/lambda/s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-8d79f49"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c" {
  function_name    = "s3-prefix-processing-pipeline-cc071-rd-lambda-process-pr-8d79f49"
  role             = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processing_pipeline_cc071_rd_lambda_process_prefix4_5b0c_lg]
}

# --- staging_data_bucket ---
resource "aws_s3_bucket" "s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26" {
  bucket        = "s3-prefix-processing-pipeline-cc071-rd-s3-staging-data-644ef94"
  force_destroy = true

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26_versioning" {
  bucket = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26_sse" {
  bucket = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_staging_data_bucket_8f26.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- s3_1 ---
resource "aws_s3_bucket" "s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662" {
  bucket        = "s3-prefix-processing-pipeline-cc071-rd-s3-s3-1-e8c7"
  force_destroy = true

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_versioning" {
  bucket = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_sse" {
  bucket = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_invoke_s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b" {
  statement_id  = "AllowS3-s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662-s3_prefix_processing_pipeline_c-3248181c"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662.arn
}

resource "time_sleep" "s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_iam_sleep" {
  depends_on      = [aws_lambda_permission.s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_invoke_s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_notification" {
  bucket = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662.id

  lambda_function {
    id                  = "s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b"
    lambda_function_arn = aws_lambda_function.s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_invoke_s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b, time_sleep.s3_prefix_processing_pipeline_cc071_rd_s3_s3_1_4662_iam_sleep]
}

# --- lambda_1 ---
data "archive_file" "s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_role" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-lambda-1-294c-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_policy" {
  name = "s3-prefix-processing-pipeline-cc071-rd-lambda-lam-413254e-policy"
  role = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_lg" {
  name              = "/aws/lambda/s3-prefix-processing-pipeline-cc071-rd-lambda-lambda-1-294c"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b" {
  function_name    = "s3-prefix-processing-pipeline-cc071-rd-lambda-lambda-1-294c"
  role             = aws_iam_role.s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_placeholder.output_base64sha256

  environment {
    variables = {
      SOURCE_DATA_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_processing_pipeline_cc071_rd_s3_source_data_bucket_35af.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_processing_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "cc071"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processing_pipeline_cc071_rd_lambda_lambda_1_345b_lg]
}
