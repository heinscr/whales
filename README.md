# Whales Application

A serverless full-stack web application built with Terraform for GCP infrastructure, JavaScript frontend (Express/Node.js), Python backend (Flask on Cloud Run), Firestore for data storage, and API Gateway for API management.

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Development](#development)
- [Cost Optimization](#cost-optimization)
- [Documentation](#documentation)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    GCP Serverless Stack                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Cloud Run Frontend (JavaScript/Node.js)         │   │
│  │  - Serves static assets + configuration          │   │
│  │  - Auto-scales based on traffic                  │   │
│  │  - Pay only for execution time                   │   │
│  └────────────────┬─────────────────────────────────┘   │
│                   │                                       │
│  ┌────────────────▼─────────────────────────────────┐   │
│  │  API Gateway                                     │   │
│  │  - Single entry point for all API calls         │   │
│  │  - Rate limiting, authentication, logging       │   │
│  │  - CORS management                              │   │
│  └────────────────┬─────────────────────────────────┘   │
│                   │                                       │
│  ┌────────────────▼─────────────────────────────────┐   │
│  │  Cloud Run Backend (Python/Flask)                │   │
│  │  - RESTful API endpoints                         │   │
│  │  - Auto-scales to zero when idle                │   │
│  │  - Firestore integration                         │   │
│  └────────────────┬─────────────────────────────────┘   │
│                   │                                       │
│  ┌────────────────▼────────┐  ┌──────────────────────┐  │
│  │  Firestore (NoSQL)      │  │  Cloud Storage       │  │
│  │  - Document database    │  │  - File uploads      │  │
│  │  - Real-time sync       │  │  - Static assets     │  │
│  │  - Free tier friendly   │  │  - Bucket storage    │  │
│  └─────────────────────────┘  └──────────────────────┘  │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Components

- **Frontend**: JavaScript (Node.js/Express) served via Cloud Run
- **Backend**: Python (Flask) deployed as Cloud Run services
- **API Layer**: Google Cloud API Gateway for centralized API management
- **Database**: Google Firestore (NoSQL, document-based)
- **Storage**: Google Cloud Storage for file uploads and static assets
- **Infrastructure**: Terraform for infrastructure-as-code

## Prerequisites

### For Local Development

- [Node.js](https://nodejs.org/) >= 18 (for frontend)
- [Python](https://www.python.org/) >= 3.9 (for backend)
- [Git](https://git-scm.com/)

### For GCP Infrastructure & Deployment

- [Terraform](https://www.terraform.io/downloads) >= 1.0 (infrastructure setup)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (GCP CLI)

**Note:** Docker is not required. Cloud Run builds containers from source automatically.

### GCP Setup

1. **Authenticate with GCP**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Create a GCP Project**
   ```bash
   gcloud projects create whales-app
   gcloud config set project whales-app
   ```

3. **Grant Cloud Build Permissions**
   ```bash
   PROJECT_ID=$(gcloud config get-value project)
   
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member=user:YOUR-EMAIL@gmail.com \
     --role=roles/cloudbuild.builds.editor
   
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member=user:YOUR-EMAIL@gmail.com \
     --role=roles/storage.admin
   ```
   
   Replace `YOUR-EMAIL@gmail.com` with your actual Google account email.

**That's it!** The infrastructure.sh script will automatically:
- Enable required GCP APIs
- Create the Terraform state storage bucket
- Set up Firestore, Cloud Storage, and service accounts

## Project Structure

```
whales/
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                   # Cloud Run, API Gateway, Firestore setup
│   ├── variables.tf              # Configuration variables
│   ├── outputs.tf                # Output endpoints and URLs
│   ├── openapi.yaml              # API Gateway specification
│   └── terraform.tfvars.example  # Configuration template
│
├── frontend/                      # JavaScript Frontend
│   ├── server.js                 # Express.js server
│   ├── package.json              # Node.js dependencies
│   ├── Dockerfile                # Container image for Cloud Run
│   ├── public/                   # Static assets
│   │   ├── index.html            # Main page
│   │   ├── style.css             # Styling
│   │   ├── app.js                # Frontend logic
│   │   ├── api.js                # API client
│   │   └── config.js             # Configuration
│   └── .env.example              # Environment template
│
├── backend/                       # Python Backend
│   ├── app.py                    # Flask application
│   ├── requirements.txt          # Python dependencies
│   ├── Dockerfile                # Container image for Cloud Run
│   └── .env.example              # Environment template
│
├── scripts/                       # Deployment & Setup
│   ├── infrastructure.sh          # Initialize infrastructure
│   └── deploy.sh                 # Build & deploy containers
│
├── docs/                          # Documentation
│   ├── FRONTEND.md               # Frontend setup
│   ├── BACKEND.md                # Backend setup
│   ├── TERRAFORM.md              # Infrastructure guide
│   └── DEPLOYMENT.md             # Deployment procedures
│
├── .github/
│   └── copilot-instructions.md   # Project guidelines
│
├── .gitignore
├── .env.example
└── README.md
```

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd whales
```

### 2. Configure GCP

```bash
# Copy Terraform configuration
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit with your GCP project details
nano terraform.tfvars
```

Set these values in `terraform.tfvars`:
```hcl
gcp_project_id = "your-gcp-project-id"
gcp_region     = "us-central1"
environment    = "dev"
```

### 3. Setup Infrastructure

```bash
bash scripts/infrastructure.sh
```

This will:
- Initialize Terraform
- Create Firestore database
- Setup Cloud Storage buckets
- Configure API Gateway
- Create necessary service accounts

### 4. Deploy Applications

```bash
bash scripts/deploy.sh
```

This will:
- Deploy backend API to Cloud Run (Python with source)
- Deploy frontend to Cloud Run (Node.js with source)
- Google Cloud automatically builds containers from your source code

### 5. Access Your Application

After deployment, you'll see URLs for:
- **Frontend**: `https://<frontend-cloud-run-url>`
- **Backend**: `https://<backend-cloud-run-url>`

Just visit the Frontend URL to access the application.

## Deployment

Deployment is fully automated using Cloud Run with Source:

```bash
bash scripts/deploy.sh
```

**What happens:**
1. Backend code is deployed as a Cloud Run service
2. Frontend code is deployed as a Cloud Run service  
3. Google Cloud automatically builds containers and applies optimizations
4. Services are configured with appropriate environment variables and resource limits

**No Docker required!** Cloud Run builds everything for you.

## Configuration

### Environment Variables

**Frontend (.env)**
```
NODE_ENV=production
PORT=3000
API_GATEWAY_URL=https://<api-gateway-url>
```

**Backend Environment Variables** (auto-configured by deploy.sh):
- `GCP_PROJECT_ID` - Your GCP project
- `ENVIRONMENT` - dev, staging, or production
- `FIRESTORE_DATABASE` - Firestore database name
- `STORAGE_BUCKET` - Cloud Storage bucket for uploads

### Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
gcp_project_id    = "your-gcp-project"
gcp_region        = "us-central1"
environment       = "production"
```

## Development

### Local Testing (No Docker Needed)

You can test the application locally without Docker before deploying to GCP.

**Terminal 1: Start Backend**

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py   # Runs on http://localhost:8080
```

**Terminal 2: Start Frontend**

```bash
cd frontend
npm install
npm start   # Runs on http://localhost:3000
```

Then visit `http://localhost:3000` in your browser to test the application.

**Note**: The frontend will call your backend at `http://localhost:8080`. To configure this, create a `.env` file in the frontend directory:

```
API_GATEWAY_URL=http://localhost:8080
```

### Working with Firestore Locally

Use the Firebase Local Emulator:

```bash
npm install -g firebase-tools
firebase login
firebase emulators:start
```

## Cost Optimization

This architecture is designed for minimal costs:

- **Cloud Run**: $0.00002400 per vCPU-second, scales to zero
- **Firestore**: Free tier includes 50K reads/day, 20K writes/day
- **API Gateway**: $3.50 per million API calls
- **Cloud Storage**: $0.020 per GB/month

### Cost Savings Tips

1. **Set up Cloud Run on-demand limits**
   ```bash
   gcloud run services update <service> \
     --max-instances=5 \
     --region=us-central1
   ```

2. **Enable Firestore autoscaling**
   - Configured automatically in Terraform

3. **Delete unused resources**
   ```bash
   terraform destroy
   ```

4. **Monitor usage**
   ```bash
   gcloud billing accounts describe <ACCOUNT>
   ```

## Monitoring & Logging

### View Logs

```bash
# Frontend logs
gcloud run logs read frontend --region=us-central1

# Backend logs
gcloud run logs read backend-api --region=us-central1

# API Gateway logs
gcloud logging read "resource.type=api" --limit 50
```

### Set up Cloud Monitoring

```bash
gcloud monitoring dashboards create --config-from-file=dashboard.json
```

## Scaling

### Scale Cloud Run Services

```bash
# Increase max concurrent requests
gcloud run services update <service> \
  --concurrency=100 \
  --region=us-central1

# Set memory allocation
gcloud run services update <service> \
  --memory=2Gi \
  --region=us-central1
```

### Database Scaling

Firestore automatically scales. Monitor usage in Cloud Console:
- Firestore → Database → Metrics

## Troubleshooting

### Cloud Run Service Won't Start

```bash
gcloud run logs read <service> --region=us-central1 --limit=50
```

### API Gateway Not Routing Requests

1. Check OpenAPI spec: `terraform/openapi.yaml`
2. Verify backend URL is correct
3. Check Cloud Run service is public: `gcloud run services get-iam-policy <service>`

### Firestore Connection Issues

```bash
# Test Firestore access
gcloud firestore databases list
gcloud firestore documents list --collection-id=items
```

## Security Best Practices

1. **Don't commit secrets**
   - Use `.gitignore` for `.env` files
   - Use Google Secret Manager for production

2. **Firestore Security Rules**
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

3. **Cloud Run Security**
   - All services are unauthenticated by default
   - Implement authentication via API Gateway

4. **API Gateway Rate Limiting**
   - Configure in OpenAPI spec
   - Set quota limits

## Contributing

1. Create a feature branch
2. Make changes
3. Test locally with emulators
4. Submit pull request

## License

MIT

## Support

For issues, open a GitHub issue or check the documentation files in `docs/`.
