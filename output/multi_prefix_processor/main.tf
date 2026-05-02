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


# --- raw_data ---
resource "aws_s3_bucket" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343" {
  bucket        = "multi-prefix-processor-cc01-engineering-s3-raw-data-53b2"
  force_destroy = true

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_versioning" {
  bucket = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_raw_data_7343.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_sse" {
  bucket = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_raw_data_7343.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudwatch_event_rule" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all" {
  name          = "multi-prefix-processor-cc01-engineering-s3-r-f35aa73-eb-objectcr"
  description   = "S3 EventBridge fan-out: multi-prefix-processor-cc01-engineering-s3-raw-data-53b2 / s3:ObjectCreated:*"
  event_pattern = "{\"source\": [\"aws.s3\"], \"detail\": {\"bucket\": {\"name\": [\"multi-prefix-processor-cc01-engineering-s3-raw-data-53b2\"]}}, \"detail-type\": [\"Object Created\"]}"

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_cloudwatch_event_target" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all_to_multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93" {
  rule      = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.name
  target_id = "objectcreated_al-multi_prefix_processor_cc01_engineerin-2e18d036"
  arn       = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93.arn
}

resource "aws_lambda_permission" "multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_allow_eb_multi_prefix_processor_cc01_engineering_s3_raw_data_7343" {
  statement_id  = "AllowS3EB-multi_prefix_processor_cc01_engineering_s3_raw_data_7343-multi_prefix_processor_c-9624a10e"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all_to_multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef" {
  rule      = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.name
  target_id = "objectcreated_al-multi_prefix_processor_cc01_engineerin-4da6afeb"
  arn       = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef.arn
}

resource "aws_lambda_permission" "multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_allow_eb_multi_prefix_processor_cc01_engineering_s3_raw_data_7343" {
  statement_id  = "AllowS3EB-multi_prefix_processor_cc01_engineering_s3_raw_data_7343-multi_prefix_processor_c-b5370c60"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all_to_multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8" {
  rule      = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.name
  target_id = "objectcreated_al-multi_prefix_processor_cc01_engineerin-7dfad31e"
  arn       = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8.arn
}

resource "aws_lambda_permission" "multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_allow_eb_multi_prefix_processor_cc01_engineering_s3_raw_data_7343" {
  statement_id  = "AllowS3EB-multi_prefix_processor_cc01_engineering_s3_raw_data_7343-multi_prefix_processor_c-84faa7e2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all_to_multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0" {
  rule      = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.name
  target_id = "objectcreated_al-multi_prefix_processor_cc01_engineerin-caccd8c2"
  arn       = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0.arn
}

resource "aws_lambda_permission" "multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_allow_eb_multi_prefix_processor_cc01_engineering_s3_raw_data_7343" {
  statement_id  = "AllowS3EB-multi_prefix_processor_cc01_engineering_s3_raw_data_7343-multi_prefix_processor_c-7932d229"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.multi_prefix_processor_cc01_engineering_s3_raw_data_7343_eb_objectcreated_all.arn
}

resource "aws_s3_bucket_notification" "multi_prefix_processor_cc01_engineering_s3_raw_data_7343_notification" {
  bucket      = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_raw_data_7343.id
  eventbridge = true

}

# --- staging_data ---
resource "aws_s3_bucket" "multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf" {
  bucket        = "multi-prefix-processor-cc01-engineering-s3-staging-data-20a0"
  force_destroy = true

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf_versioning" {
  bucket = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf_sse" {
  bucket = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- processor_1 ---
data "archive_file" "multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_role" {
  name = "multi-prefix-processor-cc01-engineering-lambda-proc-5d7cf24-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_policy" {
  name = "multi-prefix-processor-cc01-engineering-lambda-pr-5d7cf24-policy"
  role = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_lg" {
  name              = "/aws/lambda/multi-prefix-processor-cc01-engineering-lambda-processor-1-dc60"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93" {
  function_name    = "multi-prefix-processor-cc01-engineering-lambda-processor-1-dc60"
  role             = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_processor_cc01_engineering_lambda_processor_1_6f93_lg]
}

# --- processor_2 ---
data "archive_file" "multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_role" {
  name = "multi-prefix-processor-cc01-engineering-lambda-proc-37dea05-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_policy" {
  name = "multi-prefix-processor-cc01-engineering-lambda-pr-37dea05-policy"
  role = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_lg" {
  name              = "/aws/lambda/multi-prefix-processor-cc01-engineering-lambda-processor-2-6022"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef" {
  function_name    = "multi-prefix-processor-cc01-engineering-lambda-processor-2-6022"
  role             = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_processor_cc01_engineering_lambda_processor_2_88ef_lg]
}

# --- processor_3 ---
data "archive_file" "multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_role" {
  name = "multi-prefix-processor-cc01-engineering-lambda-proc-1c71e03-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_policy" {
  name = "multi-prefix-processor-cc01-engineering-lambda-pr-1c71e03-policy"
  role = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_lg" {
  name              = "/aws/lambda/multi-prefix-processor-cc01-engineering-lambda-processor-3-419d"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8" {
  function_name    = "multi-prefix-processor-cc01-engineering-lambda-processor-3-419d"
  role             = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_processor_cc01_engineering_lambda_processor_3_06e8_lg]
}

# --- processor_4 ---
data "archive_file" "multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_role" {
  name = "multi-prefix-processor-cc01-engineering-lambda-proc-aa17b3d-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_policy" {
  name = "multi-prefix-processor-cc01-engineering-lambda-pr-aa17b3d-policy"
  role = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_lg" {
  name              = "/aws/lambda/multi-prefix-processor-cc01-engineering-lambda-processor-4-c31e"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0" {
  function_name    = "multi-prefix-processor-cc01-engineering-lambda-processor-4-c31e"
  role             = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_staging_data_b4bf.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_processor_cc01_engineering_lambda_processor_4_35b0_lg]
}

# --- s3_1 ---
resource "aws_s3_bucket" "multi_prefix_processor_cc01_engineering_s3_s3_1_1455" {
  bucket        = "multi-prefix-processor-cc01-engineering-s3-s3-1-59fc"
  force_destroy = true

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "multi_prefix_processor_cc01_engineering_s3_s3_1_1455_versioning" {
  bucket = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_s3_1_1455.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "multi_prefix_processor_cc01_engineering_s3_s3_1_1455_sse" {
  bucket = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_s3_1_1455.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "multi_prefix_processor_cc01_engineering_s3_s3_1_1455_invoke_multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c" {
  statement_id  = "AllowS3-multi_prefix_processor_cc01_engineering_s3_s3_1_1455-multi_prefix_processor_cc01_en-ca205d5d"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_s3_1_1455.arn
}

resource "time_sleep" "multi_prefix_processor_cc01_engineering_s3_s3_1_1455_iam_sleep" {
  depends_on      = [aws_lambda_permission.multi_prefix_processor_cc01_engineering_s3_s3_1_1455_invoke_multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "multi_prefix_processor_cc01_engineering_s3_s3_1_1455_notification" {
  bucket = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_s3_1_1455.id

  lambda_function {
    id                  = "multi_prefix_processor_cc01_engineering_s3_s3_1_1455_multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c"
    lambda_function_arn = aws_lambda_function.multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.multi_prefix_processor_cc01_engineering_s3_s3_1_1455_invoke_multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c, time_sleep.multi_prefix_processor_cc01_engineering_s3_s3_1_1455_iam_sleep]
}

# --- lambda_5 ---
data "archive_file" "multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_role" {
  name = "multi-prefix-processor-cc01-engineering-lambda-lamb-9c9e3ba-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_policy" {
  name = "multi-prefix-processor-cc01-engineering-lambda-la-9c9e3ba-policy"
  role = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_lg" {
  name              = "/aws/lambda/multi-prefix-processor-cc01-engineering-lambda-lambda-5-77a3"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c" {
  function_name    = "multi-prefix-processor-cc01-engineering-lambda-lambda-5-77a3"
  role             = aws_iam_role.multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_placeholder.output_base64sha256

  environment {
    variables = {
      RAW_DATA_BUCKET = aws_s3_bucket.multi_prefix_processor_cc01_engineering_s3_raw_data_7343.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_processor_cc01_engineering_lambda_lambda_5_b65c_lg]
}
