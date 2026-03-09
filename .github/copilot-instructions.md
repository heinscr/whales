# Whales Project - Copilot Custom Instructions

## Project Overview
Serverless full-stack web application with GCP infrastructure using Terraform, JavaScript frontend (Node.js/Express), Python backend (Flask on Cloud Run), Firestore for data, and API Gateway for API management.

## Architecture
- **Infrastructure**: Terraform for GCP serverless setup
- **Frontend**: JavaScript (Node.js/Express) on Cloud Run
- **Backend**: Python (Flask) on Cloud Run
- **Database**: Google Firestore (NoSQL)
- **Storage**: Google Cloud Storage (uploads & static assets)
- **API Layer**: Google Cloud API Gateway
- **Deployment**: Automated scripts for container builds and Cloud Run deployment

## Scaffolding Checklist

- [x] Verify copilot-instructions.md file created
- [x] Scaffold the Project Structure
- [x] Create Terraform Configuration
- [x] Setup Frontend (JavaScript)
- [x] Setup Backend (Python)
- [x] Create Deployment Script
- [x] Create Documentation (README)
- [x] Project Compilation Check
- [x] Final Verification

## Key Requirements
- ✅ Terraform provisioning for GCP serverless components (Cloud Run, API Gateway, Firestore, Storage)
- ✅ Deployment script that reads Terraform outputs and builds/pushes containers
- ✅ JavaScript frontend (Node.js/Express with Cloud Run)
- ✅ Python backend (Flask with Cloud Run)
- ✅ Firestore NoSQL database integration
- ✅ Cloud Storage buckets for uploads
- ✅ Environment configuration management
- ✅ Automated deployment pipeline
- ✅ Cost-optimized serverless architecture
- ✅ Comprehensive documentation

## Cost-Optimized Setup
- **Cloud Run**: Scales to zero, pay-per-execution model
- **Firestore**: Free tier friendly (50K reads/day, 20K writes/day)
- **API Gateway**: Single entry point with rate limiting
- **Estimated monthly cost (dev)**: < $1 USD

## Next Steps for User
1. Configure GCP project in `terraform/terraform.tfvars`
2. Run `bash scripts/infrastructure.sh` to create infrastructure
3. Run `bash scripts/deploy.sh` to build and deploy containers
4. Access frontend URL from deployment output
5. Monitor logs via `gcloud run logs read <service>`

