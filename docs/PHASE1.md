# Whale Image Classification System - Phase 1 Implementation

## Overview
Phase 1 implements a complete whale image upload and search system with rich metadata tagging, geographic querying, and a searchable gallery interface. This foundation supports Phase 2's classifier and individual whale matching features.

## Architecture

### Infrastructure (Terraform)
- **Whale Images Bucket** (`whale-images-prod`): Stores uploaded whale images with lifecycle rules (archive to Coldline after 90 days)
- **Models Bucket** (`whale-models-prod`): Reserved for Phase 2 ML models
- **API Gateway**: Routes for image operations (upload, search, retrieve, delete)

### Backend (Python/Flask)

#### Endpoints

##### 1. POST `/api/images/request-upload`
**Purpose**: Request a presigned URL for uploading an image

**Request Body**:
```json
{
  "fileName": "whale_photo_20260321_001.jpg",
  "fileSize": 5242880,
  "mimeType": "image/jpeg",
  "metadata": {
    "speciesType": "humpback",
    "location_lat": 42.3601,
    "location_long": -71.0589,
    "region": "alaska",
    "whaleName": "Helen",
    "behavior": ["breaching", "fluking"],
    "podSize": 3,
    "visibleFeatures": "distinctive scar on left fluke",
    "confidence": "high",
    "waterConditions": "excellent",
    "timeOfDay": "morning",
    "observerName": "Dr. Sarah Johnson",
    "vesselName": "Whale Watch Explorer",
    "notes": "Active feeding behavior observed"
  }
}
```

**Response** (200 OK):
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "presignedUrl": "https://storage.googleapis.com/...",
  "expiresIn": 900,
  "uploadPath": "whale_images/550e8400-e29b-41d4-a716-446655440000/whale_photo.jpg"
}
```

**Validation**:
- Species type must be in predefined list
- Coordinates must be valid lat/long
- Pod size must be ≥ 1
- File size must be ≤ 50MB
- Required metadata fields: speciesType, location_lat, location_long, confidence, observerName, vesselName

---

##### 2. POST `/api/images/confirm-upload`
**Purpose**: Confirm file upload completion and finalize metadata

**Request Body**:
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "gcsPath": "whale_images/550e8400-e29b-41d4-a716-446655440000/whale_photo.jpg"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Upload confirmed successfully"
}
```

**Process**:
1. Verifies file exists in Cloud Storage
2. Updates Firestore document with upload completion status
3. Generates searchable tags from metadata
4. Triggers thumbnail generation (optional, for future optimization)

---

##### 3. GET `/api/images/search`
**Purpose**: Search whale images with flexible filtering

**Query Parameters**:
- `species` (string): Filter by species (humpback, fin, blue, gray, etc.)
- `region` (string): Filter by geographic region
- `whaleName` (string): Filter by known whale name
- `startDate` (ISO 8601): Start of date range
- `endDate` (ISO 8601): End of date range
- `behavior` (string): Filter by behavior (feeding, breaching, etc.)
- `observerName` (string): Filter by observer
- `limit` (int, default 20, max 100): Results per page
- `offset` (int, default 0): Pagination offset

**Example**:
```
GET /api/images/search?species=humpback&region=alaska&startDate=2026-01-01T00:00:00Z&limit=20&offset=0
```

**Response** (200 OK):
```json
{
  "images": [
    {
      "imageId": "550e8400-e29b-41d4-a716-446655440000",
      "metadata": { /* full metadata object */ },
      "uploadStatus": "complete",
      "storage": {
        "gcsPath": "whale_images/...",
        "fileSizeBytes": 5242880,
        "fileSizeActual": 5241234,
        "uploadedAt": "2026-03-21T10:30:00Z"
      },
      "createdAt": "2026-03-21T10:25:00Z",
      "searchTags": ["humpback", "alaska", "breaching", "helen"]
    }
  ],
  "count": 12,
  "offset": 0,
  "limit": 20,
  "timestamp": "2026-03-21T11:00:00Z"
}
```

---

##### 4. GET `/api/images/{imageId}`
**Purpose**: Retrieve full metadata for a specific image

**Response** (200 OK): Returns complete image document

**Error** (404): Image not found

---

##### 5. DELETE `/api/images/{imageId}`
**Purpose**: Delete an image and associated file from Cloud Storage

**Response** (204): No content

**Process**:
1. Retrieves GCS path from Firestore
2. Deletes file from Cloud Storage
3. Deletes Firestore document

---

### Database Schema (Firestore)

#### Collection: `whale_images`

```firestore
Document ID: {imageId}
├── imageId: string
├── uploadStatus: "pending" | "complete"
├── createdAt: timestamp
├── storage: {
│   ├── fileName: string
│   ├── fileSizeBytes: integer
│   ├── mimeType: string
│   ├── gcsPath: string
│   ├── uploadedAt: timestamp
│   └── fileSizeActual: integer
├── metadata: {
│   ├── speciesType: string
│   ├── whaleName: string (optional)
│   ├── whaleIndividualId: string (for Phase 2)
│   ├── confidence: "high" | "medium" | "low"
│   ├── podSize: integer
│   ├── location_lat: float
│   ├── location_long: float
│   ├── region: string
│   ├── behavior: [array of strings]
│   ├── visibleFeatures: string
│   ├── waterConditions: string
│   ├── timeOfDay: string
│   ├── observerName: string
│   ├── vesselName: string
│   ├── notes: string
│   └── timestamp: ISO 8601 string
└── searchTags: [array of indexed keywords]
```

**Indexes Created**:
- `uploadStatus` (ASC)
- `metadata.speciesType` (ASC) + uploadStatus (ASC)
- `metadata.region` (ASC) + uploadStatus (ASC)
- `metadata.observerName` (ASC) + uploadStatus (ASC)
- `createdAt` (DESC) for sorting results

---

### Frontend (JavaScript/Node.js)

#### HTML Structure
- **Upload Tab**: Form with rich metadata input
- **Search Tab**: Filter panel + Gallery view + Image details modal
- **Status Tab**: Health checks
- **Data Tab**: Legacy data management

#### Upload Form Sections
1. **Image File**: File picker with size validation
2. **Whale Identification**: Species selector, whale name, confidence level, pod size
3. **Location**: Latitude/longitude inputs, region field
4. **Observations**: Behavior multi-select, distinctive features text
5. **Environmental**: Water visibility, time of day
6. **Attribution**: Observer name, vessel name, additional notes

#### Search Features
- Multi-field filtering
- Date range selection
- Real-time result pagination
- Gallery grid display (3 columns on desktop, 1 on mobile)
- Click-to-detail modal with full metadata
- Delete functionality

#### Upload Flow
```
1. User fills form + selects image
2. Frontend calls: POST /api/images/request-upload → presigned URL
3. Frontend uploads directly to Cloud Storage via presigned URL
4. Frontend calls: POST /api/images/confirm-upload
5. Backend updates Firestore with complete status
6. Frontend shows success message
```

---

## Metadata Specifications

### Species Types
- humpback
- fin
- blue
- gray
- right
- sperm
- beluga
- orca
- other

### Behaviors
- feeding
- breaching
- fluking
- spyhopping
- traveling
- resting

### Water Conditions
- excellent
- good
- fair
- poor

### Confidence Levels
- high
- medium
- low

---

## Environment Variables

### Backend (.env)
```
GCP_PROJECT_ID=your-project-id
ENVIRONMENT=production
FIRESTORE_DATABASE=(default)
WHALE_IMAGES_BUCKET=whales-prod-whale-images
STORAGE_BUCKET=whales-prod-uploads
```

### Frontend (.env)
```
API_GATEWAY_URL=https://api-xyz.gateway.dev/api
NODE_ENV=production
```

---

## Deployment Steps

### 1. Update Infrastructure
```bash
# Review and deploy Terraform changes
cd terraform
terraform plan
terraform apply
```

### 2. Deploy Backend
```bash
cd backend
gcloud builds submit --tag gcr.io/PROJECT_ID/whales-backend:phase1
gcloud run deploy whales-backend \
  --image gcr.io/PROJECT_ID/whales-backend:phase1 \
  --platform managed \
  --region us-central1 \
  --set-env-vars WHALE_IMAGES_BUCKET=whales-prod-whale-images
```

### 3. Deploy Frontend
```bash
cd frontend
gcloud builds submit --tag gcr.io/PROJECT_ID/whales-frontend:phase1
gcloud run deploy whales-frontend \
  --image gcr.io/PROJECT_ID/whales-frontend:phase1 \
  --platform managed \
  --region us-central1
```

### 4. Update API Gateway
```bash
# Deploy new OpenAPI spec
gcloud api-gateway apis create whales-api --project PROJECT_ID
gcloud api-gateway api-configs create prod \
  --api=whales-api \
  --openapi-spec=openapi.yaml \
  --backend-auth-service-account SA_EMAIL
gcloud api-gateway gateways create whales-gateway \
  --api=whales-api \
  --api-config=prod \
  --location=us-central1
```

---

## Testing Checklist

- [ ] Upload image with complete metadata
- [ ] Verify presigned URL receives ~15 min expiration
- [ ] Confirm file appears in Cloud Storage bucket
- [ ] Verify Firestore document created with correct schema
- [ ] Search by species
- [ ] Search by date range
- [ ] Search by whale name
- [ ] Pagination works (20 results per page)
- [ ] Delete image removes both Firestore doc and GCS file
- [ ] View image details modal
- [ ] Form validation catches invalid coordinates
- [ ] Form validation catches invalid species
- [ ] Responsiveness on mobile (tabs stack vertically)
- [ ] Upload progress bar shows during transfer
- [ ] Error handling for network failures
- [ ] Whale name field optional (not required)

---

## Cost Estimation (Monthly)

For 1000 uploads/month @ 5MB each:

- **Cloud Storage**: ~$0.02 (5GB stored, $0.020/GB)
- **Firestore Reads**: ~$0.10 (5000 reads @ $0.06/100k)
- **Firestore Writes**: ~$0.20 (1000 uploads × 2-3 writes @ $0.18/100k)
- **Cloud Run**: ~$0.50 (request duration ~500ms, 3000 requests)
- **API Gateway**: ~$0.35 (3000 requests @ $0.35-1.50 per million)
- **Bandwidth**: ~$0.50 (25GB outbound @ $0.12/GB)

**Total**: ~$1.67/month (well under GCP free tier for testing)

---

## Future Enhancements (Phase 2)

- Automatic whale species classification
- Individual whale flukes matching
- Whale sighting timeline and migration maps
- Observer statistics and leaderboards
- Batch upload support
- Image thumbnail generation and caching
- Community whale database integration
- Mobile app for field uploads

---

## Related Files

- Backend: [app.py](../backend/app.py)
- Frontend: [index.html](../frontend/public/index.html)
- Frontend: [app.js](../frontend/public/app.js)
- Frontend: [whaleImages.js](../frontend/public/whaleImages.js)
- Terraform: [main.tf](../terraform/main.tf)
- Terraform: [openapi.yaml](../terraform/openapi.yaml)
- Terraform: [variables.tf](../terraform/variables.tf)
