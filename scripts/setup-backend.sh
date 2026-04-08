#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# setup-backend.sh
# Creates the S3 bucket + DynamoDB table required for Terraform remote state.
# Run this ONCE before the first `terraform init`.
#
# Usage:
#   chmod +x scripts/setup-backend.sh
#   ./scripts/setup-backend.sh
# -----------------------------------------------------------------------------

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
REGION="ap-south-1"
DYNAMODB_TABLE="terraform-state-lock"

# Bucket name uses AWS account ID to guarantee global uniqueness
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="simpletimeservice-tfstate-${ACCOUNT_ID}"

echo ""
echo "=== Terraform Remote State Setup ==="
echo "Region:         ${REGION}"
echo "Bucket:         ${BUCKET_NAME}"
echo "DynamoDB table: ${DYNAMODB_TABLE}"
echo ""

# ── S3 Bucket ─────────────────────────────────────────────────────────────────
echo "[1/5] Creating S3 bucket..."

# ap-south-1 requires LocationConstraint (us-east-1 does not — AWS quirk)
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}" \
  --no-cli-pager

echo "[2/5] Enabling versioning (keeps full history of state files)..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled \
  --no-cli-pager

echo "[3/5] Enabling server-side encryption (AES-256)..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }' \
  --no-cli-pager

echo "[4/5] Blocking all public access to the state bucket..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --no-cli-pager

# ── DynamoDB Table ────────────────────────────────────────────────────────────
echo "[5/5] Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name "${DYNAMODB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" \
  --no-cli-pager

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Done! Resources created successfully. ==="
echo ""
echo "Next step — open terraform/versions.tf and replace the backend block with:"
echo ""
echo "  backend \"s3\" {"
echo "    bucket         = \"${BUCKET_NAME}\""
echo "    key            = \"devops-challenge/terraform.tfstate\""
echo "    region         = \"${REGION}\""
echo "    dynamodb_table = \"${DYNAMODB_TABLE}\""
echo "    encrypt        = true"
echo "  }"
echo ""
echo "Then run:"
echo "  cd terraform/"
echo "  terraform init"
echo ""
