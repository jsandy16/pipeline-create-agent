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


# --- raw_data_bucket ---
resource "aws_s3_bucket" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1" {
  bucket        = "traffic-collision-minilake-analytics-d0012-s3-raw-data-bucket-1"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_versioning" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_sse" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1" {
  statement_id  = "AllowS3-traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1-traffic_collision_m-0c5b54f3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.arn
}

resource "aws_lambda_permission" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_party_processor_2" {
  statement_id  = "AllowS3-traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1-traffic_collision_m-b1a5035a"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_party_processor_2.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.arn
}

resource "aws_lambda_permission" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3" {
  statement_id  = "AllowS3-traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1-traffic_collision_m-7befa90e"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.arn
}

resource "aws_lambda_permission" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_case_processor_4" {
  statement_id  = "AllowS3-traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1-traffic_collision_m-9a344664"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_case_processor_4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.arn
}

resource "time_sleep" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_iam_sleep" {
  depends_on      = [aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1, aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_party_processor_2, aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3, aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_case_processor_4]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_notification" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.id

  lambda_function {
    id                  = "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1"
    filter_prefix       = "collision_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_traffic_collision_minilake_analytics_d0012_lambda_party_processor_2"
    filter_prefix       = "party_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_party_processor_2.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3"
    filter_prefix       = "victim_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_traffic_collision_minilake_analytics_d0012_lambda_case_processor_4"
    filter_prefix       = "case_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_case_processor_4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1, aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_party_processor_2, aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3, aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_invoke_traffic_collision_minilake_analytics_d0012_lambda_case_processor_4, time_sleep.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_iam_sleep]
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_collision_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.id

  key = "collision_raw/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_party_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.id

  key = "party_raw/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_victim_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.id

  key = "victim_raw/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1_case_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_raw_data_bucket_1.id

  key = "case_raw/"

  content_type = "application/x-directory"
}

# --- collision_processor ---
data "archive_file" "traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        obj = s3.get_object(Bucket=source_bucket, Key=source_key)\n        data = obj['Body'].read().decode('utf-8')\n        \n        target_key = f\"collision/{source_key.split('/')[-1]}\"\n        s3.put_object(\n            Bucket=staging_bucket,\n            Key=target_key,\n            Body=data\n        )\n    \n    return {'statusCode': 200, 'body': json.dumps('Collision data processed')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_role" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-c-b070a38-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_policy" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-b070a38-policy"
  role = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_lg" {
  name              = "/aws/lambda/traffic-collision-minilake-analytics-d0012-lambda-collis-095b615"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1" {
  function_name    = "traffic-collision-minilake-analytics-d0012-lambda-collis-095b615"
  role             = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_minilake_analytics_d0012_lambda_collision_processor_1_lg]
}

# --- party_processor ---
data "archive_file" "traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        obj = s3.get_object(Bucket=source_bucket, Key=source_key)\n        data = obj['Body'].read().decode('utf-8')\n        \n        target_key = f\"party/{source_key.split('/')[-1]}\"\n        s3.put_object(\n            Bucket=staging_bucket,\n            Key=target_key,\n            Body=data\n        )\n    \n    return {'statusCode': 200, 'body': json.dumps('Party data processed')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_role" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-p-510389f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_policy" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-510389f-policy"
  role = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_lg" {
  name              = "/aws/lambda/traffic-collision-minilake-analytics-d0012-lambda-party-f83095f"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_minilake_analytics_d0012_lambda_party_processor_2" {
  function_name    = "traffic-collision-minilake-analytics-d0012-lambda-party-f83095f"
  role             = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_minilake_analytics_d0012_lambda_party_processor_2_lg]
}

# --- victim_processor ---
data "archive_file" "traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        obj = s3.get_object(Bucket=source_bucket, Key=source_key)\n        data = obj['Body'].read().decode('utf-8')\n        \n        target_key = f\"victim/{source_key.split('/')[-1]}\"\n        s3.put_object(\n            Bucket=staging_bucket,\n            Key=target_key,\n            Body=data\n        )\n    \n    return {'statusCode': 200, 'body': json.dumps('Victim data processed')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_role" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-v-e2a2c99-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_policy" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-e2a2c99-policy"
  role = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_lg" {
  name              = "/aws/lambda/traffic-collision-minilake-analytics-d0012-lambda-victim-6cbc55c"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3" {
  function_name    = "traffic-collision-minilake-analytics-d0012-lambda-victim-6cbc55c"
  role             = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_minilake_analytics_d0012_lambda_victim_processor_3_lg]
}

# --- case_processor ---
data "archive_file" "traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        obj = s3.get_object(Bucket=source_bucket, Key=source_key)\n        data = obj['Body'].read().decode('utf-8')\n        \n        target_key = f\"case/{source_key.split('/')[-1]}\"\n        s3.put_object(\n            Bucket=staging_bucket,\n            Key=target_key,\n            Body=data\n        )\n    \n    return {'statusCode': 200, 'body': json.dumps('Case data processed')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_role" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-c-e6a9e43-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_policy" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-e6a9e43-policy"
  role = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_lg" {
  name              = "/aws/lambda/traffic-collision-minilake-analytics-d0012-lambda-case-p-ee8edaf"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_minilake_analytics_d0012_lambda_case_processor_4" {
  function_name    = "traffic-collision-minilake-analytics-d0012-lambda-case-p-ee8edaf"
  role             = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 60
  filename         = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_minilake_analytics_d0012_lambda_case_processor_4_lg]
}

# --- staging_bucket ---
resource "aws_s3_bucket" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2" {
  bucket        = "traffic-collision-minilake-analytics-d0012-s3-staging-bucket-2"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_versioning" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_sse" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_invoke_traffic_collision_minilake_analytics_d0012_lambda_refine_data_5" {
  statement_id  = "AllowS3-traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2-traffic_collision_mi-2420134b"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_refine_data_5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.arn
}

resource "time_sleep" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_iam_sleep" {
  depends_on      = [aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_invoke_traffic_collision_minilake_analytics_d0012_lambda_refine_data_5]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_notification" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id

  lambda_function {
    id                  = "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_traffic_collision_minilake_analytics_d0012_lambda_refine_data_5"
    lambda_function_arn = aws_lambda_function.traffic_collision_minilake_analytics_d0012_lambda_refine_data_5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_invoke_traffic_collision_minilake_analytics_d0012_lambda_refine_data_5, time_sleep.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_iam_sleep]
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_collision_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id

  key = "collision/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_party_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id

  key = "party/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_victim_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id

  key = "victim/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2_case_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_staging_bucket_2.id

  key = "case/"

  content_type = "application/x-directory"
}

# --- refine_data ---
data "archive_file" "traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3 = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    minilake_bucket = os.environ['MINILAKE_BUCKET']\n    \n    prefixes = ['collision/', 'party/', 'victim/', 'case/']\n    \n    for prefix in prefixes:\n        response = s3.list_objects_v2(Bucket=staging_bucket, Prefix=prefix)\n        \n        if 'Contents' not in response:\n            continue\n        \n        for obj in response['Contents']:\n            source_key = obj['Key']\n            \n            data = s3.get_object(Bucket=staging_bucket, Key=source_key)\n            body = data['Body'].read()\n            \n            target_key = source_key\n            s3.put_object(\n                Bucket=minilake_bucket,\n                Key=target_key,\n                Body=body\n            )\n    \n    return {'statusCode': 200, 'body': json.dumps('Data refined to minilake')}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_role" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-r-76f08fd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_policy" {
  name = "traffic-collision-minilake-analytics-d0012-lambda-76f08fd-policy"
  role = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_lg" {
  name              = "/aws/lambda/traffic-collision-minilake-analytics-d0012-lambda-refine-data-5"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_minilake_analytics_d0012_lambda_refine_data_5" {
  function_name    = "traffic-collision-minilake-analytics-d0012-lambda-refine-data-5"
  role             = aws_iam_role.traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 1024
  timeout          = 300
  filename         = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_placeholder.output_base64sha256

  environment {
    variables = {
      MINILAKE_BUCKET = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_minilake_analytics_d0012_lambda_refine_data_5_lg]
}

# --- minilake ---
resource "aws_s3_bucket" "traffic_collision_minilake_analytics_d0012_s3_minilake_3" {
  bucket        = "traffic-collision-minilake-analytics-d0012-s3-minilake-3"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_minilake_analytics_d0012_s3_minilake_3_versioning" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_minilake_analytics_d0012_s3_minilake_3_sse" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_minilake_3_collision_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id

  key = "collision/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_minilake_3_party_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id

  key = "party/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_minilake_3_victim_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id

  key = "victim/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_minilake_analytics_d0012_s3_minilake_3_case_prefix" {
  bucket = aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id

  key = "case/"

  content_type = "application/x-directory"
}

# --- minilake_database ---
resource "aws_glue_catalog_database" "traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database" {
  name        = "traffic_collision_minilake_analytics_d0012_glue_data_ca_6d7ec0a"
  description = "Glue Data Catalog database"
}

resource "aws_glue_catalog_table" "traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database_collision_table" {
  database_name = aws_glue_catalog_database.traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database.name

  name = "collision"

  table_type = "EXTERNAL_TABLE"

  parameters = {EXTERNAL = "TRUE"}

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id}/collision/"

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
      name = "timestamp"
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

resource "aws_glue_catalog_table" "traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database_party_table" {
  database_name = aws_glue_catalog_database.traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database.name

  name = "party"

  table_type = "EXTERNAL_TABLE"

  parameters = {EXTERNAL = "TRUE"}

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id}/party/"

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
      name = "party_type"
      type = "string"
    }

    columns {
      name = "name"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database_victim_table" {
  database_name = aws_glue_catalog_database.traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database.name

  name = "victim"

  table_type = "EXTERNAL_TABLE"

  parameters = {EXTERNAL = "TRUE"}

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id}/victim/"

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
      name = "injury_severity"
      type = "string"
    }

    columns {
      name = "age"
      type = "int"
    }
  }
}

resource "aws_glue_catalog_table" "traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database_case_table" {
  database_name = aws_glue_catalog_database.traffic_collision_minilake_analytics_d0012_glue_data_catalog_minilake_database.name

  name = "case"

  table_type = "EXTERNAL_TABLE"

  parameters = {EXTERNAL = "TRUE"}

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_minilake_analytics_d0012_s3_minilake_3.id}/case/"

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
      name = "case_status"
      type = "string"
    }

    columns {
      name = "filed_date"
      type = "date"
    }
  }
}

# --- athena_workgroup ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "traffic_collision_minilake_analytics_d0012_athena_athena_workgroup_lg" {
  name              = "/aws/athena/traffic-collision-minilake-analytics-d0012-athena-athena-workgroup"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "traffic_collision_minilake_analytics_d0012_athena_athena_workgroup" {
  name = "traffic-collision-minilake-analytics-d0012-athena-athena-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://traffic-collision-minilake-analytics-d0012-athena-athena-workgroup-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "traffic_collision_minilake"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D0012"
    ManagedBy     = "aws-pipeline-engine"
  }
}
