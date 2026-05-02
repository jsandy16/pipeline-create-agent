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
resource "aws_s3_bucket" "s3_prefix_processor_engineering_cc001_s3_src" {
  bucket        = "s3-prefix-processor-engineering-cc001-s3-src"
  force_destroy = true

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_prefix_processor_engineering_cc001_s3_src_versioning" {
  bucket = aws_s3_bucket.s3_prefix_processor_engineering_cc001_s3_src.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_prefix_processor_engineering_cc001_s3_src_sse" {
  bucket = aws_s3_bucket.s3_prefix_processor_engineering_cc001_s3_src.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_case_processor_1" {
  statement_id  = "AllowS3-s3_prefix_processor_engineering_cc001_s3_src-s3_prefix_processor_engineering_cc001_-ea8f091e"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_case_processor_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_processor_engineering_cc001_s3_src.arn
}

resource "aws_lambda_permission" "s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_party_processor_2" {
  statement_id  = "AllowS3-s3_prefix_processor_engineering_cc001_s3_src-s3_prefix_processor_engineering_cc001_-2e5f6ee6"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_party_processor_2.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_processor_engineering_cc001_s3_src.arn
}

resource "aws_lambda_permission" "s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_collision_processor_3" {
  statement_id  = "AllowS3-s3_prefix_processor_engineering_cc001_s3_src-s3_prefix_processor_engineering_cc001_-bd59f93d"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_collision_processor_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_processor_engineering_cc001_s3_src.arn
}

resource "aws_lambda_permission" "s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_victim_processor_4" {
  statement_id  = "AllowS3-s3_prefix_processor_engineering_cc001_s3_src-s3_prefix_processor_engineering_cc001_-f7e60527"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_victim_processor_4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_processor_engineering_cc001_s3_src.arn
}

resource "aws_s3_bucket_notification" "s3_prefix_processor_engineering_cc001_s3_src_notification" {
  bucket = aws_s3_bucket.s3_prefix_processor_engineering_cc001_s3_src.id

  lambda_function {
    id                  = "s3_prefix_processor_engineering_cc001_s3_src_s3_prefix_processor_engineering_cc001_lambda_case_processor_1"
    filter_prefix       = "case/"
    lambda_function_arn = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_case_processor_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "s3_prefix_processor_engineering_cc001_s3_src_s3_prefix_processor_engineering_cc001_lambda_party_processor_2"
    filter_prefix       = "party/"
    lambda_function_arn = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_party_processor_2.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "s3_prefix_processor_engineering_cc001_s3_src_s3_prefix_processor_engineering_cc001_lambda_collision_processor_3"
    filter_prefix       = "collision/"
    lambda_function_arn = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_collision_processor_3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "s3_prefix_processor_engineering_cc001_s3_src_s3_prefix_processor_engineering_cc001_lambda_victim_processor_4"
    filter_prefix       = "victim/"
    lambda_function_arn = aws_lambda_function.s3_prefix_processor_engineering_cc001_lambda_victim_processor_4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_case_processor_1, aws_lambda_permission.s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_party_processor_2, aws_lambda_permission.s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_collision_processor_3, aws_lambda_permission.s3_prefix_processor_engineering_cc001_s3_src_invoke_s3_prefix_processor_engineering_cc001_lambda_victim_processor_4]
}

# --- case_processor ---
data "archive_file" "s3_prefix_processor_engineering_cc001_lambda_case_processor_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processor_engineering_cc001_lambda_case_processor_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processor_engineering_cc001_lambda_case_processor_1_role" {
  name = "s3-prefix-processor-engineering-cc001-lambda-case-p-5708cb4-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processor_engineering_cc001_lambda_case_processor_1_policy" {
  name = "s3-prefix-processor-engineering-cc001-lambda-case-5708cb4-policy"
  role = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_case_processor_1_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processor_engineering_cc001_lambda_case_processor_1_lg" {
  name              = "/aws/lambda/s3-prefix-processor-engineering-cc001-lambda-case-processor-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processor_engineering_cc001_lambda_case_processor_1" {
  function_name    = "s3-prefix-processor-engineering-cc001-lambda-case-processor-1"
  role             = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_case_processor_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_case_processor_1_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_case_processor_1_placeholder.output_base64sha256

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processor_engineering_cc001_lambda_case_processor_1_lg]
}

# --- party_processor ---
data "archive_file" "s3_prefix_processor_engineering_cc001_lambda_party_processor_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processor_engineering_cc001_lambda_party_processor_2_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processor_engineering_cc001_lambda_party_processor_2_role" {
  name = "s3-prefix-processor-engineering-cc001-lambda-party-5c679fe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processor_engineering_cc001_lambda_party_processor_2_policy" {
  name = "s3-prefix-processor-engineering-cc001-lambda-part-5c679fe-policy"
  role = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_party_processor_2_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processor_engineering_cc001_lambda_party_processor_2_lg" {
  name              = "/aws/lambda/s3-prefix-processor-engineering-cc001-lambda-party-processor-2"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processor_engineering_cc001_lambda_party_processor_2" {
  function_name    = "s3-prefix-processor-engineering-cc001-lambda-party-processor-2"
  role             = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_party_processor_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_party_processor_2_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_party_processor_2_placeholder.output_base64sha256

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processor_engineering_cc001_lambda_party_processor_2_lg]
}

# --- collision_processor ---
data "archive_file" "s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_role" {
  name = "s3-prefix-processor-engineering-cc001-lambda-collis-91dce3a-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_policy" {
  name = "s3-prefix-processor-engineering-cc001-lambda-coll-91dce3a-policy"
  role = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_lg" {
  name              = "/aws/lambda/s3-prefix-processor-engineering-cc001-lambda-collision-p-3ef6f53"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processor_engineering_cc001_lambda_collision_processor_3" {
  function_name    = "s3-prefix-processor-engineering-cc001-lambda-collision-p-3ef6f53"
  role             = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_role.arn
  runtime          = "python3.11"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_placeholder.output_base64sha256

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processor_engineering_cc001_lambda_collision_processor_3_lg]
}

# --- victim_processor ---
data "archive_file" "s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_role" {
  name = "s3-prefix-processor-engineering-cc001-lambda-victim-a004023-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_policy" {
  name = "s3-prefix-processor-engineering-cc001-lambda-vict-a004023-policy"
  role = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_lg" {
  name              = "/aws/lambda/s3-prefix-processor-engineering-cc001-lambda-victim-processor-4"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_processor_engineering_cc001_lambda_victim_processor_4" {
  function_name    = "s3-prefix-processor-engineering-cc001-lambda-victim-processor-4"
  role             = aws_iam_role.s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_placeholder.output_base64sha256

  tags = {
    Pipeline      = "s3_prefix_processor"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_processor_engineering_cc001_lambda_victim_processor_4_lg]
}
