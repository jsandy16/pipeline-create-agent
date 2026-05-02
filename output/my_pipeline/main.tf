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


# --- lambda_1 ---
data "archive_file" "my_pipeline_engineering_cc001_lambda_lambda_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/my_pipeline_engineering_cc001_lambda_lambda_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "my_pipeline_engineering_cc001_lambda_lambda_1_role" {
  name = "my-pipeline-engineering-cc001-lambda-lambda-1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "my_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "my_pipeline_engineering_cc001_lambda_lambda_1_policy" {
  name = "my-pipeline-engineering-cc001-lambda-lambda-1-policy"
  role = aws_iam_role.my_pipeline_engineering_cc001_lambda_lambda_1_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "my_pipeline_engineering_cc001_lambda_lambda_1_lg" {
  name              = "/aws/lambda/my-pipeline-engineering-cc001-lambda-lambda-1"
  retention_in_days = 7

  tags = {
    Pipeline      = "my_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "my_pipeline_engineering_cc001_lambda_lambda_1" {
  function_name    = "my-pipeline-engineering-cc001-lambda-lambda-1"
  role             = aws_iam_role.my_pipeline_engineering_cc001_lambda_lambda_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.my_pipeline_engineering_cc001_lambda_lambda_1_placeholder.output_path
  source_code_hash = data.archive_file.my_pipeline_engineering_cc001_lambda_lambda_1_placeholder.output_base64sha256

  tags = {
    Pipeline      = "my_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.my_pipeline_engineering_cc001_lambda_lambda_1_lg]
}
