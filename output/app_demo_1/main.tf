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


# --- s3_1 ---
resource "aws_s3_bucket" "app_demo_1_engineering_cc001_s3_s3_1_1" {
  bucket        = "app-demo-1-engineering-cc001-s3-s3-1-1"
  force_destroy = true

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "app_demo_1_engineering_cc001_s3_s3_1_1_versioning" {
  bucket = aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_1_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_demo_1_engineering_cc001_s3_s3_1_1_sse" {
  bucket = aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_1_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "app_demo_1_engineering_cc001_s3_s3_1_1_invoke_app_demo_1_engineering_cc001_lambda_lambda_1" {
  statement_id  = "AllowS3-app_demo_1_engineering_cc001_s3_s3_1_1-app_demo_1_engineering_cc001_lambda_lambda_1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app_demo_1_engineering_cc001_lambda_lambda_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_1_1.arn
}

resource "aws_s3_bucket_notification" "app_demo_1_engineering_cc001_s3_s3_1_1_notification" {
  bucket = aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_1_1.id

  lambda_function {
    id                  = "app_demo_1_engineering_cc001_s3_s3_1_1_app_demo_1_engineering_cc001_lambda_lambda_1"
    lambda_function_arn = aws_lambda_function.app_demo_1_engineering_cc001_lambda_lambda_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.app_demo_1_engineering_cc001_s3_s3_1_1_invoke_app_demo_1_engineering_cc001_lambda_lambda_1]
}

# --- lambda_1 ---
data "archive_file" "app_demo_1_engineering_cc001_lambda_lambda_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/app_demo_1_engineering_cc001_lambda_lambda_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "app_demo_1_engineering_cc001_lambda_lambda_1_role" {
  name = "app-demo-1-engineering-cc001-lambda-lambda-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "app_demo_1_engineering_cc001_lambda_lambda_1_policy" {
  name = "app-demo-1-engineering-cc001-lambda-lambda-1-policy"
  role = aws_iam_role.app_demo_1_engineering_cc001_lambda_lambda_1_role.id

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
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics",
          "s3:PutObject",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "app_demo_1_engineering_cc001_lambda_lambda_1_lg" {
  name              = "/aws/lambda/app-demo-1-engineering-cc001-lambda-lambda-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "app_demo_1_engineering_cc001_lambda_lambda_1" {
  function_name    = "app-demo-1-engineering-cc001-lambda-lambda-1"
  role             = aws_iam_role.app_demo_1_engineering_cc001_lambda_lambda_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.app_demo_1_engineering_cc001_lambda_lambda_1_placeholder.output_path
  source_code_hash = data.archive_file.app_demo_1_engineering_cc001_lambda_lambda_1_placeholder.output_base64sha256

  environment {
    variables = {
      GLUE_1_CRAWLER_NAME = aws_glue_crawler.app_demo_1_engineering_cc001_glue_glue_1.name
      S3_2_BUCKET = aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_2_2.id
    }
  }

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.app_demo_1_engineering_cc001_lambda_lambda_1_lg]
}

# --- glue_1 ---
resource "aws_cloudwatch_log_group" "app_demo_1_engineering_cc001_glue_glue_1_lg" {
  name              = "/aws-glue/jobs/app-demo-1-engineering-cc001-glue-glue-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "app_demo_1_engineering_cc001_glue_glue_1_db" {
  name = "app_demo_1_engineering_cc001_glue_glue_1_db"

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "app_demo_1_engineering_cc001_glue_glue_1_role" {
  name = "app-demo-1-engineering-cc001-glue-glue-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "app_demo_1_engineering_cc001_glue_glue_1_policy" {
  name = "app-demo-1-engineering-cc001-glue-glue-1-policy"
  role = aws_iam_role.app_demo_1_engineering_cc001_glue_glue_1_role.id

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
          "glue:StartCrawler",
          "glue:GetCrawler",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_glue_crawler" "app_demo_1_engineering_cc001_glue_glue_1" {
  name          = "app-demo-1-engineering-cc001-glue-glue-1"
  database_name = aws_glue_catalog_database.app_demo_1_engineering_cc001_glue_glue_1_db.name
  role          = aws_iam_role.app_demo_1_engineering_cc001_glue_glue_1_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_2_2.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- athena_1 ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "app_demo_1_engineering_cc001_athena_athena_1_lg" {
  name              = "/aws/athena/app-demo-1-engineering-cc001-athena-athena-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "app_demo_1_engineering_cc001_athena_athena_1" {
  name = "app-demo-1-engineering-cc001-athena-athena-1"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://app-demo-1-engineering-cc001-s3-s3-2-2/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- s3_2 ---
resource "aws_s3_bucket" "app_demo_1_engineering_cc001_s3_s3_2_2" {
  bucket        = "app-demo-1-engineering-cc001-s3-s3-2-2"
  force_destroy = true

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "app_demo_1_engineering_cc001_s3_s3_2_2_versioning" {
  bucket = aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_2_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_demo_1_engineering_cc001_s3_s3_2_2_sse" {
  bucket = aws_s3_bucket.app_demo_1_engineering_cc001_s3_s3_2_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- sagemaker_1 ---
# ⚠️  WARNING: sagemaker is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_iam_role" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1_role" {
  name = "app-demo-1-engineering-cc001-sagemaker-sagemaker-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1_policy" {
  name = "app-demo-1-engineering-cc001-sagemaker-sagemaker-1-policy"
  role = aws_iam_role.app_demo_1_engineering_cc001_sagemaker_sagemaker_1_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1_sagemaker_full" {
  role       = aws_iam_role.app_demo_1_engineering_cc001_sagemaker_sagemaker_1_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Resolves the correct DLC image URI for this account + region.
# Supported repository_name values: sklearn, pytorch-inference,
# tensorflow-inference, xgboost, huggingface-pytorch-inference,
# mxnet-inference, pytorch-training, tensorflow-training, etc.
data "aws_sagemaker_prebuilt_ecr_image" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1_img" {
  repository_name = "sagemaker-scikit-learn"
  image_tag       = "1.2-1-cpu-py3"
}

resource "aws_cloudwatch_log_group" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1_lg" {
  name              = "/aws/sagemaker/Endpoints/app-demo-1-engineering-cc001-sagemaker-sagemaker-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sagemaker_model" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1_model" {
  name               = "app-demo-1-engineering-cc001-sagemaker-sagemaker-1-model"
  execution_role_arn = aws_iam_role.app_demo_1_engineering_cc001_sagemaker_sagemaker_1_role.arn

  primary_container {
    image          = data.aws_sagemaker_prebuilt_ecr_image.app_demo_1_engineering_cc001_sagemaker_sagemaker_1_img.registry_path
    model_data_url = "s3://placeholder-model-bucket/model.tar.gz"
  }

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sagemaker_endpoint_configuration" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1_cfg" {
  name = "app-demo-1-engineering-cc001-sagemaker-sagemaker-1-cfg"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.app_demo_1_engineering_cc001_sagemaker_sagemaker_1_model.name
    initial_instance_count = 1
    instance_type          = "ml.t2.medium"
    initial_variant_weight = 1
  }

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sagemaker_endpoint" "app_demo_1_engineering_cc001_sagemaker_sagemaker_1" {
  name                 = "app-demo-1-engineering-cc001-sagemaker-sagemaker-1"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.app_demo_1_engineering_cc001_sagemaker_sagemaker_1_cfg.name

  tags = {
    Pipeline      = "app_demo_1"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
