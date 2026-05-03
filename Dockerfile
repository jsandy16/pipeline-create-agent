FROM python:3.12-slim

# Install system deps + Terraform
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip gnupg ca-certificates && \
    # Terraform
    curl -fsSL https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -o /tmp/tf.zip && \
    unzip /tmp/tf.zip -d /usr/local/bin && \
    rm /tmp/tf.zip && \
    # Clean up
    apt-get purge -y unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Runtime directories
RUN mkdir -p output input_architecture_dgm input_dgm input_dgm_archive

# Terraform plugin cache — pre-warm at build time so terraform init
# copies from local cache (~2s) instead of downloading (~2min).
# This prevents HTTP timeout on Render/similar platforms.
ENV TF_PLUGIN_CACHE_DIR=/tmp/.terraform_cache
RUN mkdir -p /tmp/.terraform_cache /tmp/_tf_warmup && \
    printf 'terraform {\n  required_providers {\n    aws = { source = "hashicorp/aws", version = "~> 5.0" }\n    archive = { source = "hashicorp/archive", version = "~> 2.0" }\n    time = { source = "hashicorp/time", version = "~> 0.9" }\n  }\n}\n' \
      > /tmp/_tf_warmup/main.tf && \
    cd /tmp/_tf_warmup && terraform init -backend=false -input=false && \
    rm -rf /tmp/_tf_warmup

EXPOSE 8080

# Use Render's PORT env var (falls back to 8080 for local dev)
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8080} --proxy-headers --forwarded-allow-ips '*' --ws-ping-interval 5 --ws-ping-timeout 10"]
