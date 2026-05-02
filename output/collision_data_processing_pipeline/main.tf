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


# --- src_bucket ---
resource "aws_s3_bucket" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1" {
  bucket        = "collision-data-processing-pipeline-engineering-cc001-s3-cbb8af3"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_versioning" {
  bucket = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_sse" {
  bucket = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_lambda_permission" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1" {
  statement_id  = "AllowS3-collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1-collision_data-9ec038cf"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1.arn
}

resource "aws_lambda_permission" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2" {
  statement_id  = "AllowS3-collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1-collision_data-f62daa65"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1.arn
}

resource "aws_lambda_permission" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3" {
  statement_id  = "AllowS3-collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1-collision_data-70e6f67a"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1.arn
}

resource "aws_lambda_permission" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4" {
  statement_id  = "AllowS3-collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1-collision_data-b1747511"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1.arn
}

resource "aws_s3_bucket_notification" "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_notification" {
  bucket = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1.id

  lambda_function {
    id                  = "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1"
    filter_prefix       = "case/"
    lambda_function_arn = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2"
    filter_prefix       = "party/"
    lambda_function_arn = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3"
    filter_prefix       = "victim/"
    lambda_function_arn = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3.arn
    events              = ["s3:ObjectCreated:*"]
  }
  lambda_function {
    id                  = "collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4"
    filter_prefix       = "collision/"
    lambda_function_arn = aws_lambda_function.collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1, aws_lambda_permission.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2, aws_lambda_permission.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3, aws_lambda_permission.collision_data_processing_pipeline_engineering_cc001_s3_src_bucket_1_invoke_collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4]
}

# --- tgt_bucket ---
resource "aws_s3_bucket" "collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2" {
  bucket        = "collision-data-processing-pipeline-engineering-cc001-s3-366ab24"
  force_destroy = true

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_s3_bucket_versioning" "collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2_versioning" {
  bucket = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2_sse" {
  bucket = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- case_processor ---
data "archive_file" "collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_role" {
  name = "collision-data-processing-pipeline-engineering-cc00-47738ba-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_policy" {
  name = "collision-data-processing-pipeline-engineering-cc-47738ba-policy"
  role = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_lg" {
  name              = "/aws/lambda/collision-data-processing-pipeline-engineering-cc001-lam-ad57451"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1" {
  function_name    = "collision-data-processing-pipeline-engineering-cc001-lam-ad57451"
  role             = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_placeholder.output_base64sha256

  environment {
    variables = {
      TGT_BUCKET_BUCKET = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_processing_pipeline_engineering_cc001_lambda_case_processor_1_lg]
}

# --- party_processor ---
data "archive_file" "collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_role" {
  name = "collision-data-processing-pipeline-engineering-cc00-8fb88bb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_policy" {
  name = "collision-data-processing-pipeline-engineering-cc-8fb88bb-policy"
  role = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_lg" {
  name              = "/aws/lambda/collision-data-processing-pipeline-engineering-cc001-lam-30625e9"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2" {
  function_name    = "collision-data-processing-pipeline-engineering-cc001-lam-30625e9"
  role             = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_placeholder.output_base64sha256

  environment {
    variables = {
      TGT_BUCKET_BUCKET = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_processing_pipeline_engineering_cc001_lambda_party_processor_2_lg]
}

# --- victim_processor ---
data "archive_file" "collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_role" {
  name = "collision-data-processing-pipeline-engineering-cc00-f2badfd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_policy" {
  name = "collision-data-processing-pipeline-engineering-cc-f2badfd-policy"
  role = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_lg" {
  name              = "/aws/lambda/collision-data-processing-pipeline-engineering-cc001-lam-cdf1b1b"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3" {
  function_name    = "collision-data-processing-pipeline-engineering-cc001-lam-cdf1b1b"
  role             = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_placeholder.output_base64sha256

  environment {
    variables = {
      TGT_BUCKET_BUCKET = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_processing_pipeline_engineering_cc001_lambda_victim_processor_3_lg]
}

# --- collision_processor ---
data "archive_file" "collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_placeholder" {
  type        = "zip"
  output_path = "${path.module}/collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {\"statusCode\": 200}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_role" {
  name = "collision-data-processing-pipeline-engineering-cc00-e51a3c7-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_iam_role_policy" "collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_policy" {
  name = "collision-data-processing-pipeline-engineering-cc-e51a3c7-policy"
  role = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_role.id

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

resource "aws_cloudwatch_log_group" "collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_lg" {
  name              = "/aws/lambda/collision-data-processing-pipeline-engineering-cc001-lam-a3bf961"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_lambda_function" "collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4" {
  function_name    = "collision-data-processing-pipeline-engineering-cc001-lam-a3bf961"
  role             = aws_iam_role.collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_role.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  memory_size      = 512
  timeout          = 300
  filename         = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_placeholder.output_path
  source_code_hash = data.archive_file.collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_placeholder.output_base64sha256

  environment {
    variables = {
      TGT_BUCKET_BUCKET = aws_s3_bucket.collision_data_processing_pipeline_engineering_cc001_s3_tgt_bucket_2.id
    }
  }

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }

  depends_on = [aws_cloudwatch_log_group.collision_data_processing_pipeline_engineering_cc001_lambda_collision_processor_4_lg]
}

# --- collision_analysis_database ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_collision_analysis_database_1" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_648200b"
  description = "Glue Data Catalog database"
}

# --- collision_analysis_staging_database ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_collision_analysis_staging_database_2" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_c1da729"
  description = "Glue Data Catalog database"
}

# --- case_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_case_table_3" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_719c299"
  description = "Glue Data Catalog database"
}

# --- party_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_party_table_4" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_2993f38"
  description = "Glue Data Catalog database"
}

# --- victim_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_victim_table_5" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_1494986"
  description = "Glue Data Catalog database"
}

# --- collision_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_collision_table_6" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_998f77e"
  description = "Glue Data Catalog database"
}

# --- case_staging_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_case_staging_table_7" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_dbad692"
  description = "Glue Data Catalog database"
}

# --- party_staging_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_party_staging_table_8" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_14cd24a"
  description = "Glue Data Catalog database"
}

# --- victim_staging_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_victim_staging_table_9" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_2c1e178"
  description = "Glue Data Catalog database"
}

# --- collision_staging_table ---
resource "aws_glue_catalog_database" "collision_data_processing_pipeline_engineering_cc001_glue_data_catalog_collision_staging_table_10" {
  name        = "collision_data_processing_pipeline_engineering_cc001_gl_26ff731"
  description = "Glue Data Catalog database"
}

# --- athena_workgroup ---
# ⚠️  WARNING: athena is NOT AWS Free Tier eligible.
# Costs will be incurred when this resource is deployed.
# Defaults are set to minimum viable size to reduce cost.

resource "aws_cloudwatch_log_group" "collision_data_processing_pipeline_engineering_cc001_athena_athena_workgroup_lg" {
  name              = "/aws/athena/collision-data-processing-pipeline-engineering-cc001-athena-athena-workgroup"
  retention_in_days = 7

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}

resource "aws_athena_workgroup" "collision_data_processing_pipeline_engineering_cc001_athena_athena_workgroup" {
  name = "collision-data-processing-pipeline-engineering-cc001-athena-athena-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://collision-data-processing-pipeline-engineering-cc001-athena-athena-workgroup-results/query-results/"
    }

    engine_version {
      selected_engine_version = "AUTO"
    }
  }

  tags = {
    Pipeline      = "collision_data_processing_pipeline"
    BusinessUnit  = "engineering"
    CostCenter    = "cc001"
    ManagedBy     = "aws-pipeline-engine"
  }
}
