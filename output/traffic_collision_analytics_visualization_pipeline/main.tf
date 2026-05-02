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
resource "aws_s3_bucket" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1" {
  bucket        = "traffic-collision-analytics-visualization-pipeline-engi-810bbc1"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_versioning" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_sse" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudwatch_event_rule" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all" {
  name          = "traffic-collision-analytics-visualization-pi-1b9f680-eb-objectcr"
  description   = "S3 EventBridge fan-out: traffic-collision-analytics-visualization-pipeline-engi-810bbc1 / s3:ObjectCreated:*"
  event_pattern = "{\"source\": [\"aws.s3\"], \"detail\": {\"bucket\": {\"name\": [\"traffic-collision-analytics-visualization-pipeline-engi-810bbc1\"]}}, \"detail-type\": [\"Object Created\"]}"

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_cloudwatch_event_target" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all_to_traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1" {
  rule      = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.name
  target_id = "objectcreated_al-traffic_collision_analytics_visualizat-7c900930"
  arn       = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1.arn
}

resource "aws_lambda_permission" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_allow_eb_traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1" {
  statement_id  = "AllowS3EB-traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_c-b1ebb44a"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all_to_traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2" {
  rule      = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.name
  target_id = "objectcreated_al-traffic_collision_analytics_visualizat-f86df421"
  arn       = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2.arn
}

resource "aws_lambda_permission" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_allow_eb_traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1" {
  statement_id  = "AllowS3EB-traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_c-330fedff"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all_to_traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3" {
  rule      = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.name
  target_id = "objectcreated_al-traffic_collision_analytics_visualizat-1e6d6605"
  arn       = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3.arn
}

resource "aws_lambda_permission" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_allow_eb_traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1" {
  statement_id  = "AllowS3EB-traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_c-079e7790"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.arn
}

resource "aws_cloudwatch_event_target" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all_to_traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4" {
  rule      = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.name
  target_id = "objectcreated_al-traffic_collision_analytics_visualizat-06dabf8e"
  arn       = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4.arn
}

resource "aws_lambda_permission" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_allow_eb_traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1" {
  statement_id  = "AllowS3EB-traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_c-1abb6e08"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_eb_objectcreated_all.arn
}

resource "aws_s3_bucket_notification" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_notification" {
  bucket      = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id
  eventbridge = true

}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_collision_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "collision/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_party_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "party/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_victim_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "victim/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1_case_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_raw_1.id

  key = "case/"

  content_type = "application/x-directory"
}

# --- collision_preprocessor ---
data "archive_file" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_role" {
  name = "traffic-collision-analytics-visualization-pipeline-686bc21-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-686bc21-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-visualization-pipeline-engin-649d9a7"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1" {
  function_name    = "traffic-collision-analytics-visualization-pipeline-engin-649d9a7"
  role             = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_collision_preprocessor_1_lg]
}

# --- victim_preprocessor ---
data "archive_file" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_role" {
  name = "traffic-collision-analytics-visualization-pipeline-2bf8cfc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-2bf8cfc-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-visualization-pipeline-engin-cf9a021"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2" {
  function_name    = "traffic-collision-analytics-visualization-pipeline-engin-cf9a021"
  role             = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_victim_preprocessor_2_lg]
}

# --- party_preprocessor ---
data "archive_file" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_role" {
  name = "traffic-collision-analytics-visualization-pipeline-34a3b53-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-34a3b53-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-visualization-pipeline-engin-d544741"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3" {
  function_name    = "traffic-collision-analytics-visualization-pipeline-engin-d544741"
  role             = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_party_preprocessor_3_lg]
}

# --- case_preprocessor ---
data "archive_file" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_role" {
  name = "traffic-collision-analytics-visualization-pipeline-97cb201-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-97cb201-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_lg" {
  name              = "/aws/lambda/traffic-collision-analytics-visualization-pipeline-engin-8c6a60e"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4" {
  function_name    = "traffic-collision-analytics-visualization-pipeline-engin-8c6a60e"
  role             = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_placeholder.output_base64sha256

  environment {
    variables = {
      PREPROCESSING_QUEUE_QUEUE_URL = aws_sqs_queue.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sqs_preprocessing_queue.url
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_analytics_visualization_pipeline_engineering_cc001_lambda_case_preprocessor_4_lg]
}

# --- preprocessing_queue ---
resource "aws_sqs_queue" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_sqs_preprocessing_queue" {
  name                       = "traffic-collision-analytics-visualization-pipeline-engineering-cc001-sqs-633d0c2"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- emr_serverless_clean_transform ---
# ⚠️  WARNING: emr_serverless is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_emr_serverless_emr_serverless_clean_transform_role" {
  name = "traffic-collision-analytics-visualization-pipeline-98e8416-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "emr-serverless.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_emr_serverless_emr_serverless_clean_transform_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-98e8416-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_emr_serverless_emr_serverless_clean_transform_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_emr_serverless_emr_serverless_clean_transform_lg" {
  name              = "/aws/emr-serverless/traffic-collision-analytics-visualization-pipeline-engin-8abae1f"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# ⚠️ PREREQUISITE: Enable EMR Serverless in your AWS account first.
# Go to: AWS Console → EMR → EMR Serverless → Get started (one-time per account/region).
# Without this step, terraform apply will fail with SubscriptionRequiredException.
resource "aws_emrserverless_application" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_emr_serverless_emr_serverless_clean_transform" {
  name          = "traffic-collision-analytics-visualization-pipeline-engin-8abae1f"
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
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- traffic_collision_staging ---
resource "aws_s3_bucket" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2" {
  bucket        = "traffic-collision-analytics-visualization-pipeline-engi-f3ffb19"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2_versioning" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2_sse" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2_collision_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  key = "collision/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2_party_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  key = "party/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2_victim_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  key = "victim/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2_case_prefix" {
  bucket = aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id

  key = "case/"

  content_type = "application/x-directory"
}

# --- glue_data_catalog ---
resource "aws_cloudwatch_log_group" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_lg" {
  name              = "/aws-glue/jobs/traffic-collision-analytics-visualization-pipeline-engineering-cc001-glue-glue-data-catalog"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_db" {
  name = "traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_db"

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_role" {
  name = "traffic-collision-analytics-visualization-pipeline-f59cd6b-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-f59cd6b-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_role.id

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
          "glue:BatchDeletePartition"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_glue_crawler" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog" {
  name          = "traffic-collision-analytics-visualization-pipeline-engineering-cc001-glue-glue-data-catalog"
  database_name = aws_glue_catalog_database.traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_db.name
  role          = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_glue_glue_data_catalog_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.traffic_collision_analytics_visualization_pipeline_engineering_cc001_s3_traffic_collision_staging_2.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- athena_query_tables ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_athena_athena_query_tables_lg" {
  name              = "/aws/athena/traffic-collision-analytics-visualization-pipeline-engineering-cc001-athena-athena-query-tables"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_athena_athena_query_tables" {
  name = "traffic-collision-analytics-visualization-pipeline-engineering-cc001-athena-athena-query-tables"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://traffic-collision-analytics-visualization-pipeline-engineering-cc001-athena-athena-query-tables-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- analyst_business_notebook ---
resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_analyst_business_notebook_1_role" {
  name = "traffic-collision-analytics-visualization-pipeline-28ef21f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_analyst_business_notebook_1_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-28ef21f-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_analyst_business_notebook_1_role.id

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

resource "aws_sagemaker_notebook_instance" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_analyst_business_notebook_1" {
  name          = "traffic-collision-analytics-visualization-pipeline-engi-107432c"
  role_arn      = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_analyst_business_notebook_1_role.arn
  instance_type = "ml.t3.medium"
  volume_size   = 5
  direct_internet_access = "Enabled"

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- persistence_handson_notebook ---
resource "aws_iam_role" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_persistence_handson_notebook_2_role" {
  name = "traffic-collision-analytics-visualization-pipeline-62db750-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_persistence_handson_notebook_2_policy" {
  name = "traffic-collision-analytics-visualization-pipelin-62db750-policy"
  role = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_persistence_handson_notebook_2_role.id

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

resource "aws_sagemaker_notebook_instance" "traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_persistence_handson_notebook_2" {
  name          = "traffic-collision-analytics-visualization-pipeline-engi-ccfb201"
  role_arn      = aws_iam_role.traffic_collision_analytics_visualization_pipeline_engineering_cc001_sagemaker_notebook_persistence_handson_notebook_2_role.arn
  instance_type = "ml.t3.medium"
  volume_size   = 5
  direct_internet_access = "Enabled"

  tags = {
    Pipeline      = "traffic_collision_analytics_visualization_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
