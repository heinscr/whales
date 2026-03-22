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
- Set up Cloud Storage and service accounts

### Firestore Initialization

Google Cloud requires a one-time manual Firestore database initialization for each project. Terraform can manage Firestore-related resources only after the database exists.

Before running infrastructure or deployment scripts, create the Firestore database in the Google Cloud Console:

1. Open `https://console.cloud.google.com/datastore/setup?project=YOUR_GCP_PROJECT_ID`
2. Choose `Firestore` in `Native mode`
3. Use database ID `(default)`
4. Select the same region as your deployment, for example `us-central1`

After this one-time step, you can continue with Terraform and the deployment scripts normally.

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
- Setup Cloud Storage buckets
- Configure API Gateway
- Create necessary service accounts

Note: the initial Firestore database must already exist before this step. See `Firestore Initialization` above.

### 4. Deploy Applications

```bash
bash scripts/deploy.sh
```

This will:
- Build backend Docker image and push to Google Container Registry
- Build frontend Docker image and push to Google Container Registry
- Deploy backend to Cloud Run (Python/Flask)
- Deploy frontend to Cloud Run (Node.js/Express)
- Configure service accounts and permissions
- Output deployment URLs

### 5. Access Your Application

After deployment, you'll see URLs for:
- **Frontend**: `https://<frontend-cloud-run-url>`
- **Backend**: `https://<backend-cloud-run-url>`

Visit the Frontend URL to access the application.

## Deployment

Deployment is fully automated with container building and image management:

```bash
bash scripts/deploy.sh
```

**What happens:**

1. **Build Backend**: Python code is containerized using the backend Dockerfile
2. **Push Backend**: Image is pushed to Google Container Registry
3. **Deploy Backend**: Cloud Run service is created/updated with the image
4. **Build Frontend**: Node.js code is containerized
5. **Push Frontend**: Image is pushed to Google Container Registry  
6. **Deploy Frontend**: Cloud Run service is created/updated with the image
7. **Configure Permissions**: Service accounts are granted necessary IAM roles for Firestore and Cloud Storage

**Key Features:**
- Images are tagged with environment (dev/production) and "latest"
- Each deployment is immutable (images are versioned)
- Automatic scaling configured (0-100 instances)
- Environment variables auto-configured based on Terraform outputs

**To monitor deployments:**

```bash
# View backend logs (live)
gcloud alpha run logs read production-backend --region us-central1 --follow

# View frontend logs  
gcloud alpha run logs read production-frontend --region us-central1 --follow

# Check service status
gcloud run services describe production-backend --region us-central1
```

## Configuration

### Environment Variables

**Frontend (.env)**
```
NODE_ENV=production
PORT=3000
API_GATEWAY_URL=https://<backend-cloud-run-url>/api
```

**Backend** (auto-configured by deploy.sh):
- `GCP_PROJECT_ID` - Your GCP project
- `ENVIRONMENT` - dev, staging, or production
- `FIRESTORE_DATABASE` - Firestore database name
- `WHALE_IMAGES_BUCKET` - Cloud Storage bucket for whale images
- `STORAGE_BUCKET` - Cloud Storage bucket for general uploads

### Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
gcp_project_id    = "your-gcp-project"
gcp_region        = "us-central1"
environment       = "production"
```

## Development

### Local Setup

After running `bash scripts/deploy.sh` at least once, it writes a `local.env` file at `~/.config/whales/local.env` containing all the environment variables (credentials path, project ID, bucket names, etc.) needed to run the backend locally.

**Terminal 1: Start Backend**

```bash
cd backend
python3 -m venv venv          # first time only
source venv/bin/activate
pip install -r requirements.txt  # first time only

source ~/.config/whales/local.env
python app.py   # runs on http://localhost:8000
```

Or as a one-liner after the first setup:

```bash
cd backend && source venv/bin/activate && source ~/.config/whales/local.env && python app.py
```

**Terminal 2: Start Frontend**

```bash
cd frontend
npm install   # first time only
API_GATEWAY_URL="http://localhost:8000/api" npm start   # runs on http://localhost:3000
```

Then visit `http://localhost:3000`.

> **Note:** `~/.config/whales/local.env` is regenerated on every `deploy.sh` run, so it always reflects the current project and environment. Never commit it — it contains a path to your service account key.

### What's in local.env

| Variable | Description |
|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to the service account key downloaded by `deploy.sh` |
| `GCP_PROJECT_ID` | Your GCP project ID |
| `ENVIRONMENT` | Current environment (e.g. `production`) |
| `FIRESTORE_DATABASE` | Firestore database ID (`(default)`) |
| `WHALE_IMAGES_BUCKET` | GCS bucket for whale images |
| `STORAGE_BUCKET` | GCS bucket for uploads |
| `SIGNING_SERVICE_ACCOUNT` | Service account used to sign GCS URLs |
| `PORT` | Backend port (`8000`) |

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
