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

# Terraform plugin cache
ENV TF_PLUGIN_CACHE_DIR=/tmp/.terraform_cache
RUN mkdir -p /tmp/.terraform_cache

EXPOSE 8080

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
