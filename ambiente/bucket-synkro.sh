#!/bin/bash
set -e

REGION="us-east-1"
BUCKETS=("synkro-raw-$(date +%Y%m%d%H%M%S)" "synkro-trusted-$(date +%Y%m%d%H%M%S)" "synkro-client-$(date +%Y%m%d%H%M%S)")

echo "===== CRIANDO BUCKETS S3 ====="

for BUCKET in "${BUCKETS[@]}"; do
    echo "Verificando bucket: $BUCKET"

    if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
        echo "Bucket $BUCKET já existe. Pulando criação."
    else
        echo "Bucket $BUCKET não existe. Criando..."
        aws s3api create-bucket \
            --bucket "$BUCKET" \
            --region "$REGION"
        echo "Bucket $BUCKET criado com sucesso."
    fi
done

echo "Todos os buckets foram verificados e criados se necessário."
