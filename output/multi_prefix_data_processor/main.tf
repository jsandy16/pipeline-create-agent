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
resource "aws_s3_bucket" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971" {
  bucket        = "multi-prefix-data-processor-f01-eng-s3-raw-data-bucket-5b2c"
  force_destroy = true

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_versioning" {
  bucket = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_sse" {
  bucket = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c" {
  statement_id  = "AllowS3-multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971-multi_prefix_data_proce-04b62718"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971.arn
}

resource "aws_lambda_permission" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff" {
  statement_id  = "AllowS3-multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971-multi_prefix_data_proce-058fd73a"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971.arn
}

resource "aws_lambda_permission" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_products_processor_799c" {
  statement_id  = "AllowS3-multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971-multi_prefix_data_proce-8a75d189"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_products_processor_799c.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971.arn
}

resource "aws_lambda_permission" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5" {
  statement_id  = "AllowS3-multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971-multi_prefix_data_proce-2ecca4ff"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971.arn
}

resource "time_sleep" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_iam_sleep" {
  depends_on      = [aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c, aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff, aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_products_processor_799c, aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_notification" {
  bucket = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971.id

  lambda_function {
    id                  = "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c"
    filter_prefix       = "orders/"
    lambda_function_arn = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff"
    filter_prefix       = "customers/"
    lambda_function_arn = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_multi_prefix_data_processor_f01_eng_lambda_products_processor_799c"
    filter_prefix       = "products/"
    lambda_function_arn = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_products_processor_799c.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5"
    filter_prefix       = "inventory/"
    lambda_function_arn = aws_lambda_function.multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c, aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff, aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_products_processor_799c, aws_lambda_permission.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_invoke_multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5, time_sleep.multi_prefix_data_processor_f01_eng_s3_raw_data_bucket_5971_iam_sleep]
}

# --- orders_processor ---
data "archive_file" "multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_role" {
  name = "multi-prefix-data-processor-f01-eng-lambda-orders-p-0537084-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_policy" {
  name = "multi-prefix-data-processor-f01-eng-lambda-orders-0537084-policy"
  role = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_lg" {
  name              = "/aws/lambda/multi-prefix-data-processor-f01-eng-lambda-orders-processor-a164"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c" {
  function_name    = "multi-prefix-data-processor-f01-eng-lambda-orders-processor-a164"
  role             = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_data_processor_f01_eng_lambda_orders_processor_681c_lg]
}

# --- customers_processor ---
data "archive_file" "multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_role" {
  name = "multi-prefix-data-processor-f01-eng-lambda-customer-160c48b-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_policy" {
  name = "multi-prefix-data-processor-f01-eng-lambda-custom-160c48b-policy"
  role = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_lg" {
  name              = "/aws/lambda/multi-prefix-data-processor-f01-eng-lambda-customers-pro-a3538a3"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff" {
  function_name    = "multi-prefix-data-processor-f01-eng-lambda-customers-pro-a3538a3"
  role             = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_data_processor_f01_eng_lambda_customers_processor_ceff_lg]
}

# --- products_processor ---
data "archive_file" "multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_role" {
  name = "multi-prefix-data-processor-f01-eng-lambda-products-712179e-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_policy" {
  name = "multi-prefix-data-processor-f01-eng-lambda-produc-712179e-policy"
  role = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_lg" {
  name              = "/aws/lambda/multi-prefix-data-processor-f01-eng-lambda-products-proc-8a2a7aa"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_data_processor_f01_eng_lambda_products_processor_799c" {
  function_name    = "multi-prefix-data-processor-f01-eng-lambda-products-proc-8a2a7aa"
  role             = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_data_processor_f01_eng_lambda_products_processor_799c_lg]
}

# --- inventory_processor ---
data "archive_file" "multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_placeholder" {
  type        = "zip"
  output_path = "${path.module}/multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_role" {
  name = "multi-prefix-data-processor-f01-eng-lambda-inventor-85e9ae9-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_policy" {
  name = "multi-prefix-data-processor-f01-eng-lambda-invent-85e9ae9-policy"
  role = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_role.id

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

resource "aws_cloudwatch_log_group" "multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_lg" {
  name              = "/aws/lambda/multi-prefix-data-processor-f01-eng-lambda-inventory-pro-84cfc12"
  retention_in_days = 7

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5" {
  function_name    = "multi-prefix-data-processor-f01-eng-lambda-inventory-pro-84cfc12"
  role             = aws_iam_role.multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_placeholder.output_path
  source_code_hash = data.archive_file.multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_DATA_BUCKET_BUCKET = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739.id
    }
  }

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.multi_prefix_data_processor_f01_eng_lambda_inventory_processor_a3d5_lg]
}

# --- staging_data_bucket ---
resource "aws_s3_bucket" "multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739" {
  bucket        = "multi-prefix-data-processor-f01-eng-s3-staging-data-bucket-34a5"
  force_destroy = true

  tags = {
    Pipeline      = "multi_prefix_data_processor"
    BusinessUnit  = "eng"
    CostCenter    = "f01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739_versioning" {
  bucket = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739_sse" {
  bucket = aws_s3_bucket.multi_prefix_data_processor_f01_eng_s3_staging_data_bucket_9739.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
