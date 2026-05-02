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


# --- ecom_landing ---
resource "aws_s3_bucket" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde" {
  bucket        = "ecommerce-batch-data-pipeline-c01-rd-s3-ecom-landing-b1d6"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-e6fe0bc0"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-ef613cab"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-42877ed6"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-dfa5cadf"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-8f3da408"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-16ffd4b9"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-ea97f652"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-160d04ce"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-f2e58569"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "aws_lambda_permission" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9" {
  statement_id  = "AllowS3-ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde-ecommerce_batch_data_pipe-080bae02"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.arn
}

resource "time_sleep" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_iam_sleep" {
  depends_on      = [aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_notification" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde.id

  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d"
    filter_prefix       = "orders/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307"
    filter_prefix       = "order_items/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e"
    filter_prefix       = "customers/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e"
    filter_prefix       = "inventory/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32"
    filter_prefix       = "warehouses/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4"
    filter_prefix       = "stock_movements/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c"
    filter_prefix       = "procurements/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f"
    filter_prefix       = "suppliers/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f"
    filter_prefix       = "products/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9"
    filter_prefix       = "categories/"
    lambda_function_arn = aws_lambda_function.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f, aws_lambda_permission.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_invoke_ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9, time_sleep.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_landing_5bde_iam_sleep]
}

# --- ecom_raw ---
resource "aws_s3_bucket" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f" {
  bucket        = "ecommerce-batch-data-pipeline-c01-rd-s3-ecom-raw-fdee"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- ecom_curated ---
resource "aws_s3_bucket" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_curated_33b7" {
  bucket        = "ecommerce-batch-data-pipeline-c01-rd-s3-ecom-curated-adac"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_curated_33b7_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_curated_33b7.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_curated_33b7_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_curated_33b7.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- ecom_error ---
resource "aws_s3_bucket" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d" {
  bucket        = "ecommerce-batch-data-pipeline-c01-rd-s3-ecom-error-eab3"
  force_destroy = true

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d_versioning" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d_sse" {
  bucket = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- lambda_orders_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-6debbfd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-6debbfd-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_role.id

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
          "s3:DeleteObject",
          "states:StartExecution",
          "states:DescribeExecution"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-order-1dac4ad"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-order-1dac4ad"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
      ORCHESTRATE_ENRICHMENT_STATE_MACHINE_ARN = aws_sfn_state_machine.ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7.arn
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_orders_preprocess_f36d_lg]
}

# --- lambda_order_items_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-ae70495-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-ae70495-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-order-ec07cec"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-order-ec07cec"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_order_items_preprocess_a307_lg]
}

# --- lambda_customers_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-a5d62f5-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-a5d62f5-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-custo-4069a7e"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-custo-4069a7e"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_customers_preprocess_440e_lg]
}

# --- lambda_inventory_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-063fd22-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-063fd22-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-inven-c9f2ed7"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-inven-c9f2ed7"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_inventory_preprocess_7d6e_lg]
}

# --- lambda_warehouses_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-c0d86f5-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-c0d86f5-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-wareh-4f98649"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-wareh-4f98649"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_warehouses_preprocess_4c32_lg]
}

# --- lambda_stock_movements_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-e09d338-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-e09d338-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-stock-95407a1"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-stock-95407a1"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_stock_movements_preprocess_0bd4_lg]
}

# --- lambda_procurements_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-6a66deb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-6a66deb-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-procu-56dde8f"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-procu-56dde8f"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_procurements_preprocess_e87c_lg]
}

# --- lambda_suppliers_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-90e357e-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-90e357e-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-suppl-ca76e3e"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-suppl-ca76e3e"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_suppliers_preprocess_d32f_lg]
}

# --- lambda_products_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-dcb3dd5-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-dcb3dd5-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-produ-c8e79b2"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-produ-c8e79b2"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_products_preprocess_1f2f_lg]
}

# --- lambda_categories_preprocess ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-4249a8d-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-4249a8d-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_role.id

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

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-categ-a3e2e0e"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-categ-a3e2e0e"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_raw_994f.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_error_8f9d.id
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_categories_preprocess_cba9_lg]
}

# --- orchestrate_enrichment ---
resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-stepfunctions-a7f3470-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-stepfunction-a7f3470-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "states:StartExecution",
          "states:DescribeExecution",
          "lambda:InvokeFunction"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7_lg" {
  name              = "/aws/vendedlogs/states/ecommerce-batch-data-pipeline-c01-rd-stepfunctions-orchestrate-enrichment-6bc9"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sfn_state_machine" "ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7" {
  name     = "ecommerce-batch-data-pipeline-c01-rd-stepfunctions-orchestrate-enrichment-6bc9"
  role_arn = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7_role.arn
  type     = "STANDARD"

  definition = "{\"Comment\": \"State machine for orchestrate_enrichment\", \"StartAt\": \"Invoke_lambda_enrich_transform\", \"States\": {\"Invoke_lambda_enrich_transform\": {\"Type\": \"Task\", \"Resource\": \"arn:aws:states:::lambda:invoke\", \"Parameters\": {\"FunctionName.$\": \"$.function_name\", \"Payload.$\": \"$\"}, \"End\": true}}}"

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_stepfunctions_orchestrate_enrichment_e8c7_lg.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- lambda_enrich_transform ---
data "archive_file" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-d2e7aae-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambd-d2e7aae-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_role.id

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
          "s3:DeleteObject",
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_lg" {
  name              = "/aws/lambda/ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-enric-90419ab"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0" {
  function_name    = "ecommerce-batch-data-pipeline-c01-rd-lambda-lambda-enric-90419ab"
  role             = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 1024
  timeout          = 900
  filename         = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_placeholder.output_path
  source_code_hash = data.archive_file.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_CURATED_BUCKET = aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_curated_33b7.id
      GLUE_CRAWLER_CURATED_CRAWLER_NAME = aws_glue_crawler.ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef.name
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecommerce_batch_data_pipeline_c01_rd_lambda_lambda_enrich_transform_e4c0_lg]
}

# --- glue_crawler_curated ---
resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef_lg" {
  name              = "/aws-glue/jobs/ecommerce-batch-data-pipeline-c01-rd-glue-glue-crawler-curated-c203"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef_db" {
  name = "ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_c203_db"

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef_role" {
  name = "ecommerce-batch-data-pipeline-c01-rd-glue-glue-craw-a62201f-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef_policy" {
  name = "ecommerce-batch-data-pipeline-c01-rd-glue-glue-cr-a62201f-policy"
  role = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef_role.id

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

resource "aws_glue_crawler" "ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef" {
  name          = "ecommerce-batch-data-pipeline-c01-rd-glue-glue-crawler-curated-c203"
  database_name = aws_glue_catalog_database.ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef_db.name
  role          = aws_iam_role.ecommerce_batch_data_pipeline_c01_rd_glue_glue_crawler_curated_0bef_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.ecommerce_batch_data_pipeline_c01_rd_s3_ecom_curated_33b7.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- ecom_curated_db ---
resource "aws_glue_catalog_database" "ecommerce_batch_data_pipeline_c01_rd_glue_data_catalog_ecom_curated_db_da71" {
  name        = "ecommerce_batch_data_pipeline_c01_rd_glue_data_catalog_5f67336"
  description = "E-commerce curated data catalog with facts and dimensions"
}

# --- athena_ecom_analytics ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "ecommerce_batch_data_pipeline_c01_rd_athena_athena_ecom_analytics_095c_lg" {
  name              = "/aws/athena/ecommerce-batch-data-pipeline-c01-rd-athena-athena-ecom-analytics-6b3f"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "ecommerce_batch_data_pipeline_c01_rd_athena_athena_ecom_analytics_095c" {
  name = "ecommerce-batch-data-pipeline-c01-rd-athena-athena-ecom-analytics-6b3f"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://ecommerce-batch-data-pipeline-c01-rd-s3-ecom-curated-adac/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "ecommerce_batch_data_pipeline"
    BusinessUnit  = "rd"
    CostCenter    = "c01"
    ManagedBy     = "aws-pipeline-engine"
  }
}
