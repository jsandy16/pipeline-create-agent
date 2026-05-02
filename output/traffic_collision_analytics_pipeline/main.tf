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


# --- traffic_collision_raw ---
resource "aws_s3_bucket" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1" {
  bucket        = "traffic-collision-analytics-pipeline-engineering-cc001-bcc24be"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_versioning" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_sse" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1" {
  statement_id  = "AllowS3-traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1-t-e07aec57"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.arn
}

resource "aws_lambda_permission" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2" {
  statement_id  = "AllowS3-traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1-t-109afa4e"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.arn
}

resource "aws_lambda_permission" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3" {
  statement_id  = "AllowS3-traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1-t-cab9e4e9"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.arn
}

resource "aws_lambda_permission" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4" {
  statement_id  = "AllowS3-traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1-t-2b6b3cf6"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.arn
}

resource "aws_s3_bucket_notification" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_notification" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  lambda_function {
    id                  = "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1"
    filter_prefix       = "collision/"
    lambda_function_arn = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2"
    filter_prefix       = "victim/"
    lambda_function_arn = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3"
    filter_prefix       = "party/"
    lambda_function_arn = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4"
    filter_prefix       = "case/"
    lambda_function_arn = aws_lambda_function.traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1, aws_lambda_permission.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2, aws_lambda_permission.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3, aws_lambda_permission.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_invoke_traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4]
}

resource "aws_s3_object" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_collision_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "collision/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_victim_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "victim/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_party_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "party/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1_case_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "case/"

  content_type = "application/x-directory"
}

# --- collision_preprocessor ---
data "archive_file" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder.zip"
  source {
    content  = "import json\nimport boto3\n\nsqs = boto3.client('sqs')\nQUEUE_URL = 'REPLACE_WITH_QUEUE_URL'\n\ndef handler(event, context):\n    for record in event['Records']:\n        bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        print(f'Processing collision data: {key}')\n        \n        # Data cleaning and schema normalization logic here\n        \n        # Send completion message to SQS\n        message = {\n            'source': 'collision_preprocessor',\n            'bucket': bucket,\n            'key': key,\n            'status': 'completed'\n        }\n        \n        sqs.send_message(\n            QueueUrl=QUEUE_URL,\n            MessageBody=json.dumps(message)\n        )\n        \n    return {'statusCode': 200, 'body': 'Preprocessing completed'}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_role" {
  name = "traffic-collision-analytics-pipeline-engineering-cc-de9cfad-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_policy" {
  name = "traffic-collision-analytics-pipeline-engineering-de9cfad-policy"
  role = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_role.id

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
          "sqs:SendMessage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-pipeline-engineering-cc001-l-9fbb92e"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1" {
  function_name    = "traffic-collision-analytics-pipeline-engineering-cc001-l-9fbb92e"
  role             = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_pipeline_engineering_cc001_lambda_collision_preprocessor_1_lg]
}

# --- victim_preprocessor ---
data "archive_file" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder.zip"
  source {
    content  = "import json\nimport boto3\n\nsqs = boto3.client('sqs')\nQUEUE_URL = 'REPLACE_WITH_QUEUE_URL'\n\ndef handler(event, context):\n    for record in event['Records']:\n        bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        print(f'Processing victim data: {key}')\n        \n        # Data cleaning and schema normalization logic here\n        \n        # Send completion message to SQS\n        message = {\n            'source': 'victim_preprocessor',\n            'bucket': bucket,\n            'key': key,\n            'status': 'completed'\n        }\n        \n        sqs.send_message(\n            QueueUrl=QUEUE_URL,\n            MessageBody=json.dumps(message)\n        )\n        \n    return {'statusCode': 200, 'body': 'Preprocessing completed'}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_role" {
  name = "traffic-collision-analytics-pipeline-engineering-cc-2a17243-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_policy" {
  name = "traffic-collision-analytics-pipeline-engineering-2a17243-policy"
  role = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_role.id

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
          "sqs:SendMessage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-pipeline-engineering-cc001-l-0bca4cf"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2" {
  function_name    = "traffic-collision-analytics-pipeline-engineering-cc001-l-0bca4cf"
  role             = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_pipeline_engineering_cc001_lambda_victim_preprocessor_2_lg]
}

# --- party_preprocessor ---
data "archive_file" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder.zip"
  source {
    content  = "import json\nimport boto3\n\nsqs = boto3.client('sqs')\nQUEUE_URL = 'REPLACE_WITH_QUEUE_URL'\n\ndef handler(event, context):\n    for record in event['Records']:\n        bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        print(f'Processing party data: {key}')\n        \n        # Data cleaning and schema normalization logic here\n        \n        # Send completion message to SQS\n        message = {\n            'source': 'party_preprocessor',\n            'bucket': bucket,\n            'key': key,\n            'status': 'completed'\n        }\n        \n        sqs.send_message(\n            QueueUrl=QUEUE_URL,\n            MessageBody=json.dumps(message)\n        )\n        \n    return {'statusCode': 200, 'body': 'Preprocessing completed'}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_role" {
  name = "traffic-collision-analytics-pipeline-engineering-cc-12df30f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_policy" {
  name = "traffic-collision-analytics-pipeline-engineering-12df30f-policy"
  role = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_role.id

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
          "sqs:SendMessage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-pipeline-engineering-cc001-l-6794295"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3" {
  function_name    = "traffic-collision-analytics-pipeline-engineering-cc001-l-6794295"
  role             = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_pipeline_engineering_cc001_lambda_party_preprocessor_3_lg]
}

# --- case_preprocessor ---
data "archive_file" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder.zip"
  source {
    content  = "import json\nimport boto3\n\nsqs = boto3.client('sqs')\nQUEUE_URL = 'REPLACE_WITH_QUEUE_URL'\n\ndef handler(event, context):\n    for record in event['Records']:\n        bucket = record['s3']['bucket']['name']\n        key = record['s3']['object']['key']\n        \n        print(f'Processing case data: {key}')\n        \n        # Data cleaning and schema normalization logic here\n        \n        # Send completion message to SQS\n        message = {\n            'source': 'case_preprocessor',\n            'bucket': bucket,\n            'key': key,\n            'status': 'completed'\n        }\n        \n        sqs.send_message(\n            QueueUrl=QUEUE_URL,\n            MessageBody=json.dumps(message)\n        )\n        \n    return {'statusCode': 200, 'body': 'Preprocessing completed'}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_role" {
  name = "traffic-collision-analytics-pipeline-engineering-cc-be8d2d2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_policy" {
  name = "traffic-collision-analytics-pipeline-engineering-be8d2d2-policy"
  role = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_role.id

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
          "sqs:SendMessage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-pipeline-engineering-cc001-l-b1d243e"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4" {
  function_name    = "traffic-collision-analytics-pipeline-engineering-cc001-l-b1d243e"
  role             = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_pipeline_engineering_cc001_lambda_case_preprocessor_4_lg]
}

# --- preprocessing_queue ---
resource "aws_sqs_queue" "traffic_collision_analytics_pipeline_engineering_cc001_sqs_preprocessing_queue" {
  name                       = "traffic-collision-analytics-pipeline-engineering-cc001-sqs-preprocessing-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- emr_transform_job ---
# ⚠️  WARNING: emr_serverless is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_iam_role" "traffic_collision_analytics_pipeline_engineering_cc001_emr_serverless_emr_transform_job_role" {
  name = "traffic-collision-analytics-pipeline-engineering-cc-20a50e7-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "emr-serverless.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_pipeline_engineering_cc001_emr_serverless_emr_transform_job_policy" {
  name = "traffic-collision-analytics-pipeline-engineering-20a50e7-policy"
  role = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_emr_serverless_emr_transform_job_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_pipeline_engineering_cc001_emr_serverless_emr_transform_job_lg" {
  name              = "/aws/emr-serverless/traffic-collision-analytics-pipeline-engineering-cc001-e-cd4cc8b"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# ⚠️ PREREQUISITE: Enable EMR Serverless in your AWS account first.
# Go to: AWS Console → EMR → EMR Serverless → Get started (one-time per account/region).
# Without this step, terraform apply will fail with SubscriptionRequiredException.
resource "aws_emrserverless_application" "traffic_collision_analytics_pipeline_engineering_cc001_emr_serverless_emr_transform_job" {
  name          = "traffic-collision-analytics-pipeline-engineering-cc001-e-cd4cc8b"
  release_label = "emr-6.10.0"
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
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- traffic_collision_staging ---
resource "aws_s3_bucket" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_staging_2" {
  bucket        = "traffic-collision-analytics-pipeline-engineering-cc001-b03d8d1"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_staging_2_versioning" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_staging_2_sse" {
  bucket = aws_s3_bucket.traffic_collision_analytics_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- collision_catalog ---
resource "aws_glue_catalog_database" "traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog" {
  name        = "traffic_collision_analytics_pipeline_engineering_cc001_ae8237f"
  description = "Glue Data Catalog database"
}

resource "aws_glue_catalog_table" "traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog_collision_tbl_table" {
  database_name = aws_glue_catalog_database.traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog.name

  name = "collision_tbl"

  table_type = "EXTERNAL_TABLE"

  parameters {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://traffic_collision_staging/collision/"

    input_format = "org.apache.hadoop.mapred.TextInputFormat"

    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
    }

    columns {
      name = "collision_id"
      type = "string"
    }

    columns {
      name = "collision_type"
      type = "string"
    }

    columns {
      name = "collision_timestamp"
      type = "timestamp"
    }

    columns {
      name = "location"
      type = "string"
    }

    columns {
      name = "severity"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog_victim_tbl_table" {
  database_name = aws_glue_catalog_database.traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog.name

  name = "victim_tbl"

  table_type = "EXTERNAL_TABLE"

  parameters {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://traffic_collision_staging/victim/"

    input_format = "org.apache.hadoop.mapred.TextInputFormat"

    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
    }

    columns {
      name = "victim_id"
      type = "string"
    }

    columns {
      name = "collision_id"
      type = "string"
    }

    columns {
      name = "victim_name"
      type = "string"
    }

    columns {
      name = "age"
      type = "int"
    }

    columns {
      name = "injury_type"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog_party_tbl_table" {
  database_name = aws_glue_catalog_database.traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog.name

  name = "party_tbl"

  table_type = "EXTERNAL_TABLE"

  parameters {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://traffic_collision_staging/party/"

    input_format = "org.apache.hadoop.mapred.TextInputFormat"

    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
    }

    columns {
      name = "party_id"
      type = "string"
    }

    columns {
      name = "collision_id"
      type = "string"
    }

    columns {
      name = "party_name"
      type = "string"
    }

    columns {
      name = "party_type"
      type = "string"
    }

    columns {
      name = "vehicle_type"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog_case_tbl_table" {
  database_name = aws_glue_catalog_database.traffic_collision_analytics_pipeline_engineering_cc001_glue_data_catalog_collision_catalog.name

  name = "case_tbl"

  table_type = "EXTERNAL_TABLE"

  parameters {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://traffic_collision_staging/case/"

    input_format = "org.apache.hadoop.mapred.TextInputFormat"

    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
    }

    columns {
      name = "case_id"
      type = "string"
    }

    columns {
      name = "collision_id"
      type = "string"
    }

    columns {
      name = "case_number"
      type = "string"
    }

    columns {
      name = "case_date"
      type = "timestamp"
    }

    columns {
      name = "case_status"
      type = "string"
    }
  }
}

# --- collision_athena ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_pipeline_engineering_cc001_athena_collision_athena_lg" {
  name              = "/aws/athena/traffic-collision-analytics-pipeline-engineering-cc001-athena-collision-athena"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "traffic_collision_analytics_pipeline_engineering_cc001_athena_collision_athena" {
  name = "traffic-collision-analytics-pipeline-engineering-cc001-athena-collision-athena"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://traffic-collision-analytics-pipeline-engineering-cc001-athena-collision-athena-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- analytics_notebook ---
resource "aws_iam_role" "traffic_collision_analytics_pipeline_engineering_cc001_sagemaker_notebook_analytics_notebook_role" {
  name = "traffic-collision-analytics-pipeline-engineering-cc-aa1b69f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_pipeline_engineering_cc001_sagemaker_notebook_analytics_notebook_policy" {
  name = "traffic-collision-analytics-pipeline-engineering-aa1b69f-policy"
  role = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_sagemaker_notebook_analytics_notebook_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sagemaker:DescribeNotebookInstance",
          "sagemaker:ListTags"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_sagemaker_notebook_instance" "traffic_collision_analytics_pipeline_engineering_cc001_sagemaker_notebook_analytics_notebook" {
  name          = "traffic-collision-analytics-pipeline-engineering-cc001-0abb5ea"
  role_arn      = aws_iam_role.traffic_collision_analytics_pipeline_engineering_cc001_sagemaker_notebook_analytics_notebook_role.arn
  instance_type = "ml.t3.medium"
  volume_size   = 5
  direct_internet_access = "Enabled"

  tags = {
    Pipeline      = "traffic_collision_analytics_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
