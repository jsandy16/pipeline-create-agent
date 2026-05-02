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


# --- raw_data_bucket ---
resource "aws_s3_bucket" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1" {
  bucket        = "traffic-collision-data-pipeline-analytics-d01-s3-raw-da-4f5e3ed"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_versioning" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_sse" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1" {
  statement_id  = "AllowS3-traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1-traffic_collisio-5dc3857b"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.arn
}

resource "aws_lambda_permission" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2" {
  statement_id  = "AllowS3-traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1-traffic_collisio-383ea227"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.arn
}

resource "aws_lambda_permission" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3" {
  statement_id  = "AllowS3-traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1-traffic_collisio-63b5d933"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.arn
}

resource "aws_lambda_permission" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4" {
  statement_id  = "AllowS3-traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1-traffic_collisio-f4d6d679"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.arn
}

resource "aws_s3_bucket_notification" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_notification" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.id

  lambda_function {
    id                  = "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1"
    filter_prefix       = "collision_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2"
    filter_prefix       = "party_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3"
    filter_prefix       = "victim_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4"
    filter_prefix       = "case_raw/"
    lambda_function_arn = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1, aws_lambda_permission.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2, aws_lambda_permission.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3, aws_lambda_permission.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4]
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_collision_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.id

  key = "collision_raw/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_party_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.id

  key = "party_raw/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_victim_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.id

  key = "victim_raw/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1_case_raw_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_raw_data_bucket_1.id

  key = "case_raw/"

  content_type = "application/x-directory"
}

# --- collision_processor ---
data "archive_file" "traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3_client = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        # Copy to staging with collision prefix\n        destination_key = f\"collision/{source_key.split('/')[-1]}\"\n        \n        s3_client.copy_object(\n            CopySource={'Bucket': source_bucket, 'Key': source_key},\n            Bucket=staging_bucket,\n            Key=destination_key\n        )\n        \n        print(f\"Copied {source_key} to staging: {destination_key}\")\n    \n    return {\n        'statusCode': 200,\n        'body': json.dumps('Collision data processed successfully')\n    }\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_role" {
  name = "traffic-collision-data-pipeline-analytics-d01-lambd-4f597f2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_policy" {
  name = "traffic-collision-data-pipeline-analytics-d01-lam-4f597f2-policy"
  role = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_lg" {
  name              = "/aws/lambda/traffic-collision-data-pipeline-analytics-d01-lambda-col-1d1dbb5"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1" {
  function_name    = "traffic-collision-data-pipeline-analytics-d01-lambda-col-1d1dbb5"
  role             = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 60
  filename         = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_data_pipeline_analytics_d01_lambda_collision_processor_1_lg]
}

# --- party_processor ---
data "archive_file" "traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3_client = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        # Copy to staging with party prefix\n        destination_key = f\"party/{source_key.split('/')[-1]}\"\n        \n        s3_client.copy_object(\n            CopySource={'Bucket': source_bucket, 'Key': source_key},\n            Bucket=staging_bucket,\n            Key=destination_key\n        )\n        \n        print(f\"Copied {source_key} to staging: {destination_key}\")\n    \n    return {\n        'statusCode': 200,\n        'body': json.dumps('Party data processed successfully')\n    }\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_role" {
  name = "traffic-collision-data-pipeline-analytics-d01-lambd-0576b85-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_policy" {
  name = "traffic-collision-data-pipeline-analytics-d01-lam-0576b85-policy"
  role = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_lg" {
  name              = "/aws/lambda/traffic-collision-data-pipeline-analytics-d01-lambda-par-47fc142"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2" {
  function_name    = "traffic-collision-data-pipeline-analytics-d01-lambda-par-47fc142"
  role             = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 60
  filename         = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_data_pipeline_analytics_d01_lambda_party_processor_2_lg]
}

# --- victim_processor ---
data "archive_file" "traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3_client = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        # Copy to staging with victim prefix\n        destination_key = f\"victim/{source_key.split('/')[-1]}\"\n        \n        s3_client.copy_object(\n            CopySource={'Bucket': source_bucket, 'Key': source_key},\n            Bucket=staging_bucket,\n            Key=destination_key\n        )\n        \n        print(f\"Copied {source_key} to staging: {destination_key}\")\n    \n    return {\n        'statusCode': 200,\n        'body': json.dumps('Victim data processed successfully')\n    }\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_role" {
  name = "traffic-collision-data-pipeline-analytics-d01-lambd-af5f795-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_policy" {
  name = "traffic-collision-data-pipeline-analytics-d01-lam-af5f795-policy"
  role = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_lg" {
  name              = "/aws/lambda/traffic-collision-data-pipeline-analytics-d01-lambda-vic-b1366a4"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3" {
  function_name    = "traffic-collision-data-pipeline-analytics-d01-lambda-vic-b1366a4"
  role             = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 60
  filename         = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_data_pipeline_analytics_d01_lambda_victim_processor_3_lg]
}

# --- case_processor ---
data "archive_file" "traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3_client = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    \n    for record in event['Records']:\n        source_bucket = record['s3']['bucket']['name']\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        # Copy to staging with case prefix\n        destination_key = f\"case/{source_key.split('/')[-1]}\"\n        \n        s3_client.copy_object(\n            CopySource={'Bucket': source_bucket, 'Key': source_key},\n            Bucket=staging_bucket,\n            Key=destination_key\n        )\n        \n        print(f\"Copied {source_key} to staging: {destination_key}\")\n    \n    return {\n        'statusCode': 200,\n        'body': json.dumps('Case data processed successfully')\n    }\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_role" {
  name = "traffic-collision-data-pipeline-analytics-d01-lambd-eda9558-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_policy" {
  name = "traffic-collision-data-pipeline-analytics-d01-lam-eda9558-policy"
  role = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_lg" {
  name              = "/aws/lambda/traffic-collision-data-pipeline-analytics-d01-lambda-cas-df02056"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4" {
  function_name    = "traffic-collision-data-pipeline-analytics-d01-lambda-cas-df02056"
  role             = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 60
  filename         = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_data_pipeline_analytics_d01_lambda_case_processor_4_lg]
}

# --- staging_bucket ---
resource "aws_s3_bucket" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2" {
  bucket        = "traffic-collision-data-pipeline-analytics-d01-s3-stagin-ca1d341"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_versioning" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_sse" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5" {
  statement_id  = "AllowS3-traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2-traffic_collision-03631428"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.arn
}

resource "aws_s3_bucket_notification" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_notification" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id

  lambda_function {
    id                  = "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5"
    lambda_function_arn = aws_lambda_function.traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_invoke_traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5]
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_collision_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id

  key = "collision/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_party_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id

  key = "party/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_victim_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id

  key = "victim/"

  content_type = "application/x-directory"
}

resource "aws_s3_object" "traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2_case_prefix" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_staging_bucket_2.id

  key = "case/"

  content_type = "application/x-directory"
}

# --- refine_data ---
data "archive_file" "traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_placeholder" {
  type        = "zip"
  output_path = "${path.module}/traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_placeholder.zip"
  source {
    content  = "import json\nimport boto3\nimport os\nfrom urllib.parse import unquote_plus\n\ns3_client = boto3.client('s3')\n\ndef handler(event, context):\n    staging_bucket = os.environ['STAGING_BUCKET_BUCKET']\n    minilake_bucket = os.environ['MINILAKE_BUCKET']\n    \n    for record in event['Records']:\n        source_key = unquote_plus(record['s3']['object']['key'])\n        \n        # Determine dataset type from prefix\n        if source_key.startswith('collision/'):\n            dataset_type = 'collision'\n        elif source_key.startswith('party/'):\n            dataset_type = 'party'\n        elif source_key.startswith('victim/'):\n            dataset_type = 'victim'\n        elif source_key.startswith('case/'):\n            dataset_type = 'case'\n        else:\n            print(f\"Unknown prefix for {source_key}\")\n            continue\n        \n        # Copy refined data to minilake with same structure\n        destination_key = f\"{dataset_type}/{source_key.split('/')[-1]}\"\n        \n        s3_client.copy_object(\n            CopySource={'Bucket': staging_bucket, 'Key': source_key},\n            Bucket=minilake_bucket,\n            Key=destination_key\n        )\n        \n        print(f\"Refined {source_key} to minilake: {destination_key}\")\n    \n    return {\n        'statusCode': 200,\n        'body': json.dumps('Data refinement completed')\n    }\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_role" {
  name = "traffic-collision-data-pipeline-analytics-d01-lambd-dc24000-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_policy" {
  name = "traffic-collision-data-pipeline-analytics-d01-lam-dc24000-policy"
  role = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_role.id

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

resource "aws_cloudwatch_log_group" "traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_lg" {
  name              = "/aws/lambda/traffic-collision-data-pipeline-analytics-d01-lambda-ref-d8a0478"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5" {
  function_name    = "traffic-collision-data-pipeline-analytics-d01-lambda-ref-d8a0478"
  role             = aws_iam_role.traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_placeholder.output_path
  source_code_hash = data.archive_file.traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_placeholder.output_base64sha256

  environment {
    variables = {
      MINILAKE_BUCKET = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_minilake_3.id
    }
  }

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.traffic_collision_data_pipeline_analytics_d01_lambda_refine_data_5_lg]
}

# --- minilake ---
resource "aws_s3_bucket" "traffic_collision_data_pipeline_analytics_d01_s3_minilake_3" {
  bucket        = "traffic-collision-data-pipeline-analytics-d01-s3-minilake-3"
  force_destroy = true

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "traffic_collision_data_pipeline_analytics_d01_s3_minilake_3_versioning" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_minilake_3.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traffic_collision_data_pipeline_analytics_d01_s3_minilake_3_sse" {
  bucket = aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_minilake_3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- minilake_catalog ---
resource "aws_glue_catalog_database" "traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog" {
  name        = "traffic_collision_data_pipeline_analytics_d01_glue_data_34b5f3d"
  description = "Glue Data Catalog database"
}

resource "aws_glue_catalog_table" "traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog_collision_table" {
  database_name = aws_glue_catalog_database.traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog.name

  name = "collision"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_minilake_3.id}/collision/"

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
      name = "collision_date"
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

resource "aws_glue_catalog_table" "traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog_party_table" {
  database_name = aws_glue_catalog_database.traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog.name

  name = "party"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_minilake_3.id}/party/"

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
      name = "vehicle_year"
      type = "int"
    }
  }
}

resource "aws_glue_catalog_table" "traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog_victim_table" {
  database_name = aws_glue_catalog_database.traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog.name

  name = "victim"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_minilake_3.id}/victim/"

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
      name = "victim_role"
      type = "string"
    }

    columns {
      name = "injury_severity"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog_case_table" {
  database_name = aws_glue_catalog_database.traffic_collision_data_pipeline_analytics_d01_glue_data_catalog_minilake_catalog.name

  name = "case"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL = "TRUE"
  }

  storage_descriptor {
    location = "s3://${aws_s3_bucket.traffic_collision_data_pipeline_analytics_d01_s3_minilake_3.id}/case/"

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
      name = "filing_date"
      type = "date"
    }
  }
}

# --- query_layer ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "traffic_collision_data_pipeline_analytics_d01_athena_query_layer_lg" {
  name              = "/aws/athena/traffic-collision-data-pipeline-analytics-d01-athena-query-layer"
  retention_in_days = 7

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "traffic_collision_data_pipeline_analytics_d01_athena_query_layer" {
  name = "traffic-collision-data-pipeline-analytics-d01-athena-query-layer"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://traffic-collision-data-pipeline-analytics-d01-athena-query-layer-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "traffic_collision_data_pipeline"
    BusinessUnit  = "ANALYTICS"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}
