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


# --- order_bucket ---
resource "aws_s3_bucket" "order_processing_pipeline_c01_operations_s3_order_bucket_7f88" {
  bucket        = "order-processing-pipeline-c01-operations-s3-order-bucket-e589"
  force_destroy = true

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "order_processing_pipeline_c01_operations_s3_order_bucket_7f88_versioning" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_order_bucket_7f88.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "order_processing_pipeline_c01_operations_s3_order_bucket_7f88_sse" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_order_bucket_7f88.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "order_processing_pipeline_c01_operations_s3_order_bucket_7f88_invoke_order_processing_pipeline_c01_operations_lambda_process_order_1c37" {
  statement_id  = "AllowS3-order_processing_pipeline_c01_operations_s3_order_bucket_7f88-order_processing_pipe-10c427f4"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_process_order_1c37.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_order_bucket_7f88.arn
}

resource "time_sleep" "order_processing_pipeline_c01_operations_s3_order_bucket_7f88_iam_sleep" {
  depends_on      = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_order_bucket_7f88_invoke_order_processing_pipeline_c01_operations_lambda_process_order_1c37]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "order_processing_pipeline_c01_operations_s3_order_bucket_7f88_notification" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_order_bucket_7f88.id

  lambda_function {
    id                  = "order_processing_pipeline_c01_operations_s3_order_bucket_7f88_order_processing_pipeline_c01_operations_lambda_process_order_1c37"
    lambda_function_arn = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_process_order_1c37.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_order_bucket_7f88_invoke_order_processing_pipeline_c01_operations_lambda_process_order_1c37, time_sleep.order_processing_pipeline_c01_operations_s3_order_bucket_7f88_iam_sleep]
}

# --- invoice_bucket ---
resource "aws_s3_bucket" "order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0" {
  bucket        = "order-processing-pipeline-c01-operations-s3-invoice-bucket-e904"
  force_destroy = true

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_versioning" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_sse" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_invoke_order_processing_pipeline_c01_operations_lambda_process_invoice_5f70" {
  statement_id  = "AllowS3-order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0-order_processing_pi-8dd57ae2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_process_invoice_5f70.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0.arn
}

resource "time_sleep" "order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_iam_sleep" {
  depends_on      = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_invoke_order_processing_pipeline_c01_operations_lambda_process_invoice_5f70]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_notification" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0.id

  lambda_function {
    id                  = "order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_order_processing_pipeline_c01_operations_lambda_process_invoice_5f70"
    lambda_function_arn = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_process_invoice_5f70.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_invoke_order_processing_pipeline_c01_operations_lambda_process_invoice_5f70, time_sleep.order_processing_pipeline_c01_operations_s3_invoice_bucket_aed0_iam_sleep]
}

# --- product_bucket ---
resource "aws_s3_bucket" "order_processing_pipeline_c01_operations_s3_product_bucket_2d03" {
  bucket        = "order-processing-pipeline-c01-operations-s3-product-bucket-02eb"
  force_destroy = true

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "order_processing_pipeline_c01_operations_s3_product_bucket_2d03_versioning" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_product_bucket_2d03.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "order_processing_pipeline_c01_operations_s3_product_bucket_2d03_sse" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_product_bucket_2d03.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "order_processing_pipeline_c01_operations_s3_product_bucket_2d03_invoke_order_processing_pipeline_c01_operations_lambda_process_product_c130" {
  statement_id  = "AllowS3-order_processing_pipeline_c01_operations_s3_product_bucket_2d03-order_processing_pi-b81b4d24"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_process_product_c130.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_product_bucket_2d03.arn
}

resource "time_sleep" "order_processing_pipeline_c01_operations_s3_product_bucket_2d03_iam_sleep" {
  depends_on      = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_product_bucket_2d03_invoke_order_processing_pipeline_c01_operations_lambda_process_product_c130]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "order_processing_pipeline_c01_operations_s3_product_bucket_2d03_notification" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_product_bucket_2d03.id

  lambda_function {
    id                  = "order_processing_pipeline_c01_operations_s3_product_bucket_2d03_order_processing_pipeline_c01_operations_lambda_process_product_c130"
    lambda_function_arn = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_process_product_c130.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_product_bucket_2d03_invoke_order_processing_pipeline_c01_operations_lambda_process_product_c130, time_sleep.order_processing_pipeline_c01_operations_s3_product_bucket_2d03_iam_sleep]
}

# --- staging_bucket ---
resource "aws_s3_bucket" "order_processing_pipeline_c01_operations_s3_staging_bucket_3b56" {
  bucket        = "order-processing-pipeline-c01-operations-s3-staging-bucket-0d9a"
  force_destroy = true

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_versioning" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_sse" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_invoke_order_processing_pipeline_c01_operations_lambda_refine_data_b055" {
  statement_id  = "AllowS3-order_processing_pipeline_c01_operations_s3_staging_bucket_3b56-order_processing_pi-c7574b2c"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_refine_data_b055.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56.arn
}

resource "time_sleep" "order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_iam_sleep" {
  depends_on      = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_invoke_order_processing_pipeline_c01_operations_lambda_refine_data_b055]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_notification" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56.id

  lambda_function {
    id                  = "order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_order_processing_pipeline_c01_operations_lambda_refine_data_b055"
    lambda_function_arn = aws_lambda_function.order_processing_pipeline_c01_operations_lambda_refine_data_b055.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_invoke_order_processing_pipeline_c01_operations_lambda_refine_data_b055, time_sleep.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56_iam_sleep]
}

# --- curated_bucket ---
resource "aws_s3_bucket" "order_processing_pipeline_c01_operations_s3_curated_bucket_673f" {
  bucket        = "order-processing-pipeline-c01-operations-s3-curated-bucket-7515"
  force_destroy = true

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "order_processing_pipeline_c01_operations_s3_curated_bucket_673f_versioning" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_curated_bucket_673f.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "order_processing_pipeline_c01_operations_s3_curated_bucket_673f_sse" {
  bucket = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_curated_bucket_673f.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- process_order ---
data "archive_file" "order_processing_pipeline_c01_operations_lambda_process_order_1c37_placeholder" {
  type        = "zip"
  output_path = "${path.module}/order_processing_pipeline_c01_operations_lambda_process_order_1c37_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "order_processing_pipeline_c01_operations_lambda_process_order_1c37_role" {
  name = "order-processing-pipeline-c01-operations-lambda-pro-198b2db-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "order_processing_pipeline_c01_operations_lambda_process_order_1c37_policy" {
  name = "order-processing-pipeline-c01-operations-lambda-p-198b2db-policy"
  role = aws_iam_role.order_processing_pipeline_c01_operations_lambda_process_order_1c37_role.id

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

resource "aws_cloudwatch_log_group" "order_processing_pipeline_c01_operations_lambda_process_order_1c37_lg" {
  name              = "/aws/lambda/order-processing-pipeline-c01-operations-lambda-process-c82ea3d"
  retention_in_days = 7

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "order_processing_pipeline_c01_operations_lambda_process_order_1c37" {
  function_name    = "order-processing-pipeline-c01-operations-lambda-process-c82ea3d"
  role             = aws_iam_role.order_processing_pipeline_c01_operations_lambda_process_order_1c37_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 60
  filename         = data.archive_file.order_processing_pipeline_c01_operations_lambda_process_order_1c37_placeholder.output_path
  source_code_hash = data.archive_file.order_processing_pipeline_c01_operations_lambda_process_order_1c37_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56.id
    }
  }

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.order_processing_pipeline_c01_operations_lambda_process_order_1c37_lg]
}

# --- process_invoice ---
data "archive_file" "order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_placeholder" {
  type        = "zip"
  output_path = "${path.module}/order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_role" {
  name = "order-processing-pipeline-c01-operations-lambda-pro-40497b3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_policy" {
  name = "order-processing-pipeline-c01-operations-lambda-p-40497b3-policy"
  role = aws_iam_role.order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_role.id

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

resource "aws_cloudwatch_log_group" "order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_lg" {
  name              = "/aws/lambda/order-processing-pipeline-c01-operations-lambda-process-78776ca"
  retention_in_days = 7

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "order_processing_pipeline_c01_operations_lambda_process_invoice_5f70" {
  function_name    = "order-processing-pipeline-c01-operations-lambda-process-78776ca"
  role             = aws_iam_role.order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 60
  filename         = data.archive_file.order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_placeholder.output_path
  source_code_hash = data.archive_file.order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56.id
    }
  }

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.order_processing_pipeline_c01_operations_lambda_process_invoice_5f70_lg]
}

# --- process_product ---
data "archive_file" "order_processing_pipeline_c01_operations_lambda_process_product_c130_placeholder" {
  type        = "zip"
  output_path = "${path.module}/order_processing_pipeline_c01_operations_lambda_process_product_c130_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "order_processing_pipeline_c01_operations_lambda_process_product_c130_role" {
  name = "order-processing-pipeline-c01-operations-lambda-pro-e3674bf-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "order_processing_pipeline_c01_operations_lambda_process_product_c130_policy" {
  name = "order-processing-pipeline-c01-operations-lambda-p-e3674bf-policy"
  role = aws_iam_role.order_processing_pipeline_c01_operations_lambda_process_product_c130_role.id

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

resource "aws_cloudwatch_log_group" "order_processing_pipeline_c01_operations_lambda_process_product_c130_lg" {
  name              = "/aws/lambda/order-processing-pipeline-c01-operations-lambda-process-525464a"
  retention_in_days = 7

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "order_processing_pipeline_c01_operations_lambda_process_product_c130" {
  function_name    = "order-processing-pipeline-c01-operations-lambda-process-525464a"
  role             = aws_iam_role.order_processing_pipeline_c01_operations_lambda_process_product_c130_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 60
  filename         = data.archive_file.order_processing_pipeline_c01_operations_lambda_process_product_c130_placeholder.output_path
  source_code_hash = data.archive_file.order_processing_pipeline_c01_operations_lambda_process_product_c130_placeholder.output_base64sha256

  environment {
    variables = {
      STAGING_BUCKET_BUCKET = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_staging_bucket_3b56.id
    }
  }

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.order_processing_pipeline_c01_operations_lambda_process_product_c130_lg]
}

# --- refine_data ---
data "archive_file" "order_processing_pipeline_c01_operations_lambda_refine_data_b055_placeholder" {
  type        = "zip"
  output_path = "${path.module}/order_processing_pipeline_c01_operations_lambda_refine_data_b055_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "order_processing_pipeline_c01_operations_lambda_refine_data_b055_role" {
  name = "order-processing-pipeline-c01-operations-lambda-ref-71cf7cb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "order_processing_pipeline_c01_operations_lambda_refine_data_b055_policy" {
  name = "order-processing-pipeline-c01-operations-lambda-r-71cf7cb-policy"
  role = aws_iam_role.order_processing_pipeline_c01_operations_lambda_refine_data_b055_role.id

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

resource "aws_cloudwatch_log_group" "order_processing_pipeline_c01_operations_lambda_refine_data_b055_lg" {
  name              = "/aws/lambda/order-processing-pipeline-c01-operations-lambda-refine-data-f0c3"
  retention_in_days = 7

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "order_processing_pipeline_c01_operations_lambda_refine_data_b055" {
  function_name    = "order-processing-pipeline-c01-operations-lambda-refine-data-f0c3"
  role             = aws_iam_role.order_processing_pipeline_c01_operations_lambda_refine_data_b055_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 120
  filename         = data.archive_file.order_processing_pipeline_c01_operations_lambda_refine_data_b055_placeholder.output_path
  source_code_hash = data.archive_file.order_processing_pipeline_c01_operations_lambda_refine_data_b055_placeholder.output_base64sha256

  environment {
    variables = {
      CURATED_BUCKET_BUCKET = aws_s3_bucket.order_processing_pipeline_c01_operations_s3_curated_bucket_673f.id
    }
  }

  tags = {
    Pipeline      = "order_processing_pipeline"
    BusinessUnit  = "operations"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.order_processing_pipeline_c01_operations_lambda_refine_data_b055_lg]
}

# --- order_processing_database ---
resource "aws_glue_catalog_database" "order_processing_pipeline_c01_operations_glue_data_catalog_order_processing_database_3a77" {
  name        = "order_processing_pipeline_c01_operations_glue_data_cata_cd34fcc"
  description = "Glue Data Catalog database"
}

# --- order_table ---
resource "aws_glue_catalog_database" "order_processing_pipeline_c01_operations_glue_data_catalog_order_table_6850" {
  name        = "order_processing_pipeline_c01_operations_glue_data_cata_5ddb06b"
  description = "Glue Data Catalog database"
}

# --- invoice_table ---
resource "aws_glue_catalog_database" "order_processing_pipeline_c01_operations_glue_data_catalog_invoice_table_76c9" {
  name        = "order_processing_pipeline_c01_operations_glue_data_cata_20e443f"
  description = "Glue Data Catalog database"
}

# --- product_table ---
resource "aws_glue_catalog_database" "order_processing_pipeline_c01_operations_glue_data_catalog_product_table_b57f" {
  name        = "order_processing_pipeline_c01_operations_glue_data_cata_a23ef22"
  description = "Glue Data Catalog database"
}
