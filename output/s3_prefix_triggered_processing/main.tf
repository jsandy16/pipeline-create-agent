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
resource "aws_s3_bucket" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1" {
  bucket        = "s3-prefix-triggered-processing-engineering-cc001-s3-sou-9e1e137"
  force_destroy = true

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_versioning" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_sse" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1" {
  statement_id  = "AllowS3-s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1-s3_prefix_trigg-aab0d5d8"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.arn
}

resource "aws_lambda_permission" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2" {
  statement_id  = "AllowS3-s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1-s3_prefix_trigg-04eb9be9"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.arn
}

resource "aws_lambda_permission" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3" {
  statement_id  = "AllowS3-s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1-s3_prefix_trigg-4b3ae078"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.arn
}

resource "aws_lambda_permission" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4" {
  statement_id  = "AllowS3-s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1-s3_prefix_trigg-68c1db09"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.arn
}

resource "aws_s3_bucket_notification" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_notification" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.id

  lambda_function {
    id                  = "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1"
    filter_prefix       = "case/"
    lambda_function_arn = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2"
    filter_prefix       = "party/"
    lambda_function_arn = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3"
    filter_prefix       = "collision/"
    lambda_function_arn = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4"
    filter_prefix       = "victim/"
    lambda_function_arn = aws_lambda_function.s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1, aws_lambda_permission.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2, aws_lambda_permission.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3, aws_lambda_permission.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_invoke_s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4]
}

resource "aws_s3_object" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_case_prefix" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.id

  key = "case/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_party_prefix" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.id

  key = "party/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_collision_prefix" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.id

  key = "collision/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1_victim_prefix" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_source_bucket_1.id

  key = "victim/"

  content_type = "application/x-directory"
}

# --- target_bucket ---
resource "aws_s3_bucket" "s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2" {
  bucket        = "s3-prefix-triggered-processing-engineering-cc001-s3-tar-ef50529"
  force_destroy = true

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2_versioning" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2_sse" {
  bucket = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- case_processor ---
data "archive_file" "s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    target_bucket = os.environ.get('TARGET_BUCKET')\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        copy_source = {'Bucket': source_bucket, 'Key': key}\n        s3.copy_object(CopySource=copy_source, Bucket=target_bucket, Key=key)\n        \n    return {'statusCode': 200, 'body': json.dumps('Processing complete')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_role" {
  name = "s3-prefix-triggered-processing-engineering-cc001-la-3bc3314-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_policy" {
  name = "s3-prefix-triggered-processing-engineering-cc001-3bc3314-policy"
  role = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_lg" {
  name              = "/aws/lambda/s3-prefix-triggered-processing-engineering-cc001-lambda-663798d"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1" {
  function_name    = "s3-prefix-triggered-processing-engineering-cc001-lambda-663798d"
  role             = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_placeholder.output_base64sha256

  environment {
    variables = {
      TARGET_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_triggered_processing_engineering_cc001_lambda_case_processor_1_lg]
}

# --- party_processor ---
data "archive_file" "s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    target_bucket = os.environ.get('TARGET_BUCKET')\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        copy_source = {'Bucket': source_bucket, 'Key': key}\n        s3.copy_object(CopySource=copy_source, Bucket=target_bucket, Key=key)\n        \n    return {'statusCode': 200, 'body': json.dumps('Processing complete')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_role" {
  name = "s3-prefix-triggered-processing-engineering-cc001-la-f23ffd0-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_policy" {
  name = "s3-prefix-triggered-processing-engineering-cc001-f23ffd0-policy"
  role = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_lg" {
  name              = "/aws/lambda/s3-prefix-triggered-processing-engineering-cc001-lambda-2a1cddb"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2" {
  function_name    = "s3-prefix-triggered-processing-engineering-cc001-lambda-2a1cddb"
  role             = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_placeholder.output_base64sha256

  environment {
    variables = {
      TARGET_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_triggered_processing_engineering_cc001_lambda_party_processor_2_lg]
}

# --- collision_processor ---
data "archive_file" "s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    target_bucket = os.environ.get('TARGET_BUCKET')\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        copy_source = {'Bucket': source_bucket, 'Key': key}\n        s3.copy_object(CopySource=copy_source, Bucket=target_bucket, Key=key)\n        \n    return {'statusCode': 200, 'body': json.dumps('Processing complete')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_role" {
  name = "s3-prefix-triggered-processing-engineering-cc001-la-1941b9b-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_policy" {
  name = "s3-prefix-triggered-processing-engineering-cc001-1941b9b-policy"
  role = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_lg" {
  name              = "/aws/lambda/s3-prefix-triggered-processing-engineering-cc001-lambda-dbcf1bb"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3" {
  function_name    = "s3-prefix-triggered-processing-engineering-cc001-lambda-dbcf1bb"
  role             = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_placeholder.output_base64sha256

  environment {
    variables = {
      TARGET_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_triggered_processing_engineering_cc001_lambda_collision_processor_3_lg]
}

# --- victim_processor ---
data "archive_file" "s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    target_bucket = os.environ.get('TARGET_BUCKET')\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        copy_source = {'Bucket': source_bucket, 'Key': key}\n        s3.copy_object(CopySource=copy_source, Bucket=target_bucket, Key=key)\n        \n    return {'statusCode': 200, 'body': json.dumps('Processing complete')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_role" {
  name = "s3-prefix-triggered-processing-engineering-cc001-la-9dcd6de-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_policy" {
  name = "s3-prefix-triggered-processing-engineering-cc001-9dcd6de-policy"
  role = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_role.id

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

resource "aws_cloudwatch_log_group" "s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_lg" {
  name              = "/aws/lambda/s3-prefix-triggered-processing-engineering-cc001-lambda-4ed5aa5"
  retention_in_days = 7

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4" {
  function_name    = "s3-prefix-triggered-processing-engineering-cc001-lambda-4ed5aa5"
  role             = aws_iam_role.s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_placeholder.output_path
  source_code_hash = data.archive_file.s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_placeholder.output_base64sha256

  environment {
    variables = {
      TARGET_BUCKET_BUCKET = aws_s3_bucket.s3_prefix_triggered_processing_engineering_cc001_s3_target_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "s3_prefix_triggered_processing"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.s3_prefix_triggered_processing_engineering_cc001_lambda_victim_processor_4_lg]
}
