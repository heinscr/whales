#!/bin/bash
set -e

# Whales Application Deployment Script for Cloud Run
# This script deploys applications to Google Cloud Run using Cloud Run with Source

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Whales Application Deployment to Cloud Run${NC}"
echo "========================================"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    exit 1
fi

# Parse terraform outputs and configuration
echo -e "${YELLOW}Reading Terraform configuration...${NC}"
cd "$TERRAFORM_DIR"

PROJECT_ID=$(terraform output -raw gcp_project_id 2>/dev/null || grep '^gcp_project_id' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
REGION=$(terraform output -raw gcp_region 2>/dev/null || grep '^gcp_region' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
ENVIRONMENT=$(grep '^environment' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')

echo -e "${GREEN}Project: $PROJECT_ID${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo -e "${GREEN}Environment: $ENVIRONMENT${NC}"

echo ""
echo -e "${YELLOW}Deploying Backend API to Cloud Run...${NC}"

# Deploy backend using source code
cd "$PROJECT_ROOT/backend"
gcloud run deploy "${ENVIRONMENT}-api" \
  --source . \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --allow-unauthenticated \
  --set-env-vars="ENVIRONMENT=${ENVIRONMENT},GCP_PROJECT_ID=${PROJECT_ID},FIRESTORE_DATABASE=${ENVIRONMENT}-database,STORAGE_BUCKET=${PROJECT_ID}-${ENVIRONMENT}-uploads" \
  --memory 512Mi \
  --cpu 1 \
  --timeout 60s

echo -e "${GREEN}Backend API deployed${NC}"

# Get backend URL
BACKEND_URL=$(gcloud run services describe "${ENVIRONMENT}-api" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')
echo -e "${GREEN}Backend URL: $BACKEND_URL${NC}"

echo ""
echo -e "${YELLOW}Deploying Frontend to Cloud Run...${NC}"

# Deploy frontend using source code, pointing to backend
cd "$PROJECT_ROOT/frontend"
gcloud run deploy "${ENVIRONMENT}-frontend" \
  --source . \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --allow-unauthenticated \
  --set-env-vars="API_GATEWAY_URL=${BACKEND_URL}/api" \
  --memory 256Mi \
  --cpu 0.5 \
  --timeout 60s

echo -e "${GREEN}Frontend deployed${NC}"

# Get the deployed service URLs
echo ""
echo -e "${YELLOW}Retrieving service URLs...${NC}"

BACKEND_URL=$(gcloud run services describe "${ENVIRONMENT}-api" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')
FRONTEND_URL=$(gcloud run services describe "${ENVIRONMENT}-frontend" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')

echo ""
echo -e "${GREEN}Deployment Complete!${NC}"
echo "========================================"
echo -e "${GREEN}Frontend:${NC} $FRONTEND_URL"
echo -e "${GREEN}Backend:${NC} $BACKEND_URL"
echo "========================================"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Visit the frontend URL to access the application"
echo "2. The frontend will communicate with the backend service"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "# View backend logs:"
echo "gcloud run logs read ${ENVIRONMENT}-api --region=${REGION}"
echo ""
echo "# View frontend logs:"
echo "gcloud run logs read ${ENVIRONMENT}-frontend --region=${REGION}"
echo ""
echo "# List all Cloud Run services:"
echo "gcloud run services list --region=${REGION}"
echo ""
echo "# Scale up backend concurrency:"
echo "gcloud run services update ${ENVIRONMENT}-api --region=${REGION} --concurrency=100"

