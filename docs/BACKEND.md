# Backend Development Guide

## Overview

The backend is a Python Flask application deployed on Google Cloud Run. It provides REST API endpoints, handles Firestore database operations, and manages file uploads to Cloud Storage.

## Architecture

The backend:
- Provides REST API endpoints via Flask
- Integrates with Firestore for NoSQL data storage
- Stores files in Google Cloud Storage
- Scales automatically via Cloud Run
- Scales to zero when idle (cost-efficient)
- Accessed directly from frontend with CORS enabled

## Setup

### Prerequisites
- Python 3.9+
- pip

### Local Development

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Set environment variables (create `.env` from `.env.example`):

```
GCP_PROJECT_ID=your-project-id
ENVIRONMENT=development
FIRESTORE_DATABASE=(default)
STORAGE_BUCKET=your-bucket-name
PORT=8080
```

### Run Development Server

```bash
python app.py
```

The backend will run on `http://localhost:8080`

## Configuration

### Environment Variables

Create a `.env` file:

```
GCP_PROJECT_ID=whales-project
ENVIRONMENT=development
FIRESTORE_DATABASE=development-database
STORAGE_BUCKET=whales-project-development-uploads
PORT=8080
```

In production (Cloud Run), these are set automatically by `deploy.sh`.

## Project Structure

```
backend/
├── app.py              # Flask application
├── requirements.txt    # Python dependencies
├── .env.example       # Environment template
└── [future: additional modules as needed]
```

## API Endpoints

### Health Check
```
GET /api/health
```

Response:
```json
{
  "status": "healthy",
  "service": "backend-api",
  "environment": "development",
  "timestamp": "2024-01-15T10:30:00"
}
```

### List Items
```
GET /api/items
```

Response:
```json
{
  "items": [
    {
      "id": "doc-id",
      "title": "Item 1",
      "value": 100,
      "createdAt": "2024-01-15T10:00:00",
      "updatedAt": "2024-01-15T10:00:00"
    }
  ],
  "count": 1,
  "timestamp": "2024-01-15T10:30:00"
}
```

### Create Item
```
POST /api/items
Content-Type: application/json

{
  "title": "New Item",
  "value": 150
}
```

Response (201 Created):
```json
{
  "id": "new-doc-id",
  "title": "New Item",
  "value": 150,
  "createdAt": "2024-01-15T10:30:00",
  "updatedAt": "2024-01-15T10:30:00"
}
```

### Get Item
```
GET /api/items/:item_id
```

### Update Item
```
PUT /api/items/:item_id
Content-Type: application/json

{
  "title": "Updated Title",
  "value": 200
}
```

### Delete Item
```
DELETE /api/items/:item_id
```

## Development

### Running Locally

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python app.py
```

### Working with Firestore

#### Without Emulator (using live Firestore)
- Ensure GCP credentials are set: `gcloud auth application-default login`
- Ensure Firestore API is enabled in GCP

#### With Emulator (local testing)

```bash
# Install Firebase tools
npm install -g firebase-tools

# Start emulator
firebase emulators:start

# Update code to use emulator
import os
os.environ["FIRESTORE_EMULATOR_HOST"] = "localhost:8081"
```

## Deployment

Cloud Run handles deployment automatically from source code. See the main README for deployment instructions.

Run `bash scripts/deploy.sh` from the project root to deploy the backend.

## Cloud Run Configuration

After deployment via `deploy.sh`, view deployment details:

```bash
# List services
gcloud run services list --region=us-central1

# View specific service
gcloud run services describe production-api --region=us-central1

# View logs
gcloud run services logs read production-api --region=us-central1 --limit=50
```

## Database Operations

### Using Firestore

All database operations use the Firestore client:

```python
from google.cloud import firestore

db = firestore.Client()

# Get collection
items = db.collection('items').stream()

# Add document
db.collection('items').add({
    'title': 'New Item',
    'value': 100
})

# Update document
db.collection('items').document('doc-id').update({
    'title': 'Updated'
})

# Delete document
db.collection('items').document('doc-id').delete()
```

### Document Schema

```
Collection: items
├── title (string)
├── value (number)
├── createdAt (timestamp)
└── updatedAt (timestamp)
```

## Testing

### Manual API Testing

Using curl:

```bash
# Health check
curl http://localhost:8080/api/health

# List items
curl http://localhost:8080/api/items

# Create item
curl -X POST http://localhost:8080/api/items \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","value":100}'

# Get item
curl http://localhost:8080/api/items/doc-id

# Update item
curl -X PUT http://localhost:8080/api/items/doc-id \
  -H "Content-Type: application/json" \
  -d '{"title":"Updated"}'

# Delete item
curl -X DELETE http://localhost:8080/api/items/doc-id
```

### Unit Testing

Add pytest tests:

```bash
pip install pytest pytest-cov
```

Create `test_app.py`:

```python
import pytest
from app import app

@pytest.fixture
def client():
    with app.test_client() as client:
        yield client

def test_health(client):
    response = client.get('/api/health')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'
```

Run tests:
```bash
pytest -v --cov=app
```

## Troubleshooting

### Module Not Found

```bash
pip install -r requirements.txt
```

### Firestore Connection Error

Check:
1. GCP authentication: `gcloud auth login`
2. Firestore enabled: `gcloud services enable firestore.googleapis.com`
3. Environment variables set correctly
4. Service account has Firestore permissions

### Cloud Run Logs

```bash
gcloud run services logs read production-api --region=us-central1 --limit=100
```

### Port Already in Use

```bash
# Use different port
PORT=8081 python app.py
```

## Performance Optimization

1. **Connection Pooling**: Firestore client is shared as global
2. **Caching**: Add Redis for frequent queries
3. **Async**: Consider async Flask for I/O
4. **Indexes**: Create Firestore composite indexes for complex queries
5. **Batch Operations**: Use batch writes for multiple documents

## Security

1. **Input Validation**: Validate all request data
2. **Error Messages**: Don't expose sensitive info
3. **Service Account**: Use least-privilege IAM roles
4. **HTTPS**: Automatic with Cloud Run
5. **CORS**: Enabled for cross-origin requests from frontend

## Monitoring

### Cloud Run Metrics

View in Cloud Console:
```
Cloud Run → production-api → Metrics
```

Metrics include:
- Request count
- Error rate (4xx, 5xx)
- Latency (p50, p95, p99)
- Memory usage
- CPU usage

### Custom Logging

Add logging to track application flow:

```python
import logging
logger = logging.getLogger(__name__)

@app.route('/api/items', methods=['GET'])
def list_items():
    logger.info("Fetching items from Firestore")
    # ... rest of code
```

## Next Steps

1. Add authentication (JWT, OAuth2)
2. Implement Firestore security rules
3. Add request validation and sanitization
4. Set up CI/CD pipeline
5. Add comprehensive logging and monitoring
6. Implement caching strategies
