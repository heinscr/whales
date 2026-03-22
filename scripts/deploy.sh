#!/bin/bash
set -e

# Whales Application Deployment Script for Cloud Run
# This script builds Docker images, pushes to GCR, and deploys to Cloud Run

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
WHALE_IMAGES_BUCKET="${PROJECT_ID}-${ENVIRONMENT}-whale-images"

echo -e "${GREEN}Project: $PROJECT_ID${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo -e "${GREEN}Environment: $ENVIRONMENT${NC}"
echo -e "${GREEN}Whale Images Bucket: $WHALE_IMAGES_BUCKET${NC}"

# ============ Build & Push Backend Image ============
echo ""
echo -e "${YELLOW}Building and pushing Backend Docker image...${NC}"
cd "$PROJECT_ROOT/backend"
gcloud builds submit \
  --tag "gcr.io/${PROJECT_ID}/whales-backend:${ENVIRONMENT}" \
  --project "${PROJECT_ID}"

BACKEND_IMAGE="gcr.io/${PROJECT_ID}/whales-backend:${ENVIRONMENT}"
echo -e "${GREEN}Backend image pushed: $BACKEND_IMAGE${NC}"

# Check if backend image exists in GCR
echo -e "${YELLOW}Verifying backend image exists in GCR...${NC}"
if ! gcloud container images list-tags "gcr.io/${PROJECT_ID}/whales-backend" --filter="tags:${ENVIRONMENT}" --format="get(tags)" | grep -q "${ENVIRONMENT}"; then
  echo -e "${RED}Error: Backend image $BACKEND_IMAGE not found in GCR. Build or push may have failed.${NC}"
  exit 1
fi
echo -e "${GREEN}Backend image $BACKEND_IMAGE verified in GCR.${NC}"

# ============ Build & Push Frontend Image ============
echo ""
echo -e "${YELLOW}Building and pushing Frontend Docker image...${NC}"
cd "$PROJECT_ROOT/frontend"
gcloud builds submit \
  --tag "gcr.io/${PROJECT_ID}/whales-frontend:${ENVIRONMENT}" \
  --project "${PROJECT_ID}"

FRONTEND_IMAGE="gcr.io/${PROJECT_ID}/whales-frontend:${ENVIRONMENT}"
echo -e "${GREEN}Frontend image pushed: $FRONTEND_IMAGE${NC}"

# ============ Deploy Backend to Cloud Run ============
echo ""
echo -e "${YELLOW}Deploying Backend API to Cloud Run...${NC}"
BACKEND_SA_EMAIL=$(terraform output -state="$TERRAFORM_DIR/terraform.tfstate" -raw backend_service_account_email 2>/dev/null)
gcloud run deploy "${ENVIRONMENT}-backend" \
  --image "${BACKEND_IMAGE}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --allow-unauthenticated \
  --service-account "${BACKEND_SA_EMAIL}" \
  --set-env-vars="ENVIRONMENT=${ENVIRONMENT},GCP_PROJECT_ID=${PROJECT_ID},FIRESTORE_DATABASE=(default),WHALE_IMAGES_BUCKET=${WHALE_IMAGES_BUCKET},STORAGE_BUCKET=${PROJECT_ID}-${ENVIRONMENT}-uploads,SIGNING_SERVICE_ACCOUNT=${BACKEND_SA_EMAIL}" \
  --memory 512Mi \
  --cpu 1 \
  --timeout 60s \
  --max-instances 100

echo -e "${GREEN}Backend API deployed${NC}"

# Get backend URL
BACKEND_URL=$(gcloud run services describe "${ENVIRONMENT}-backend" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')
echo -e "${GREEN}Backend URL: $BACKEND_URL${NC}"

# ============ Deploy Frontend to Cloud Run ============
echo ""
echo -e "${YELLOW}Deploying Frontend to Cloud Run...${NC}"
gcloud run deploy "${ENVIRONMENT}-frontend" \
  --image "${FRONTEND_IMAGE}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --allow-unauthenticated \
  --set-env-vars="API_GATEWAY_URL=${BACKEND_URL}/api,NODE_ENV=${ENVIRONMENT}" \
  --memory 256Mi \
  --cpu 0.5 \
  --timeout 60s \
  --max-instances 100

echo -e "${GREEN}Frontend deployed${NC}"

# Get the deployed service URLs
echo ""
echo -e "${YELLOW}Retrieving service URLs...${NC}"

BACKEND_URL=$(gcloud run services describe "${ENVIRONMENT}-backend" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')
FRONTEND_URL=$(gcloud run services describe "${ENVIRONMENT}-frontend" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')

# ============ Configure Service Account for Backend ============
echo ""
echo -e "${YELLOW}Configuring service account permissions...${NC}"
BACKEND_SA=$(gcloud run services describe "${ENVIRONMENT}-backend" --region="${REGION}" --project="${PROJECT_ID}" --format='value(spec.template.spec.serviceAccountName)')

# Grant Firestore access
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${BACKEND_SA}" \
  --role="roles/datastore.user" \
  --condition=None \
  2>/dev/null || echo "  (Firestore role may already be assigned)"

# Grant Cloud Storage access
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${BACKEND_SA}" \
  --role="roles/storage.objectUser" \
  --condition=None \
  2>/dev/null || echo "  (Storage role may already be assigned)"

echo -e "${GREEN}Service account configured${NC}"

# ============ Local Development Service Account Key ============
echo ""
echo -e "${YELLOW}Checking for local service account key (for local development)...${NC}"
LOCAL_KEY_DIR="$HOME/.config/whales"
LOCAL_KEY_PATH="$LOCAL_KEY_DIR/backend-service-account-key.json"
mkdir -p "$LOCAL_KEY_DIR"
if [ ! -f "$LOCAL_KEY_PATH" ]; then
  echo -e "${YELLOW}Downloading service account key for local development...${NC}"
  gcloud iam service-accounts keys create "$LOCAL_KEY_PATH" \
    --iam-account="$BACKEND_SA_EMAIL" \
    --project="$PROJECT_ID"
  echo -e "${GREEN}Key downloaded: $LOCAL_KEY_PATH${NC}"
else
  echo -e "${GREEN}Key already exists: $LOCAL_KEY_PATH${NC}"
fi
echo -e "${YELLOW}To run the backend locally with signed URL support, set:${NC}"
echo -e "export GOOGLE_APPLICATION_CREDENTIALS=\"$LOCAL_KEY_PATH\""
echo ""
# ============ Display Results ============
echo ""
echo -e "${GREEN}Deployment Complete!${NC}"
echo "========================================"
echo -e "${GREEN}Frontend:${NC} $FRONTEND_URL"
echo -e "${GREEN}Backend:${NC} $BACKEND_URL"
echo "========================================"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Visit the frontend URL to access the application:"
echo "   $FRONTEND_URL"
echo ""
echo "2. Test whale image upload:"
echo "   - Go to 'Upload Image' tab"
echo "   - Fill in metadata"
echo "   - Select an image and upload"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "# View backend logs:"
echo "gcloud run logs read ${ENVIRONMENT}-backend --region=${REGION} --limit=50"
echo ""
echo "# View frontend logs:"
echo "gcloud run logs read ${ENVIRONMENT}-frontend --region=${REGION} --limit=50"
echo ""
echo "# Stream backend logs (live):"
echo "gcloud alpha run logs read ${ENVIRONMENT}-backend --region=${REGION} --follow"
echo ""
echo "# List all Cloud Run services:"
echo "gcloud run services list --region=${REGION}"
echo ""
echo "# Scale up backend concurrency:"
echo "gcloud run services update ${ENVIRONMENT}-api --region=${REGION} --concurrency=100"

