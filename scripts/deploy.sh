#!/bin/bash
set -e

# Whales Application Deployment Script for Cloud Run
# This script builds and deploys containerized applications to Google Cloud Run

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

# Check if required tools are installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker is not installed${NC}"
    exit 1
fi

# Parse terraform outputs
echo -e "${YELLOW}Reading Terraform configuration...${NC}"
cd "$TERRAFORM_DIR"

PROJECT_ID=$(terraform output -raw gcp_project_id)
REGION=$(terraform output -raw gcp_region)
ENVIRONMENT=$(grep environment terraform.tfvars | cut -d'=' -f2 | tr -d ' "')

echo -e "${GREEN}Project: $PROJECT_ID${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo -e "${GREEN}Environment: $ENVIRONMENT${NC}"

# Backend Image
BACKEND_IMAGE="gcr.io/${PROJECT_ID}/${ENVIRONMENT}-backend-api"
FRONTEND_IMAGE="gcr.io/${PROJECT_ID}/${ENVIRONMENT}-frontend"

echo ""
echo -e "${YELLOW}Building and Pushing Backend Container...${NC}"

cd "$PROJECT_ROOT/backend"

# Build backend image
docker build -t "${BACKEND_IMAGE}:latest" .

# Push to Google Container Registry
docker push "${BACKEND_IMAGE}:latest"

echo -e "${GREEN}Backend image pushed: ${BACKEND_IMAGE}:latest${NC}"

echo ""
echo -e "${YELLOW}Building and Pushing Frontend Container...${NC}"

cd "$PROJECT_ROOT/frontend"

# Build frontend image
docker build -t "${FRONTEND_IMAGE}:latest" .

# Push to Google Container Registry
docker push "${FRONTEND_IMAGE}:latest"

echo -e "${GREEN}Frontend image pushed: ${FRONTEND_IMAGE}:latest${NC}"

# Update Terraform variables
echo ""
echo -e "${YELLOW}Updating Terraform with new image URLs...${NC}"

cd "$TERRAFORM_DIR"

# Update terraform.tfvars with new image URLs
cat >> terraform.tfvars << EOF

# Updated on $(date)
backend_image_url  = "${BACKEND_IMAGE}:latest"
frontend_image_url = "${FRONTEND_IMAGE}:latest"
EOF

# Apply Terraform to deploy Cloud Run services
echo -e "${YELLOW}Deploying to Cloud Run...${NC}"

terraform apply -var="backend_image_url=${BACKEND_IMAGE}:latest" \
                -var="frontend_image_url=${FRONTEND_IMAGE}:latest" \
                -auto-approve

# Get output URLs
echo ""
echo -e "${YELLOW}Retrieving deployment information...${NC}"

API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
BACKEND_URL=$(terraform output -raw backend_cloud_run_url)
FRONTEND_URL=$(terraform output -raw frontend_cloud_run_url)

echo ""
echo -e "${GREEN}Deployment Complete!${NC}"
echo "========================================"
echo -e "${GREEN}API Gateway:${NC}  $API_GATEWAY_URL"
echo -e "${GREEN}Backend URL:${NC}  $BACKEND_URL"
echo -e "${GREEN}Frontend URL:${NC} $FRONTEND_URL"
echo "========================================"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Visit the frontend URL to access the application"
echo "2. Monitor logs: gcloud logging read"
echo "3. Check Cloud Run services: gcloud run services list --region=${REGION}"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "# View backend logs:"
echo "gcloud run logs read ${ENVIRONMENT}-api --region=${REGION}"
echo ""
echo "# View frontend logs:"
echo "gcloud run logs read ${ENVIRONMENT}-frontend --region=${REGION}"
echo ""
echo "# Scale up backend concurrency:"
echo "gcloud run services update ${ENVIRONMENT}-api --region=${REGION} --concurrency=100"

