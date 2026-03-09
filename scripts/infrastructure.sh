#!/bin/bash
set -e

# Whales Infrastructure Setup Script for Cloud Run
# This script initializes GCP infrastructure using Terraform

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Whales Infrastructure Setup (Cloud Run + Firestore)${NC}"
echo "========================================"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform is not installed${NC}"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo -e "${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}Please edit terraform.tfvars with your GCP project details${NC}"
    exit 1
fi

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Format configuration
echo -e "${YELLOW}Formatting Terraform configuration...${NC}"
terraform fmt -recursive

# Validate configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan deployment
echo -e "${YELLOW}Planning infrastructure deployment...${NC}"
terraform plan -out=tfplan

# Ask for confirmation
echo ""
echo -e "${YELLOW}Review the planned changes above.${NC}"
read -p "Do you want to apply this Terraform plan? (yes/no): " -n 3 -r
echo

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Applying Terraform configuration...${NC}"
    terraform apply tfplan
    
    echo ""
    echo -e "${GREEN}Infrastructure setup complete!${NC}"
    echo "========================================"
    echo "Terraform Outputs:"
    terraform output
    echo "========================================"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Build and push container images: bash ../scripts/deploy.sh"
    echo "2. Monitor infrastructure: gcloud run services list"
    echo "3. View Firestore: https://console.cloud.google.com/firestore"
    echo ""
    
    # Cleanup
    rm -f tfplan
else
    echo "Deployment cancelled"
    rm -f tfplan
    exit 1
fi
