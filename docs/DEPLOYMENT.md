# Deployment Guide

## Overview

Deployment is a two-step process:

1. **Infrastructure Setup**: Provision GCP resources (Cloud Run, Firestore, API Gateway)
2. **Application Deployment**: Build containers and deploy to Cloud Run

## Prerequisites

### Required Tools

- `gcloud` CLI configured with GCP authentication
- `terraform` >= 1.0
- `docker` (for building container images)
- `git` (for pushing code)

### GCP Setup

1. Create a GCP project
2. Enable required APIs:
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable apigateway.googleapis.com
   gcloud services enable firestore.googleapis.com
   gcloud services enable storage.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   ```

3. Configure Docker authentication:
   ```bash
   gcloud auth configure-docker gcr.io
   ```

4. Create Terraform state bucket:
   ```bash
   gsutil mb gs://whales-terraform-state-$(gcloud config get-value project)
   ```

## Step 1: Infrastructure Setup

### Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
gcp_project_id = "your-gcp-project-id"
gcp_region     = "us-central1"
environment    = "dev"
```

### Deploy Infrastructure

```bash
bash scripts/infrastructure.sh
```

This will:
- Initialize Terraform
- Validate configuration
- Plan changes
- Create:
  - Firestore database
  - Cloud Storage buckets
  - Service accounts with IAM roles
  - Placeholder Cloud Run services
  - API Gateway configuration

### Verify Infrastructure

```bash
# List Cloud Run services
gcloud run services list --region=us-central1

# View Firestore database
gcloud firestore databases list

# View Cloud Storage buckets
gsutil ls

# Get API Gateway URL
terraform output api_gateway_url
```

## Step 2: Application Deployment

### Build Backend Container

```bash
# Authenticate Docker
gcloud auth configure-docker gcr.io

# Build image
cd backend
docker build -t gcr.io/PROJECT-ID/backend-api:latest .

# Push to Container Registry
docker push gcr.io/PROJECT-ID/backend-api:latest
```

### Build Frontend Container

```bash
cd frontend
docker build -t gcr.io/PROJECT-ID/frontend:latest .
docker push gcr.io/PROJECT-ID/frontend:latest
```

### Update Terraform with Image URLs

Edit `terraform/terraform.tfvars`:

```hcl
backend_image_url  = "gcr.io/PROJECT-ID/backend-api:latest"
frontend_image_url = "gcr.io/PROJECT-ID/frontend:latest"
```

### Deploy to Cloud Run

```bash
cd terraform
terraform apply
```

Or use the automated script (does all above):

```bash
bash scripts/deploy.sh
```

## Automated Deployment

The `deploy.sh` script handles the entire deployment:

```bash
bash scripts/deploy.sh
```

It will:
1. Build backend Docker image
2. Push backend to Container Registry
3. Build frontend Docker image
4. Push frontend to Container Registry
5. Update Terraform variables
6. Deploy to Cloud Run
7. Output URLs and next steps

### Example Output

```
Whales Application Deployment to Cloud Run
======================================
Project: my-project
Region: us-central1
Environment: dev

Building and Pushing Backend Container...
Backend image pushed: gcr.io/my-project/dev-backend-api:latest

Building and Pushing Frontend Container...
Frontend image pushed: gcr.io/my-project/dev-frontend:latest

Updating Terraform with new image URLs...
Deploying to Cloud Run...

Deployment Complete!
======================================
API Gateway:  https://dev-gateway-xxxxx.apigateway.us-central1.goog
Backend URL:  https://dev-api-xxxxx.a.run.app
Frontend URL: https://dev-frontend-xxxxx.a.run.app
======================================
```

## Access Your Application

After deployment, visit the **Frontend URL** shown above.

You should see:
- Frontend health status: ✅ Healthy
- API Gateway status: ✅ Healthy (if backend is running)
- List of items (initially empty)
- Option to create new items

## Cloud Run Configuration

### View Deployment Details

```bash
# List services
gcloud run services list --region=us-central1

# View specific service
gcloud run services describe backend-api --region=us-central1
```

### View Logs

```bash
# Backend logs
gcloud run logs read backend-api --region=us-central1 --limit=50

# Frontend logs
gcloud run logs read frontend --region=us-central1 --limit=50

# Follow logs
gcloud run logs read backend-api --region=us-central1 --follow
```

### Scaling Configuration

Memory allocation:

```bash
gcloud run services update backend-api \
  --memory=1Gi \
  --region=us-central1
```

CPU allocation:

```bash
gcloud run services update backend-api \
  --cpu=2 \
  --region=us-central1
```

Concurrency:

```bash
gcloud run services update backend-api \
  --concurrency=100 \
  --region=us-central1
```

Max instances:

```bash
gcloud run services update backend-api \
  --max-instances=10 \
  --region=us-central1
```

## Testing Deployment

### Frontend Access

Open the Frontend URL in your browser. You should see:
- Application title
- Health check showing frontend/API gateway status
- Option to view and create items

### API Testing

#### Health Check

```bash
curl https://<api-gateway>/api/health
```

Response:
```json
{
  "status": "healthy",
  "service": "backend-api",
  "environment": "dev",
  "timestamp": "2024-01-15T10:30:00"
}
```

#### List Items

```bash
curl https://<api-gateway>/api/items
```

#### Create Item

```bash
curl -X POST https://<api-gateway>/api/items \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Item","value":100}'
```

#### Delete Item

```bash
curl -X DELETE https://<api-gateway>/api/items/<item-id>
```

## Continuous Deployment (CI/CD)

### GitHub Actions Setup

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Setup Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
      
      - name: Configure Docker
        run: gcloud auth configure-docker gcr.io
      
      - name: Build and Push Backend
        run: |
          docker build -t gcr.io/${{ secrets.GCP_PROJECT }}/backend-api:latest backend/
          docker push gcr.io/${{ secrets.GCP_PROJECT }}/backend-api:latest
      
      - name: Build and Push Frontend
        run: |
          docker build -t gcr.io/${{ secrets.GCP_PROJECT }}/frontend:latest frontend/
          docker push gcr.io/${{ secrets.GCP_PROJECT }}/frontend:latest
      
      - name: Deploy with Terraform
        run: |
          cd terraform
          terraform init
          terraform apply -auto-approve \
            -var="backend_image_url=gcr.io/${{ secrets.GCP_PROJECT }}/backend-api:latest" \
            -var="frontend_image_url=gcr.io/${{ secrets.GCP_PROJECT }}/frontend:latest"
```

### GitHub Secrets Setup

Add to GitHub:

1. `GCP_PROJECT`: Your GCP project ID
2. `GCP_SA_KEY`: Service account JSON key (base64 encoded)

Get service account key:

```bash
gcloud iam service-accounts create github-actions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions@PROJECT_ID.iam.gserviceaccount.com

cat key.json | base64
# Copy output to GitHub secret GCP_SA_KEY
```

## Rollback

### To Previous Deployment

```bash
# View revision history
gcloud run services list-revisions <service> --region=us-central1

# Deploy previous image
gcloud run deploy <service> \
  --image=<previous-image-uri> \
  --region=us-central1

# Or use Terraform
git revert <commit-hash>
terraform apply
```

### To Previous Data

Firestore doesn't have built-in rollback. Options:

1. **Manual recovery**: Write custom scripts to restore data
2. **Periodic backups**: Use Cloud Firestore export
3. **Point-in-time recovery**: Implement application-level versioning

## Monitoring & Observability

### Cloud Run Metrics

View in [Google Cloud Console](https://console.cloud.google.com):

1. Navigation → Cloud Run
2. Select service
3. Click → Metrics tab

Metrics include:
- Request count
- Error rate
- Latency (p50, p95, p99)
- Memory usage
- Instances

### Logs

```bash
# Stream logs in real-time
gcloud run logs read backend-api --region=us-central1 --follow

# Filter by severity
gcloud run logs read backend-api \
  --region=us-central1 \
  --filter="severity=ERROR"

# View specific time range
gcloud run logs read backend-api \
  --region=us-central1 \
  --limit=100 \
  --format=json
```

### Cloud Monitoring

Set up dashboards and alerts:

```bash
# Create dashboard
gcloud monitoring dashboards create --config-from-file=dashboard.json

# Create alert
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="High Error Rate" \
  --condition-display-name="Error Rate > 5%"
```

### Custom Logging

The backend logs important events:

```python
logger.info("Application started")
logger.error("Failed to create item", exc_info=True)
```

View custom logs:

```bash
gcloud logging read "jsonPayload.level=ERROR" --limit=50
```

## Cost Monitoring

### Estimate Costs

Cloud Run pricing:
- **Compute**: $0.00002400 per vCPU-second
- **Requests**: $0.40 per million requests
- **Networking**: Varies

Example (dev):
- 1 vCPU × 10 seconds/day × 30 days = $0.007/month
- 10,000 requests/month = $0.004/month
- **Total**: ~$0.011/month

### Monitor Actual Costs

```bash
gcloud billing accounts list
gcloud billing accounts describe ACCOUNT_ID

# View current month costs
gcloud billing budgets list --billing-account=ACCOUNT_ID
```

### Cost Optimization

1. Reduce memory allocation
2. Reduce max instances
3. Use smaller CPUs for frontend
4. Delete unused services
5. Monitor and right-size

## Troubleshooting

### Cloud Run Service Won't Start

```bash
# Check logs
gcloud run logs read <service> --region=us-central1 --limit=100

# View detailed error
gcloud run services describe <service> \
  --region=us-central1 \
  --format=json
```

### API Gateway Not Routing

1. Check backend service is public:
   ```bash
   gcloud run services get-iam-policy <service> --region=us-central1
   ```

2. Verify OpenAPI spec in `terraform/openapi.yaml`

3. Check API Gateway status:
   ```bash
   gcloud api-gateway apis list
   gcloud api-gateway api-configs list --api=dev-api
   ```

### Firestore Connection Issues

```bash
# Test Firestore API
gcloud firestore databases describe

# View Firestore documents
gcloud firestore documents list --collection-id=items

# Enable Firestore API
gcloud services enable firestore.googleapis.com
```

### Container Image Issues

```bash
# Check if image exists
gcloud container images list

# Inspect image details
gcloud container images describe gcr.io/PROJECT-ID/backend-api:latest

# View recent builds
gcloud builds list
```

## Cleanup

### Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

Removes:
- Cloud Run services
- API Gateway
- Firestore database
- Cloud Storage buckets
- Service accounts

### Delete Container Images

```bash
gcloud container images delete gcr.io/PROJECT-ID/backend-api:latest
gcloud container images delete gcr.io/PROJECT-ID/frontend:latest
```

### Remove State Bucket

```bash
gsutil -m rm -r gs://whales-terraform-state-$(gcloud config get-value project)
```

## Best Practices

1. **Test locally** before deploying to production
2. **Use separate projects** for dev/staging/production
3. **Enable Cloud Monitoring** for observability
4. **Set up Cloud Armor** for security
5. **Implement proper authentication** for API
6. **Use Cloud KMS** for secret management
7. **Enable audit logging** for compliance
8. **Regular backups** of Firestore data
9. **Monitor costs** and optimize
10. **Document deployment procedures**
