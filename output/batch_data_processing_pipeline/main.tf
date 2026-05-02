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


# --- raw_collision_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-ra-2669727"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1-batch_d-904ade32"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1"
    filter_prefix       = "collision_raw/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_collision_bucket_1_iam_sleep]
}

# --- raw_party_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-ra-8c7049e"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2-batch_data_-6e987750"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2"
    filter_prefix       = "party_raw/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_party_bucket_2_iam_sleep]
}

# --- raw_victim_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-ra-5e5548e"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3-batch_data-9390b54f"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3"
    filter_prefix       = "victim_raw/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_victim_bucket_3_iam_sleep]
}

# --- raw_case_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-ra-708b832"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4-batch_data_p-a1c71bff"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4"
    filter_prefix       = "case_raw/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_raw_case_bucket_4_iam_sleep]
}

# --- process_collision_lambda ---
data "archive_file" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_role" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-l-62594fd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_policy" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-62594fd-policy"
  role = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_role.id

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

resource "aws_cloudwatch_log_group" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_lg" {
  name              = "/aws/lambda/batch-data-processing-pipeline-sjanalytics-test01-lambda-3b421bb"
  retention_in_days = 7

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1" {
  function_name    = "batch-data-processing-pipeline-sjanalytics-test01-lambda-3b421bb"
  role             = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_placeholder.output_path
  source_code_hash = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_placeholder.output_base64sha256

  environment {
    variables = {
      COLLISION_STAGING_BUCKET_BUCKET = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5.id
    }
  }

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_collision_lambda_1_lg]
}

# --- process_party_lambda ---
data "archive_file" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_role" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-l-28f03cc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_policy" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-28f03cc-policy"
  role = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_role.id

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

resource "aws_cloudwatch_log_group" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_lg" {
  name              = "/aws/lambda/batch-data-processing-pipeline-sjanalytics-test01-lambda-33d806b"
  retention_in_days = 7

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2" {
  function_name    = "batch-data-processing-pipeline-sjanalytics-test01-lambda-33d806b"
  role             = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_placeholder.output_path
  source_code_hash = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_placeholder.output_base64sha256

  environment {
    variables = {
      PARTY_STAGING_BUCKET_BUCKET = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6.id
    }
  }

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_party_lambda_2_lg]
}

# --- process_victim_lambda ---
data "archive_file" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_role" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-l-1ba128f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_policy" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-1ba128f-policy"
  role = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_role.id

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

resource "aws_cloudwatch_log_group" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_lg" {
  name              = "/aws/lambda/batch-data-processing-pipeline-sjanalytics-test01-lambda-f2a0012"
  retention_in_days = 7

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3" {
  function_name    = "batch-data-processing-pipeline-sjanalytics-test01-lambda-f2a0012"
  role             = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_placeholder.output_path
  source_code_hash = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_placeholder.output_base64sha256

  environment {
    variables = {
      VICTIM_STAGING_BUCKET_BUCKET = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7.id
    }
  }

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_victim_lambda_3_lg]
}

# --- process_case_lambda ---
data "archive_file" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_role" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-l-91d5a81-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_policy" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-91d5a81-policy"
  role = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_role.id

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

resource "aws_cloudwatch_log_group" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_lg" {
  name              = "/aws/lambda/batch-data-processing-pipeline-sjanalytics-test01-lambda-ae8de78"
  retention_in_days = 7

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4" {
  function_name    = "batch-data-processing-pipeline-sjanalytics-test01-lambda-ae8de78"
  role             = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_placeholder.output_path
  source_code_hash = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_placeholder.output_base64sha256

  environment {
    variables = {
      CASE_STAGING_BUCKET_BUCKET = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8.id
    }
  }

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.batch_data_processing_pipeline_sjanalytics_test01_lambda_process_case_lambda_4_lg]
}

# --- collision_staging_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-co-8e307fb"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5-bat-59edd248"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5"
    filter_prefix       = "collision_staging/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5_iam_sleep]
}

# --- party_staging_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-pa-f72bae7"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6-batch_d-b624a694"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5"
    filter_prefix       = "party_staging/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6_iam_sleep]
}

# --- victim_staging_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-vi-3202cff"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7-batch_-f89af747"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5"
    filter_prefix       = "victim_staging/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7_iam_sleep]
}

# --- case_staging_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-ca-04c2d94"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5" {
  statement_id  = "AllowS3-batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8-batch_da-c5502b82"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8.arn
}

resource "time_sleep" "batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_iam_sleep" {
  depends_on      = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_notification" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8.id

  lambda_function {
    id                  = "batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5"
    filter_prefix       = "case_staging/"
    lambda_function_arn = aws_lambda_function.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_invoke_batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5, time_sleep.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8_iam_sleep]
}

# --- refine_data_lambda ---
data "archive_file" "batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_placeholder" {
  type        = "zip"
  output_path = "${path.module}/batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_role" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-l-b347616-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_policy" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-b347616-policy"
  role = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_role.id

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

resource "aws_cloudwatch_log_group" "batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_lg" {
  name              = "/aws/lambda/batch-data-processing-pipeline-sjanalytics-test01-lambda-b449ae2"
  retention_in_days = 7

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5" {
  function_name    = "batch-data-processing-pipeline-sjanalytics-test01-lambda-b449ae2"
  role             = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 1024
  timeout          = 600
  filename         = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_placeholder.output_path
  source_code_hash = data.archive_file.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_placeholder.output_base64sha256

  environment {
    variables = {
      MINILAKE_BUCKET_BUCKET = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_minilake_bucket_9.id
    }
  }

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.batch_data_processing_pipeline_sjanalytics_test01_lambda_refine_data_lambda_5_lg]
}

# --- minilake_bucket ---
resource "aws_s3_bucket" "batch_data_processing_pipeline_sjanalytics_test01_s3_minilake_bucket_9" {
  bucket        = "batch-data-processing-pipeline-sjanalytics-test01-s3-mi-8e9cd3b"
  force_destroy = true

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "batch_data_processing_pipeline_sjanalytics_test01_s3_minilake_bucket_9_versioning" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_minilake_bucket_9.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "batch_data_processing_pipeline_sjanalytics_test01_s3_minilake_bucket_9_sse" {
  bucket = aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_minilake_bucket_9.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- minilake_crawler ---
resource "aws_cloudwatch_log_group" "batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_lg" {
  name              = "/aws-glue/jobs/batch-data-processing-pipeline-sjanalytics-test01-glue-minilake-crawler"
  retention_in_days = 7

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_db" {
  name = "batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_db"

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_role" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-g-90002e0-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_policy" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-90002e0-policy"
  role = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_role.id

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

resource "aws_glue_crawler" "batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler" {
  name          = "batch-data-processing-pipeline-sjanalytics-test01-glue-minilake-crawler"
  database_name = aws_glue_catalog_database.batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_db.name
  role          = aws_iam_role.batch_data_processing_pipeline_sjanalytics_test01_glue_minilake_crawler_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_collision_staging_bucket_5.id}/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_party_staging_bucket_6.id}/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_victim_staging_bucket_7.id}/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.batch_data_processing_pipeline_sjanalytics_test01_s3_case_staging_bucket_8.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- minilake_database ---
resource "aws_glue_catalog_database" "batch_data_processing_pipeline_sjanalytics_test01_glue_data_catalog_minilake_database" {
  name        = "batch_data_processing_pipeline_sjanalytics_test01_glue_4c53b71"
  description = "Glue Data Catalog database"
}

# --- query_minilake_athena ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "batch_data_processing_pipeline_sjanalytics_test01_athena_query_minilake_athena_lg" {
  name              = "/aws/athena/batch-data-processing-pipeline-sjanalytics-test01-athena-query-minilake-athena"
  retention_in_days = 7

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "batch_data_processing_pipeline_sjanalytics_test01_athena_query_minilake_athena" {
  name = "batch-data-processing-pipeline-sjanalytics-test01-athena-query-minilake-athena"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://batch-data-processing-pipeline-sjanalytics-test01-athena-query-minilake-athena-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "batch_data_processing_pipeline"
    BusinessUnit  = "SJANALYTICS"
    CostCenter    = "test01"
    ManagedBy     = "aws-pipeline-engine"
  }
}
