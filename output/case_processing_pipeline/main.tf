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
resource "aws_s3_bucket" "case_processing_pipeline_engineering_cc001_s3_src_1" {
  bucket        = "case-processing-pipeline-engineering-cc001-s3-src-1"
  force_destroy = true

  tags = {
    Pipeline      = "case_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "case_processing_pipeline_engineering_cc001_s3_src_1_versioning" {
  bucket = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_src_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "case_processing_pipeline_engineering_cc001_s3_src_1_sse" {
  bucket = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_src_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "case_processing_pipeline_engineering_cc001_s3_src_1_invoke_case_processing_pipeline_engineering_cc001_lambda_case_processor" {
  statement_id  = "AllowS3-case_processing_pipeline_engineering_cc001_s3_src_1-case_processing_pipeline_engine-60975472"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.case_processing_pipeline_engineering_cc001_lambda_case_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_src_1.arn
}

resource "aws_s3_bucket_notification" "case_processing_pipeline_engineering_cc001_s3_src_1_notification" {
  bucket = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_src_1.id

  lambda_function {
    id                  = "case_processing_pipeline_engineering_cc001_s3_src_1_case_processing_pipeline_engineering_cc001_lambda_case_processor"
    filter_prefix       = "case/"
    lambda_function_arn = aws_lambda_function.case_processing_pipeline_engineering_cc001_lambda_case_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.case_processing_pipeline_engineering_cc001_s3_src_1_invoke_case_processing_pipeline_engineering_cc001_lambda_case_processor]
}

resource "aws_s3_object" "case_processing_pipeline_engineering_cc001_s3_src_1_case_prefix" {
  bucket = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_src_1.id

  key = "case/"

  content_type = "application/x-directory"
}

# --- tgt ---
resource "aws_s3_bucket" "case_processing_pipeline_engineering_cc001_s3_tgt_2" {
  bucket        = "case-processing-pipeline-engineering-cc001-s3-tgt-2"
  force_destroy = true

  tags = {
    Pipeline      = "case_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "case_processing_pipeline_engineering_cc001_s3_tgt_2_versioning" {
  bucket = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_tgt_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "case_processing_pipeline_engineering_cc001_s3_tgt_2_sse" {
  bucket = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_tgt_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "case_processing_pipeline_engineering_cc001_s3_tgt_2_case_stg_prefix" {
  bucket = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_tgt_2.id

  key = "case_stg/"

  content_type = "application/x-directory"
}

# --- case_processor ---
data "archive_file" "case_processing_pipeline_engineering_cc001_lambda_case_processor_placeholder" {
  type        = "zip"
  output_path = "${path.module}/case_processing_pipeline_engineering_cc001_lambda_case_processor_placeholder.zip"
  source {
    content  = "import boto3\nimport pandas as pd\nfrom io import StringIO\nfrom datetime import datetime\n\ns3_client = boto3.client('s3')\n\ndef handler(event, context):\n    print('Hello World')\n    \n    # Get bucket and key from event\n    bucket = event['Records'][0]['s3']['bucket']['name']\n    key = event['Records'][0]['s3']['object']['key']\n    \n    # Read CSV from S3\n    response = s3_client.get_object(Bucket=bucket, Key=key)\n    csv_content = response['Body'].read().decode('utf-8')\n    \n    # Load into pandas dataframe\n    df = pd.read_csv(StringIO(csv_content))\n    \n    # Add createdate column with today's date\n    df['createdate'] = datetime.now().strftime('%Y-%m-%d')\n    \n    # Write to target bucket\n    csv_buffer = StringIO()\n    df.to_csv(csv_buffer, index=False)\n    \n    target_key = key.replace('case/', 'case_stg/')\n    s3_client.put_object(\n        Bucket='tgt',\n        Key=target_key,\n        Body=csv_buffer.getvalue()\n    )\n    \n    return {'statusCode': 200, 'message': 'File processed successfully'}\n"
    filename = "index.py"
  }
}

resource "aws_iam_role" "case_processing_pipeline_engineering_cc001_lambda_case_processor_role" {
  name = "case-processing-pipeline-engineering-cc001-lambda-c-fd1d9bd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "case_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "case_processing_pipeline_engineering_cc001_lambda_case_processor_policy" {
  name = "case-processing-pipeline-engineering-cc001-lambda-fd1d9bd-policy"
  role = aws_iam_role.case_processing_pipeline_engineering_cc001_lambda_case_processor_role.id

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

resource "aws_cloudwatch_log_group" "case_processing_pipeline_engineering_cc001_lambda_case_processor_lg" {
  name              = "/aws/lambda/case-processing-pipeline-engineering-cc001-lambda-case-processor"
  retention_in_days = 7

  tags = {
    Pipeline      = "case_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "case_processing_pipeline_engineering_cc001_lambda_case_processor" {
  function_name    = "case-processing-pipeline-engineering-cc001-lambda-case-processor"
  role             = aws_iam_role.case_processing_pipeline_engineering_cc001_lambda_case_processor_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.case_processing_pipeline_engineering_cc001_lambda_case_processor_placeholder.output_path
  source_code_hash = data.archive_file.case_processing_pipeline_engineering_cc001_lambda_case_processor_placeholder.output_base64sha256

  environment {
    variables = {
      TGT_BUCKET = aws_s3_bucket.case_processing_pipeline_engineering_cc001_s3_tgt_2.id
    }
  }

  tags = {
    Pipeline      = "case_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.case_processing_pipeline_engineering_cc001_lambda_case_processor_lg]
}
