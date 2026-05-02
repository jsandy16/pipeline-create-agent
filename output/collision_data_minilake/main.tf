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


# --- collision_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_collision_bucket_bd75" {
  bucket        = "collision-data-minilake-c001-rd-s3-collision-bucket-cdb9"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_collision_bucket_bd75_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_bucket_bd75.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_collision_bucket_bd75_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_bucket_bd75.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_collision_bucket_bd75_invoke_collision_data_minilake_c001_rd_lambda_collision_processor_e79e" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_collision_bucket_bd75-collision_data_minilake_c0-4a41be39"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_collision_processor_e79e.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_bucket_bd75.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_collision_bucket_bd75_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_collision_bucket_bd75_invoke_collision_data_minilake_c001_rd_lambda_collision_processor_e79e]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_collision_bucket_bd75_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_bucket_bd75.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_collision_bucket_bd75_collision_data_minilake_c001_rd_lambda_collision_processor_e79e"
    filter_prefix       = "collision_raw/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_collision_processor_e79e.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_collision_bucket_bd75_invoke_collision_data_minilake_c001_rd_lambda_collision_processor_e79e, time_sleep.collision_data_minilake_c001_rd_s3_collision_bucket_bd75_iam_sleep]
}

# --- party_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_party_bucket_f971" {
  bucket        = "collision-data-minilake-c001-rd-s3-party-bucket-6366"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_party_bucket_f971_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_bucket_f971.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_party_bucket_f971_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_bucket_f971.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_party_bucket_f971_invoke_collision_data_minilake_c001_rd_lambda_party_processor_f8ca" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_party_bucket_f971-collision_data_minilake_c001_r-91c1cbe2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_party_processor_f8ca.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_bucket_f971.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_party_bucket_f971_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_party_bucket_f971_invoke_collision_data_minilake_c001_rd_lambda_party_processor_f8ca]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_party_bucket_f971_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_bucket_f971.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_party_bucket_f971_collision_data_minilake_c001_rd_lambda_party_processor_f8ca"
    filter_prefix       = "party_raw/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_party_processor_f8ca.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_party_bucket_f971_invoke_collision_data_minilake_c001_rd_lambda_party_processor_f8ca, time_sleep.collision_data_minilake_c001_rd_s3_party_bucket_f971_iam_sleep]
}

# --- victim_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_victim_bucket_c97f" {
  bucket        = "collision-data-minilake-c001-rd-s3-victim-bucket-1a7a"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_victim_bucket_c97f_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_bucket_c97f.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_victim_bucket_c97f_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_bucket_c97f.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_victim_bucket_c97f_invoke_collision_data_minilake_c001_rd_lambda_victim_processor_7499" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_victim_bucket_c97f-collision_data_minilake_c001_-2cd5ce5e"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_victim_processor_7499.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_bucket_c97f.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_victim_bucket_c97f_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_victim_bucket_c97f_invoke_collision_data_minilake_c001_rd_lambda_victim_processor_7499]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_victim_bucket_c97f_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_bucket_c97f.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_victim_bucket_c97f_collision_data_minilake_c001_rd_lambda_victim_processor_7499"
    filter_prefix       = "victim_raw/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_victim_processor_7499.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_victim_bucket_c97f_invoke_collision_data_minilake_c001_rd_lambda_victim_processor_7499, time_sleep.collision_data_minilake_c001_rd_s3_victim_bucket_c97f_iam_sleep]
}

# --- case_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_case_bucket_cb98" {
  bucket        = "collision-data-minilake-c001-rd-s3-case-bucket-a7aa"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_case_bucket_cb98_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_bucket_cb98.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_case_bucket_cb98_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_bucket_cb98.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_case_bucket_cb98_invoke_collision_data_minilake_c001_rd_lambda_case_processor_50a3" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_case_bucket_cb98-collision_data_minilake_c001_rd-f79a94d7"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_case_processor_50a3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_bucket_cb98.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_case_bucket_cb98_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_case_bucket_cb98_invoke_collision_data_minilake_c001_rd_lambda_case_processor_50a3]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_case_bucket_cb98_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_bucket_cb98.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_case_bucket_cb98_collision_data_minilake_c001_rd_lambda_case_processor_50a3"
    filter_prefix       = "case_raw/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_case_processor_50a3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_case_bucket_cb98_invoke_collision_data_minilake_c001_rd_lambda_case_processor_50a3, time_sleep.collision_data_minilake_c001_rd_s3_case_bucket_cb98_iam_sleep]
}

# --- collision_processor ---
data "archive_file" "collision_data_minilake_c001_rd_lambda_collision_processor_e79e_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_minilake_c001_rd_lambda_collision_processor_e79e_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_minilake_c001_rd_lambda_collision_processor_e79e_role" {
  name = "collision-data-minilake-c001-rd-lambda-collision-pr-540503d-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_minilake_c001_rd_lambda_collision_processor_e79e_policy" {
  name = "collision-data-minilake-c001-rd-lambda-collision-540503d-policy"
  role = aws_iam_role.collision_data_minilake_c001_rd_lambda_collision_processor_e79e_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_minilake_c001_rd_lambda_collision_processor_e79e_lg" {
  name              = "/aws/lambda/collision-data-minilake-c001-rd-lambda-collision-processor-cdf1"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_minilake_c001_rd_lambda_collision_processor_e79e" {
  function_name    = "collision-data-minilake-c001-rd-lambda-collision-processor-cdf1"
  role             = aws_iam_role.collision_data_minilake_c001_rd_lambda_collision_processor_e79e_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_minilake_c001_rd_lambda_collision_processor_e79e_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_minilake_c001_rd_lambda_collision_processor_e79e_placeholder.output_base64sha256

  environment {
    variables = {
      COLLISION_STAGING_BUCKET_BUCKET = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371.id
    }
  }

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_minilake_c001_rd_lambda_collision_processor_e79e_lg]
}

# --- party_processor ---
data "archive_file" "collision_data_minilake_c001_rd_lambda_party_processor_f8ca_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_minilake_c001_rd_lambda_party_processor_f8ca_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_minilake_c001_rd_lambda_party_processor_f8ca_role" {
  name = "collision-data-minilake-c001-rd-lambda-party-processor-b3e8-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_minilake_c001_rd_lambda_party_processor_f8ca_policy" {
  name = "collision-data-minilake-c001-rd-lambda-party-proc-3615cfd-policy"
  role = aws_iam_role.collision_data_minilake_c001_rd_lambda_party_processor_f8ca_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_minilake_c001_rd_lambda_party_processor_f8ca_lg" {
  name              = "/aws/lambda/collision-data-minilake-c001-rd-lambda-party-processor-b3e8"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_minilake_c001_rd_lambda_party_processor_f8ca" {
  function_name    = "collision-data-minilake-c001-rd-lambda-party-processor-b3e8"
  role             = aws_iam_role.collision_data_minilake_c001_rd_lambda_party_processor_f8ca_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_minilake_c001_rd_lambda_party_processor_f8ca_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_minilake_c001_rd_lambda_party_processor_f8ca_placeholder.output_base64sha256

  environment {
    variables = {
      PARTY_STAGING_BUCKET_BUCKET = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a.id
    }
  }

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_minilake_c001_rd_lambda_party_processor_f8ca_lg]
}

# --- victim_processor ---
data "archive_file" "collision_data_minilake_c001_rd_lambda_victim_processor_7499_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_minilake_c001_rd_lambda_victim_processor_7499_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_minilake_c001_rd_lambda_victim_processor_7499_role" {
  name = "collision-data-minilake-c001-rd-lambda-victim-proce-aec29e2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_minilake_c001_rd_lambda_victim_processor_7499_policy" {
  name = "collision-data-minilake-c001-rd-lambda-victim-pro-aec29e2-policy"
  role = aws_iam_role.collision_data_minilake_c001_rd_lambda_victim_processor_7499_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_minilake_c001_rd_lambda_victim_processor_7499_lg" {
  name              = "/aws/lambda/collision-data-minilake-c001-rd-lambda-victim-processor-1931"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_minilake_c001_rd_lambda_victim_processor_7499" {
  function_name    = "collision-data-minilake-c001-rd-lambda-victim-processor-1931"
  role             = aws_iam_role.collision_data_minilake_c001_rd_lambda_victim_processor_7499_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_minilake_c001_rd_lambda_victim_processor_7499_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_minilake_c001_rd_lambda_victim_processor_7499_placeholder.output_base64sha256

  environment {
    variables = {
      VICTIM_STAGING_BUCKET_BUCKET = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff.id
    }
  }

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_minilake_c001_rd_lambda_victim_processor_7499_lg]
}

# --- case_processor ---
data "archive_file" "collision_data_minilake_c001_rd_lambda_case_processor_50a3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_minilake_c001_rd_lambda_case_processor_50a3_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_minilake_c001_rd_lambda_case_processor_50a3_role" {
  name = "collision-data-minilake-c001-rd-lambda-case-processor-a528-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_minilake_c001_rd_lambda_case_processor_50a3_policy" {
  name = "collision-data-minilake-c001-rd-lambda-case-proce-205ca70-policy"
  role = aws_iam_role.collision_data_minilake_c001_rd_lambda_case_processor_50a3_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_minilake_c001_rd_lambda_case_processor_50a3_lg" {
  name              = "/aws/lambda/collision-data-minilake-c001-rd-lambda-case-processor-a528"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_minilake_c001_rd_lambda_case_processor_50a3" {
  function_name    = "collision-data-minilake-c001-rd-lambda-case-processor-a528"
  role             = aws_iam_role.collision_data_minilake_c001_rd_lambda_case_processor_50a3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_minilake_c001_rd_lambda_case_processor_50a3_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_minilake_c001_rd_lambda_case_processor_50a3_placeholder.output_base64sha256

  environment {
    variables = {
      CASE_STAGING_BUCKET_BUCKET = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11.id
    }
  }

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_minilake_c001_rd_lambda_case_processor_50a3_lg]
}

# --- collision_staging_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371" {
  bucket        = "collision-data-minilake-c001-rd-s3-collision-staging-bu-bc38198"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371-collision_data_min-32348320"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_collision_data_minilake_c001_rd_lambda_refine_data_c370"
    filter_prefix       = "collision/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370, time_sleep.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371_iam_sleep]
}

# --- party_staging_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a" {
  bucket        = "collision-data-minilake-c001-rd-s3-party-staging-bucket-4e3d"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a-collision_data_minilak-73e15bad"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_collision_data_minilake_c001_rd_lambda_refine_data_c370"
    filter_prefix       = "party/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370, time_sleep.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a_iam_sleep]
}

# --- victim_staging_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff" {
  bucket        = "collision-data-minilake-c001-rd-s3-victim-staging-bucket-c6fd"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff-collision_data_minila-004e3c2d"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_collision_data_minilake_c001_rd_lambda_refine_data_c370"
    filter_prefix       = "victim/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370, time_sleep.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff_iam_sleep]
}

# --- case_staging_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11" {
  bucket        = "collision-data-minilake-c001-rd-s3-case-staging-bucket-facb"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370" {
  statement_id  = "AllowS3-collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11-collision_data_minilake-bb957fec"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11.arn
}

resource "time_sleep" "collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_iam_sleep" {
  depends_on      = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_notification" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11.id

  lambda_function {
    id                  = "collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_collision_data_minilake_c001_rd_lambda_refine_data_c370"
    filter_prefix       = "case/"
    lambda_function_arn = aws_lambda_function.collision_data_minilake_c001_rd_lambda_refine_data_c370.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_invoke_collision_data_minilake_c001_rd_lambda_refine_data_c370, time_sleep.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11_iam_sleep]
}

# --- refine_data ---
data "archive_file" "collision_data_minilake_c001_rd_lambda_refine_data_c370_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_minilake_c001_rd_lambda_refine_data_c370_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_minilake_c001_rd_lambda_refine_data_c370_role" {
  name = "collision-data-minilake-c001-rd-lambda-refine-data-749f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_minilake_c001_rd_lambda_refine_data_c370_policy" {
  name = "collision-data-minilake-c001-rd-lambda-refine-data-749f-policy"
  role = aws_iam_role.collision_data_minilake_c001_rd_lambda_refine_data_c370_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_minilake_c001_rd_lambda_refine_data_c370_lg" {
  name              = "/aws/lambda/collision-data-minilake-c001-rd-lambda-refine-data-749f"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_minilake_c001_rd_lambda_refine_data_c370" {
  function_name    = "collision-data-minilake-c001-rd-lambda-refine-data-749f"
  role             = aws_iam_role.collision_data_minilake_c001_rd_lambda_refine_data_c370_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 1024
  timeout          = 600
  filename         = data.archive_file.collision_data_minilake_c001_rd_lambda_refine_data_c370_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_minilake_c001_rd_lambda_refine_data_c370_placeholder.output_base64sha256

  environment {
    variables = {
      MINILAKE_BUCKET_BUCKET = aws_s3_bucket.collision_data_minilake_c001_rd_s3_minilake_bucket_8632.id
    }
  }

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_minilake_c001_rd_lambda_refine_data_c370_lg]
}

# --- minilake_bucket ---
resource "aws_s3_bucket" "collision_data_minilake_c001_rd_s3_minilake_bucket_8632" {
  bucket        = "collision-data-minilake-c001-rd-s3-minilake-bucket-ad8c"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_minilake_c001_rd_s3_minilake_bucket_8632_versioning" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_minilake_bucket_8632.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_minilake_c001_rd_s3_minilake_bucket_8632_sse" {
  bucket = aws_s3_bucket.collision_data_minilake_c001_rd_s3_minilake_bucket_8632.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- minilake_crawler ---
resource "aws_cloudwatch_log_group" "collision_data_minilake_c001_rd_glue_minilake_crawler_e544_lg" {
  name              = "/aws-glue/jobs/collision-data-minilake-c001-rd-glue-minilake-crawler-9841"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "collision_data_minilake_c001_rd_glue_minilake_crawler_e544_db" {
  name = "collision_data_minilake_c001_rd_glue_minilake_crawler_9841_db"

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "collision_data_minilake_c001_rd_glue_minilake_crawler_e544_role" {
  name = "collision-data-minilake-c001-rd-glue-minilake-crawler-9841-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_minilake_c001_rd_glue_minilake_crawler_e544_policy" {
  name = "collision-data-minilake-c001-rd-glue-minilake-cra-c990dca-policy"
  role = aws_iam_role.collision_data_minilake_c001_rd_glue_minilake_crawler_e544_role.id

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

resource "aws_glue_crawler" "collision_data_minilake_c001_rd_glue_minilake_crawler_e544" {
  name          = "collision-data-minilake-c001-rd-glue-minilake-crawler-9841"
  database_name = aws_glue_catalog_database.collision_data_minilake_c001_rd_glue_minilake_crawler_e544_db.name
  role          = aws_iam_role.collision_data_minilake_c001_rd_glue_minilake_crawler_e544_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.collision_data_minilake_c001_rd_s3_collision_staging_bucket_5371.id}/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.collision_data_minilake_c001_rd_s3_party_staging_bucket_b09a.id}/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.collision_data_minilake_c001_rd_s3_victim_staging_bucket_b2ff.id}/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.collision_data_minilake_c001_rd_s3_case_staging_bucket_ae11.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- minilake_database ---
resource "aws_glue_catalog_database" "collision_data_minilake_c001_rd_glue_data_catalog_minilake_database_21f2" {
  name        = "collision_data_minilake_c001_rd_glue_data_catalog_minil_4df32f1"
  description = "Glue Data Catalog database"
}

# --- athena_query_engine ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "collision_data_minilake_c001_rd_athena_athena_query_engine_6497_lg" {
  name              = "/aws/athena/collision-data-minilake-c001-rd-athena-athena-query-engine-7fee"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "collision_data_minilake_c001_rd_athena_athena_query_engine_6497" {
  name = "collision-data-minilake-c001-rd-athena-athena-query-engine-7fee"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://collision-data-minilake-c001-rd-athena-athena-query-engine-7fee-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "collision_data_minilake"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
