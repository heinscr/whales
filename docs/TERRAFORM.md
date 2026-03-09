# Infrastructure Guide

## Overview

This project uses Terraform to manage a serverless Google Cloud Platform infrastructure. The setup includes:

- **Cloud Run**: Manages backend API and frontend services
- **API Gateway**: Centralized API management and routing
- **Firestore**: NoSQL, serverless database
- **Cloud Storage**: File uploads and static assets
- **Service Accounts**: IAM roles and permissions

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│      API Gateway (public URL)           │
│  Routes all API requests to Cloud Run   │
└────────────────┬────────────────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
┌───▼──────┐          ┌──────▼────┐
│ Cloud    │          │ Cloud Run  │
│ Run      │          │  Backend   │
│Frontend  │          │  API       │
└──────────┘          └──────┬─────┘
                             │
                   ┌─────────┼────────────┐
                   │         │            │
            ┌──────▼──┐  ┌──▼────┐  ┌─────▼───┐
            │Firestore│  │Storage│  │Logging  │
            │Database │  │Bucket │  │Monitor. │
            └─────────┘  └───────┘  └─────────┘
```

## Terraform Files

### main.tf
Defines all GCP resources:
- Cloud Run services
- API Gateway configuration
- Firestore database
- Cloud Storage buckets
- Service accounts and IAM

### variables.tf
Input variables:
- `gcp_project_id`: Your GCP project
- `gcp_region`: Deployment region
- `environment`: dev/staging/production
- `backend_image_url`: Container image for backend
- `frontend_image_url`: Container image for frontend

### outputs.tf
Exports important values:
- API Gateway URL
- Cloud Run service URLs
- Firestore database name
- Storage bucket names

### openapi.yaml
API specification for API Gateway:
- Endpoint definitions
- Request/response schemas
- Backend routing

## Setup

### Copy Configuration

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### Edit terraform.tfvars

```hcl
gcp_project_id    = "your-gcp-project-id"
gcp_region        = "us-central1"
environment       = "dev"
# Leave these empty initially, update after building containers
backend_image_url  = ""
frontend_image_url = ""
```

### Create Terraform State Bucket

```bash
gsutil mb gs://whales-terraform-state-${PROJECT_ID}
```

## Commands

### Initialize Terraform

```bash
terraform init
```

This:
- Downloads provider plugins
- Initializes backend (GCS bucket)
- Prepares working directory

### Validate Configuration

```bash
terraform validate
```

Checks syntax and logic of `.tf` files.

### Plan Changes

```bash
terraform plan -out=tfplan
```

Shows what Terraform will do without making changes.

### Apply Changes

```bash
terraform apply tfplan
```

Creates/updates resources in GCP.

### Destroy Resources

```bash
terraform destroy
```

**Warning**: Deletes all managed resources!

To destroy selectively:
```bash
terraform destroy -target=google_cloud_run_service.backend_api
```

### View State

```bash
terraform show
```

Shows current resource configuration.

### Refresh State

```bash
terraform refresh
```

Updates state from actual GCP resources (useful if manual changes were made).

## GCP Resources

### Cloud Run Services

**Backend API**
- Service: `dev-api` (or `staging/prod`)
- Image: `gcr.io/PROJECT-ID/backend-api:latest`
- Port: 8080
- Memory: Configurable (default: 512Mi)
- CPU: Configurable (default: 1)
- Concurrency: 80 (default)
- Auto-scales to zero when idle

**Frontend**
- Service: `dev-frontend`
- Image: `gcr.io/PROJECT-ID/frontend:latest`
- Port: 3000
- Memory: Configurable (default: 512Mi)
- Concurrency: 80 (default)

### API Gateway

- **API ID**: `dev-api`
- **Gateway ID**: `dev-gateway`
- **OpenAPI Spec**: Defines all endpoints
- **Backend**: Routes to Cloud Run backend service

Configuration:
```yaml
# openapi.yaml
paths:
  /api/health:
    get:
      x-google-backend:
        address: https://backend-cloud-run-url
        protocol: h2
  /api/items:
    get:
      # ...
    post:
      # ...
```

### Firestore Database

- **Type**: Cloud Firestore (native)
- **Location**: Same as GCP region
- **Concurrency**: Optimistic
- **Auto-scaling**: Enabled

Collections:
- `items`: Main data collection
  - Document fields: `title`, `value`, `createdAt`, `updatedAt`

### Cloud Storage Buckets

**Uploads Bucket**
- Stores user-uploaded files
- Naming: `PROJECT-ID-ENVIRONMENT-uploads`
- Versioning: Disabled for dev, enabled for prod
- Uniform access control: Enabled

**Static Bucket**
- Stores static assets (future use)
- Naming: `PROJECT-ID-ENVIRONMENT-static`
- CDN: Can be enabled for faster access

### Service Accounts

**Backend Service Account**
- Name: `dev-backend-sa`
- Permissions:
  - Firestore user (read/write)
  - Storage object user (read/write)

IAM Bindings:
```hcl
roles/datastore.user      # Firestore access
roles/storage.objectUser  # Cloud Storage access
```

## Variables and Configuration

### Input Variables

```hcl
variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev/staging/production)"
  type        = string
}

variable "backend_image_url" {
  description = "Backend container image"
  type        = string
  default     = ""
}

variable "frontend_image_url" {
  description = "Frontend container image"
  type        = string
  default     = ""
}
```

### Output Values

```hcl
# API Gateway entry point
output "api_gateway_url"

# Direct Cloud Run URLs
output "backend_cloud_run_url"
output "frontend_cloud_run_url"

# Database and storage
output "firestore_database"
output "uploads_bucket_name"
output "static_bucket_name"

# Service account
output "backend_service_account_email"
```

Get outputs:
```bash
terraform output
terraform output -raw api_gateway_url
```

## Environments

### Development

```hcl
gcp_project_id = "my-project-dev"
gcp_region     = "us-central1"
environment    = "dev"
```

- Lower cost instances
- Shared resources
- Can destroy easily

### Staging

```hcl
gcp_project_id = "my-project-staging"
environment    = "staging"
```

- Production-like setup
- Testing ground
- More stable

### Production

```hcl
gcp_project_id = "my-project-prod"
environment    = "production"
```

- High availability
- Backup enabled
- Monitoring enabled
- Delete protection enabled

## Cost Optimization

### Cloud Run Costs

- **Compute**: $0.00002400 per vCPU-second
- **Requests**: $0.40 per million requests
- **Scales to zero**: No cost when idle

Optimize:
```hcl
# Use smaller memory allocation
memory = "256Mi"  # instead of 512Mi

# Reduce max concurrency if not needed
concurrency = 10  # instead of 80

# Use smaller CPU
cpu = "0.5"  # instead of 1
```

### Firestore Costs

- **Reads**: $0.06 per 100K
- **Writes**: $0.18 per 100K
- **Deletes**: $0.02 per 100K
- **Free tier**: 50K reads, 20K writes, 20K deletes daily

### Cloud Storage Costs

- **Storage**: $0.020 per GB/month
- **Requests**: Minimal charges
- **Free tier**: 5GB per month

### API Gateway Costs

- **Calls**: $3.50 per million calls

## Scaling

### Manual Scaling

Update `terraform.tfvars` and reapply:

```hcl
# For future: add variables for resource sizing
# Step 1: Add max_instances variable
# Step 2: Update Cloud Run resources
# Step 3: terraform apply
```

### Current Configuration

Cloud Run auto-scales based on:
- Request rate
- CPU usage
- Memory usage
- Concurrency

No manual scaling needed in most cases.

## Troubleshooting

### State Lock

If Terraform is stuck:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK-ID>
```

### Authentication Error

```bash
gcloud auth login
gcloud auth application-default login
terraform init
```

### Resource Already Exists

If resource exists but not in state:
```bash
# Import existing resource
terraform import <resource_type>.<resource_name> <resource_id>
```

Example:
```bash
terraform import google_cloud_run_service.backend_api backend-api
```

### API Not Enabled

Error: "Cloud Run API has not been used..."

Enable APIs:
```bash
gcloud services enable run.googleapis.com
gcloud services enable apigateway.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable storage.googleapis.com
```

### Permission Denied

Ensure your GCP user has:
- `roles/editor` or
- `roles/compute.admin`
- `roles/firestore.admin`
- `roles/storage.admin`

Check:
```bash
gcloud projects get-iam-policy PROJECT-ID
```

## Monitoring

### Terraform State

```bash
# View current state
terraform show

# Check specific resource
terraform state show google_cloud_run_service.backend_api
```

### GCP Resources

```bash
# List Cloud Run services
gcloud run services list

# List API Gateway APIs
gcloud api-gateway apis list

# List Firestore databases
gcloud firestore databases list

# List Cloud Storage buckets
gsutil ls
```

### Logs

```bash
# Cloud Run logs
gcloud run logs read backend-api

# Deployment logs
gcloud logging read "resource.type=cloud_run_revision"
```

## Migration Scenarios

### From VM-Based to Serverless

1. Create new Terraform config for serverless
2. Deploy parallel infrastructure
3. Test thoroughly
4. Switch DNS/routing
5. Decommission old VMs

### Between Regions

```bash
# Update gcp_region in terraform.tfvars
terraform plan  # Review changes
terraform apply  # Execute migration
```

## Best Practices

1. **Use workspaces** for multiple environments
   ```bash
   terraform workspace new staging
   terraform workspace select staging
   ```

2. **Version control**
   - Commit `.tf` files
   - Do NOT commit `.tfstate` (use remote state)
   - Ignore `.tfvars` with secrets

3. **Code organization**
   - One resource per file (optional but readable)
   - Group related resources

4. **Security**
   - Use service accounts
   - Minimize IAM permissions
   - Enable audit logging

5. **Documentation**
   - Comment complex configurations
   - Document variable purposes
   - Keep README updated

## Additional Resources

- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [API Gateway Documentation](https://cloud.google.com/api-gateway/docs)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
- [Terraform Best Practices](https://cloud.google.com/architecture/best-practices-for-using-terraform)
