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
resource "aws_s3_bucket" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119" {
  bucket        = "ecom-batch-data-pipeline-d01-rd-s3-ecom-landing-e594"
  force_destroy = true

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_versioning" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_sse" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-d89a7e3a"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-42c7a669"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-17e7396f"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-456edada"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-751726a5"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-91986e93"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-94697779"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-75adf005"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-e58753e3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119-ecom_batch_data_pipeline_d01_r-84499706"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.arn
}

resource "time_sleep" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_iam_sleep" {
  depends_on      = [aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_notification" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119.id

  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d"
    filter_prefix       = "orders/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52"
    filter_prefix       = "order_items/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f"
    filter_prefix       = "customers/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f"
    filter_prefix       = "inventory/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642"
    filter_prefix       = "warehouses/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae"
    filter_prefix       = "stock_movements/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45"
    filter_prefix       = "procurements/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f"
    filter_prefix       = "suppliers/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010"
    filter_prefix       = "products/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848"
    filter_prefix       = "categories/"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010, aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848, time_sleep.ecom_batch_data_pipeline_d01_rd_s3_ecom_landing_3119_iam_sleep]
}

# --- ecom_raw ---
resource "aws_s3_bucket" "ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef" {
  bucket        = "ecom-batch-data-pipeline-d01-rd-s3-ecom-raw-ad8a"
  force_destroy = true

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_versioning" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_sse" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868" {
  statement_id  = "AllowS3-ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef-ecom_batch_data_pipeline_d01_rd_la-1330d40c"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.arn
}

resource "time_sleep" "ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_iam_sleep" {
  depends_on      = [aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868]
  create_duration = "15s"
}

resource "aws_s3_bucket_notification" "ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_notification" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id

  lambda_function {
    id                  = "ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868"
    lambda_function_arn = aws_lambda_function.ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_invoke_ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868, time_sleep.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef_iam_sleep]
}

# --- ecom_curated ---
resource "aws_s3_bucket" "ecom_batch_data_pipeline_d01_rd_s3_ecom_curated_7bdd" {
  bucket        = "ecom-batch-data-pipeline-d01-rd-s3-ecom-curated-ae42"
  force_destroy = true

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecom_batch_data_pipeline_d01_rd_s3_ecom_curated_7bdd_versioning" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_curated_7bdd.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecom_batch_data_pipeline_d01_rd_s3_ecom_curated_7bdd_sse" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_curated_7bdd.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- ecom_error ---
resource "aws_s3_bucket" "ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2" {
  bucket        = "ecom-batch-data-pipeline-d01-rd-s3-ecom-error-9b27"
  force_destroy = true

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2_versioning" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2_sse" {
  bucket = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- lambda_orders_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-order-07999ba-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-ord-07999ba-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-orders-pre-a319249"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-orders-pre-a319249"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_orders_preprocess_a96d_lg]
}

# --- lambda_order_items_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-order-4f2bae4-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-ord-4f2bae4-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-order-item-0c52548"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-order-item-0c52548"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_order_items_preprocess_bc52_lg]
}

# --- lambda_customers_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-custo-e0675b1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-cus-e0675b1-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-customers-76c6174"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-customers-76c6174"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_customers_preprocess_1c3f_lg]
}

# --- lambda_inventory_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-inven-28090d1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-inv-28090d1-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-inventory-46bb87c"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-inventory-46bb87c"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_inventory_preprocess_3e0f_lg]
}

# --- lambda_warehouses_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-wareh-5f008c6-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-war-5f008c6-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-warehouses-849ee6e"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-warehouses-849ee6e"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_warehouses_preprocess_7642_lg]
}

# --- lambda_stock_movements_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-stock-7215e41-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-sto-7215e41-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-stock-move-1d10ad3"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-stock-move-1d10ad3"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_stock_movements_preprocess_7aae_lg]
}

# --- lambda_procurements_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-procu-1173db1-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-pro-1173db1-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-procuremen-ba4c3f6"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-procuremen-ba4c3f6"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_procurements_preprocess_ba45_lg]
}

# --- lambda_suppliers_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-suppl-1ee7191-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-sup-1ee7191-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-suppliers-356194e"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-suppliers-356194e"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_suppliers_preprocess_3f7f_lg]
}

# --- lambda_products_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-produ-625531d-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-pro-625531d-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-products-p-797f186"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-products-p-797f186"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 256
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_products_preprocess_2010_lg]
}

# --- lambda_categories_preprocess ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-categ-a95b709-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-cat-a95b709-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-categories-61ae77a"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-categories-61ae77a"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 128
  timeout          = 300
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_RAW_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_raw_56ef.id
      ECOM_ERROR_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_error_54d2.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_categories_preprocess_8848_lg]
}

# --- ecom_orchestrator ---
resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_stepfunctions_ecom_orchestrator_92b6_role" {
  name = "ecom-batch-data-pipeline-d01-rd-stepfunctions-ecom-dc2636b-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_stepfunctions_ecom_orchestrator_92b6_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-stepfunctions-eco-dc2636b-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_stepfunctions_ecom_orchestrator_92b6_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_stepfunctions_ecom_orchestrator_92b6_lg" {
  name              = "/aws/vendedlogs/states/ecom-batch-data-pipeline-d01-rd-stepfunctions-ecom-orchestrator-91c3"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_sfn_state_machine" "ecom_batch_data_pipeline_d01_rd_stepfunctions_ecom_orchestrator_92b6" {
  name     = "ecom-batch-data-pipeline-d01-rd-stepfunctions-ecom-orchestrator-91c3"
  role_arn = aws_iam_role.ecom_batch_data_pipeline_d01_rd_stepfunctions_ecom_orchestrator_92b6_role.arn
  type     = "STANDARD"

  definition = "{\"Comment\": \"State machine for ecom_orchestrator\", \"StartAt\": \"Invoke_lambda_enrich_transform\", \"States\": {\"Invoke_lambda_enrich_transform\": {\"Type\": \"Task\", \"Resource\": \"arn:aws:states:::lambda:invoke\", \"Parameters\": {\"FunctionName.$\": \"$.function_name\", \"Payload.$\": \"$\"}, \"End\": true}}}"

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_stepfunctions_ecom_orchestrator_92b6_lg.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- lambda_enrich_transform ---
data "archive_file" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_placeholder" {
  type        = "zip"
  output_path = "${path.module}/ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_role" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-enric-61fac77-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-enr-61fac77-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_role.id

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

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_lg" {
  name              = "/aws/lambda/ecom-batch-data-pipeline-d01-rd-lambda-lambda-enrich-tra-eab65e1"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868" {
  function_name    = "ecom-batch-data-pipeline-d01-rd-lambda-lambda-enrich-tra-eab65e1"
  role             = aws_iam_role.ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 1024
  timeout          = 900
  filename         = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_placeholder.output_path
  source_code_hash = data.archive_file.ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_placeholder.output_base64sha256

  environment {
    variables = {
      ECOM_CURATED_BUCKET = aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_curated_7bdd.id
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.ecom_batch_data_pipeline_d01_rd_lambda_lambda_enrich_transform_f868_lg]
}

# --- glue_catalog_ecom ---
resource "aws_glue_catalog_database" "ecom_batch_data_pipeline_d01_rd_glue_data_catalog_glue_catalog_ecom_8777" {
  name        = "ecom_batch_data_pipeline_d01_rd_glue_data_catalog_glue_29ff649"
  description = "Glue Data Catalog database"
}

# --- glue_crawler_curated ---
resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10_lg" {
  name              = "/aws-glue/jobs/ecom-batch-data-pipeline-d01-rd-glue-glue-crawler-curated-8627"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_glue_catalog_database" "ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10_db" {
  name = "ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_8627_db"

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role" "ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10_role" {
  name = "ecom-batch-data-pipeline-d01-rd-glue-glue-crawler-c-f1e4577-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10_policy" {
  name = "ecom-batch-data-pipeline-d01-rd-glue-glue-crawler-f1e4577-policy"
  role = aws_iam_role.ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10_role.id

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

resource "aws_glue_crawler" "ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10" {
  name          = "ecom-batch-data-pipeline-d01-rd-glue-glue-crawler-curated-8627"
  database_name = aws_glue_catalog_database.ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10_db.name
  role          = aws_iam_role.ecom_batch_data_pipeline_d01_rd_glue_glue_crawler_curated_3f10_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.ecom_batch_data_pipeline_d01_rd_s3_ecom_curated_7bdd.id}/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

# --- athena_ecom_analytics ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "ecom_batch_data_pipeline_d01_rd_athena_athena_ecom_analytics_ee07_lg" {
  name              = "/aws/athena/ecom-batch-data-pipeline-d01-rd-athena-athena-ecom-analytics-ccfa"
  retention_in_days = 7

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "ecom_batch_data_pipeline_d01_rd_athena_athena_ecom_analytics_ee07" {
  name = "ecom-batch-data-pipeline-d01-rd-athena-athena-ecom-analytics-ccfa"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://ecom-batch-data-pipeline-d01-rd-s3-ecom-curated-ae42/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "ecom_batch_data_pipeline"
    BusinessUnit  = "RD"
    CostCenter    = "D01"
    ManagedBy     = "aws-pipeline-engine"
  }
}
