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


# --- ecom_landing_bucket ---
resource "aws_s3_bucket" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9" {
  bucket        = "ecommerce-batch-pipeline-c001-rd-s3-ecom-landing-bucket-4caa"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-6eb081b9"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-ff509e9a"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-b3c2ff1d"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-ea114be5"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-3d7a1748"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-1f557b00"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-de11894a"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-83d97352"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-f4700e1b"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "aws_lambda_permission" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af" {
  statement_id  = "AllowS3-ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9-ecommerce_batch_pipeli-9859e074"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.arn
}

resource "time_sleep" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_iam_sleep" {
  depends_on      = [aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_notification" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9.id

  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8"
    filter_prefix       = "orders/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d"
    filter_prefix       = "order_items/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5"
    filter_prefix       = "customers/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970"
    filter_prefix       = "inventory/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5"
    filter_prefix       = "warehouses/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06"
    filter_prefix       = "stock_movements/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141"
    filter_prefix       = "procurements/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437"
    filter_prefix       = "suppliers/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1"
    filter_prefix       = "products/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af"
    filter_prefix       = "categories/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1, aws_lambda_permission.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_invoke_ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af, time_sleep.ecommerce_batch_pipeline_c001_rd_s3_ecom_landing_bucket_53b9_iam_sleep]
}

# --- lambda_orders_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-orde-732b852-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-or-732b852-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-orders-pr-3a54123"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-orders-pr-3a54123"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_orders_preprocess_63b8_lg]
}

# --- lambda_order_items_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-orde-913cb94-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-or-913cb94-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-order-ite-ff87516"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-order-ite-ff87516"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_order_items_preprocess_fe6d_lg]
}

# --- lambda_customers_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-cust-985a00a-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-cu-985a00a-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-customers-9a39c37"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-customers-9a39c37"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_customers_preprocess_60b5_lg]
}

# --- lambda_inventory_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-inve-aeb9568-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-in-aeb9568-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-inventory-f5db087"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-inventory-f5db087"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_inventory_preprocess_9970_lg]
}

# --- lambda_warehouses_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-ware-d9cb91e-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-wa-d9cb91e-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-warehouse-e507d7b"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-warehouse-e507d7b"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_warehouses_preprocess_86f5_lg]
}

# --- lambda_stock_movements_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-stoc-a85f028-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-st-a85f028-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-stock-mov-330051b"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-stock-mov-330051b"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_stock_movements_preprocess_5e06_lg]
}

# --- lambda_procurements_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-proc-d841b0c-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-pr-d841b0c-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-procureme-2fdba10"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-procureme-2fdba10"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_procurements_preprocess_a141_lg]
}

# --- lambda_suppliers_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-supp-32e00fe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-su-32e00fe-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-suppliers-c4c34b3"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-suppliers-c4c34b3"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_suppliers_preprocess_0437_lg]
}

# --- lambda_products_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-prod-8bd3e0b-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-pr-8bd3e0b-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-products-4114ada"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-products-4114ada"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_products_preprocess_b4f1_lg]
}

# --- lambda_categories_preprocess ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-cate-a61fc7d-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-ca-a61fc7d-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-categorie-b8c5d2d"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-categorie-b8c5d2d"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_categories_preprocess_86af_lg]
}

# --- ecom_raw_bucket ---
resource "aws_s3_bucket" "ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3" {
  bucket        = "ecommerce-batch-pipeline-c001-rd-s3-ecom-raw-bucket-0729"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_raw_bucket_9bb3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- ecom_orchestrator ---
resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_stepfunctions_ecom_orchestrator_abd7_role" {
  name = "ecommerce-batch-pipeline-c001-rd-stepfunctions-ecom-dfb5507-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_stepfunctions_ecom_orchestrator_abd7_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-stepfunctions-ec-dfb5507-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_stepfunctions_ecom_orchestrator_abd7_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "lambda:InvokeFunction"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_stepfunctions_ecom_orchestrator_abd7_lg" {
  name              = "/aws/vendedlogs/states/ecommerce-batch-pipeline-c001-rd-stepfunctions-ecom-orchestrator-a493"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sfn_state_machine" "ecommerce_batch_pipeline_c001_rd_stepfunctions_ecom_orchestrator_abd7" {
  name     = "ecommerce-batch-pipeline-c001-rd-stepfunctions-ecom-orchestrator-a493"
  role_arn = aws_iam_role.ecommerce_batch_pipeline_c001_rd_stepfunctions_ecom_orchestrator_abd7_role.arn
  type     = "STANDARD"

  definition = "{\"Comment\": \"State machine for ecom_orchestrator\", \"StartAt\": \"Invoke_lambda_enrich_transform\", \"States\": {\"Invoke_lambda_enrich_transform\": {\"Type\": \"Task\", \"Resource\": \"arn:aws:states:::lambda:invoke\", \"Parameters\": {\"FunctionName.$\": \"$.function_name\", \"Payload.$\": \"$\"}, \"End\": true}}}"

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_stepfunctions_ecom_orchestrator_abd7_lg.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- lambda_enrich_transform ---
data "archive_file" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_role" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-enri-d5edf2b-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-en-d5edf2b-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_lg" {
  name              = "/aws/lambda/ecommerce-batch-pipeline-c001-rd-lambda-lambda-enrich-tr-87b3658"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe" {
  function_name    = "ecommerce-batch-pipeline-c001-rd-lambda-lambda-enrich-tr-87b3658"
  role             = aws_iam_role.ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 2048
  timeout          = 900
  filename         = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_CURATED_BUCKET_BUCKET = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_curated_bucket_cf07.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_pipeline_c001_rd_lambda_lambda_enrich_transform_ecfe_lg]
}

# --- ecom_curated_bucket ---
resource "aws_s3_bucket" "ecommerce_batch_pipeline_c001_rd_s3_ecom_curated_bucket_cf07" {
  bucket        = "ecommerce-batch-pipeline-c001-rd-s3-ecom-curated-bucket-8820"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_pipeline_c001_rd_s3_ecom_curated_bucket_cf07_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_curated_bucket_cf07.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_pipeline_c001_rd_s3_ecom_curated_bucket_cf07_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_curated_bucket_cf07.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- ecom_curated_crawler ---
resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582_lg" {
  name              = "/aws-glue/jobs/ecommerce-batch-pipeline-c001-rd-glue-ecom-curated-crawler-7ddd"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582_db" {
  name = "ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_7ddd_db"

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582_role" {
  name = "ecommerce-batch-pipeline-c001-rd-glue-ecom-curated-93cf4ec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582_policy" {
  name = "ecommerce-batch-pipeline-c001-rd-glue-ecom-curate-93cf4ec-policy"
  role = aws_iam_role.ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582_role.id

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
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_glue_crawler" "ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582" {
  name          = "ecommerce-batch-pipeline-c001-rd-glue-ecom-curated-crawler-7ddd"
  database_name = aws_glue_catalog_database.ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582_db.name
  role          = aws_iam_role.ecommerce_batch_pipeline_c001_rd_glue_ecom_curated_crawler_c582_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_curated_bucket_cf07.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- ecom_curated_database ---
resource "aws_glue_catalog_database" "ecommerce_batch_pipeline_c001_rd_glue_data_catalog_ecom_curated_database_76ae" {
  name        = "ecommerce_batch_pipeline_c001_rd_glue_data_catalog_ecom_80ebca4"
  description = "Glue Data Catalog database"
}

# --- athena_query_engine ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "ecommerce_batch_pipeline_c001_rd_athena_athena_query_engine_205c_lg" {
  name              = "/aws/athena/ecommerce-batch-pipeline-c001-rd-athena-athena-query-engine-cdce"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "ecommerce_batch_pipeline_c001_rd_athena_athena_query_engine_205c" {
  name = "ecommerce-batch-pipeline-c001-rd-athena-athena-query-engine-cdce"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://ecommerce-batch-pipeline-c001-rd-athena-athena-query-engine-cdce-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- ecom_error_bucket ---
resource "aws_s3_bucket" "ecommerce_batch_pipeline_c001_rd_s3_ecom_error_bucket_7ded" {
  bucket        = "ecommerce-batch-pipeline-c001-rd-s3-ecom-error-bucket-5c08"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_pipeline_c001_rd_s3_ecom_error_bucket_7ded_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_error_bucket_7ded.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_pipeline_c001_rd_s3_ecom_error_bucket_7ded_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_pipeline_c001_rd_s3_ecom_error_bucket_7ded.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
