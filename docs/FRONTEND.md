# Frontend Development Guide

## Overview

The frontend is a JavaScript (Node.js/Express) application served via Google Cloud Run. It provides static assets, configuration, and serves the single-page application to users.

## Architecture

The frontend:
- Serves static HTML, CSS, and JavaScript files
- Acts as a configuration server for environment variables
- Handles API gateway URL injection
- Auto-scales based on traffic via Cloud Run
- Scales to zero when idle

## Setup

### Prerequisites
- Node.js 18+
- npm or yarn
- Docker (for Cloud Run deployment)

### Local Development

```bash
npm install
npm run dev
# Frontend runs on http://localhost:3000
```

### Docker Build (for Cloud Run)

```bash
docker build -t frontend:latest .
```

## Configuration

### Environment Variables

Create a `.env` file (copy from `.env.example`):

```
NODE_ENV=development
PORT=3000
API_GATEWAY_URL=http://localhost:8000/api
```

In production (Cloud Run), these are set via Terraform outputs.

## Project Structure

```
frontend/
├── server.js              # Express server
├── package.json          # Dependencies
├── Dockerfile            # Container image
├── public/               # Static files served to browser
│   ├── index.html        # Main HTML page
│   ├── style.css         # Styling
│   ├── app.js            # Frontend logic
│   ├── api.js            # API client library
│   └── config.js         # Client-side configuration
└── .env.example         # Environment template
```

## API Integration

### API Configuration

The API URL is automatically configured based on the environment:

**Development (Local)**
```javascript
const CONFIG = {
  API_GATEWAY_URL: 'http://localhost:8000/api'
};
```

**Production (Cloud Run)**
```javascript
const CONFIG = {
  API_GATEWAY_URL: '<api-gateway-url>/api'  // Set by Terraform
};
```

### Available API Endpoints

All requests go through API Gateway:

```javascript
// Health check
GET /api/health

// List items
GET /api/items

// Create item
POST /api/items
Body: { title: "string", value: number }

// Get item
GET /api/items/:id

// Update item
PUT /api/items/:id
Body: { title?: "string", value?: number }

// Delete item
DELETE /api/items/:id
```

## Development

### Running Locally

```bash
npm install
npm run dev
```

Then open `http://localhost:3000` in your browser.

### File Structure Explanation

- **server.js**: Express server that:
  - Serves static files from `public/`
  - Provides health check endpoint
  - Sets up CORS and compression

- **public/index.html**: Main page structure

- **public/config.js**: API configuration

- **public/api.js**: Helper functions for API calls

- **public/app.js**: Frontend logic and DOM manipulation

- **public/style.css**: CSS styling

### Making API Calls

The `api.js` file provides helper functions:

```javascript
// Call API
const data = await API.listItems();

// Or use raw fetch with CONFIG
const response = await fetch(`${CONFIG.API_GATEWAY_URL}/items`);
const data = await response.json();
```

## Deployment

### Build Docker Image

```bash
docker build -t gcr.io/PROJECT-ID/frontend:latest .
```

### Push to Container Registry

```bash
docker push gcr.io/PROJECT-ID/frontend:latest
```

### Deploy via Terraform

Update `terraform/terraform.tfvars`:

```hcl
frontend_image_url = "gcr.io/PROJECT-ID/frontend:latest"
```

Then:
```bash
terraform apply
```

Or use the automated deployment:
```bash
bash scripts/deploy.sh
```

## Cloud Run Configuration

### View Deployment

```bash
gcloud run services list
```

### View Logs

```bash
gcloud run logs read frontend --region=us-central1 --limit=50
```

### Scaling

```bash
# Adjust memory allocation
gcloud run services update frontend \
  --memory=512Mi \
  --region=us-central1

# Set max instances
gcloud run services update frontend \
  --max-instances=10 \
  --region=us-central1
```

## Testing

### Manual Testing

1. Open frontend URL in browser
2. Check health status
3. Check if API Gateway is reachable
4. Create/read/delete items

### Automated Testing

Add test files using Jest:

```bash
npm install --save-dev jest
npm test
```

## Troubleshooting

### API Gateway Not Reachable

1. Check API Gateway URL in Cloud Console
2. Verify Cloud Run backend is running
3. Check CORS configuration in OpenAPI spec
4. Check browser console for error details

### Static Files Not Loading

1. Ensure files exist in `public/` directory
2. Check file paths (case-sensitive)
3. Verify `server.js` is serving from correct directory

### Cloud Run Service Timeout

1. Increase memory allocation
2. Check if backend is responding
3. Review Cloud Run logs

## Performance Optimization

1. **Enable compression** (already configured in server.js)
2. **Minify assets** before deployment
3. **Cache static files** with Cloud CDN
4. **Use service worker** for offline support

## Security

1. **Never expose secrets** in frontend code
2. **Use API Gateway** for rate limiting
3. **Enable HTTPS** (automatic with Cloud Run)
4. **Implement CORS** properly
5. **Validate user input** on API calls

## Monitoring

### CloudRun Metrics

- Request count
- Error rate
- Latency (p50, p95, p99)
- Memory usage
- CPU usage

View in Cloud Console:
```
Cloud Run → frontend → Metrics
```

## Next Steps

1. Customize the UI in `public/index.html`
2. Add more API endpoints
3. Implement authentication
4. Add PWA features
5. Set up CI/CD pipeline

