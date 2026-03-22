# Whale Image Classification System - Phase 2 Plan

## Overview
Phase 2 adds automatic whale species classification and individual whale matching/identification. When a new image is uploaded, a ML classifier automatically identifies the species and attempts to match the whale to known individuals in the database.

---

## Architecture

### ML Workflow

```
New Image Upload
      ↓
[Phase 1 Complete]
      ↓
Extract Features (Tail Flukes, Markings)
      ↓
Species Classifier (ResNet50-based)
      ↓
Species + Confidence Score
      ↓
Fluke/Marking Matcher (HappyWhale-style)
      ↓
Top-N Matches with Scores
      ↓
Update whaleIndividualId + classification metadata
      ↓
Display to User for Verification/Correction
```

---

## Existing Whale Classifiers

### Recommended: Humpback Whale Fluke Matching
**Source**: HappyWhale.com Research Data
- Focuses on individual whale re-identification via tail flukes
- Large public dataset (~2000 humpback individuals)
- Convolutional neural network trained on visual features
- ~85-95% accuracy for known individuals

**Implementation**:
- Download pre-trained model from HappyWhale (if available)
- Or fine-tune ResNet50 on their dataset
- Crops whale fluke region from uploaded image
- Compares against reference fluke images in database

### Alternative: NOAA Whale Detection Models
- General species classification
- Less individual-specific
- Good for species validation

### Default: Transfer Learning (Recommended)
- Start with ImageNet-pretrained ResNet50
- Fine-tune on growing dataset of user uploads
- Better accuracy as dataset grows
- Lightweight (~100MB model)

---

## Backend Implementation

### 1. New Python Dependencies

```txt
tensorflow==2.14.0
opencv-python==4.8.0
numpy==1.24.0
pillow==10.0.0
scikit-learn==1.3.0  # For similarity scoring
google-cloud-storage==2.14.0
```

### 2. Backend Structure

```
backend/
├── app.py (updated with classification endpoints)
├── models/
│   ├── classifier.py (species classification)
│   ├── matcher.py (individual whale matching)
│   └── feature_extractor.py (fluke/marking extraction)
├── ml_models/
│   ├── resnet50_species.h5 (species classifier weights)
│   └── fluke_matcher.pkl (fluke matching model)
└── utils/
    ├── image_processing.py (preprocessing, cropping)
    └── similarity.py (distance metrics)
```

### 3. New API Endpoints

#### POST `/api/classify/predict-species`
**Purpose**: Classify image species immediately after upload

**Request**:
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "gcsPath": "whale_images/.../photo.jpg"
}
```

**Response**:
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "classification": {
    "predictedSpecies": "humpback",
    "speciesConfidence": 0.92,
    "topSpecies": [
      {"species": "humpback", "confidence": 0.92},
      {"species": "fin", "confidence": 0.06},
      {"species": "other", "confidence": 0.02}
    ],
    "modelVersion": "resnet50_v2",
    "classifiedAt": "2026-03-21T10:35:00Z"
  }
}
```

---

#### POST `/api/classify/match-whale`
**Purpose**: Find matching known whales (individual identification)

**Request**:
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "gcsPath": "whale_images/.../photo.jpg",
  "speciesType": "humpback"  // Optional, uses classifier result if not provided
}
```

**Response**:
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "matches": [
    {
      "whaleIndividualId": "whale_001_helen",
      "whaleName": "Helen",
      "matchConfidence": 0.87,
      "matchType": "fluke_match",
      "lastSeen": "2026-03-15",
      "photoCount": 47,
      "distinctiveFeatures": ["scar on left fluke", "white on tail"]
    },
    {
      "whaleIndividualId": "whale_012_fred",
      "whaleName": "Fred",
      "matchConfidence": 0.64,
      "matchType": "marking_match",
      "lastSeen": "2026-02-20",
      "photoCount": 12
    },
    {
      "whaleIndividualId": "whale_005_unknown",
      "whaleName": "Unknown",
      "matchConfidence": 0.42,
      "matchType": "behavior_similarity"
    }
  ],
  "modelVersion": "flukes_v1",
  "matchedAt": "2026-03-21T10:36:00Z"
}
```

---

#### POST `/api/classify/confirm-match`
**Purpose**: User confirms or corrects whale identification

**Request**:
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "whaleIndividualId": "whale_001_helen",
  "whaleName": "Helen",
  "isNewWhale": false,
  "feedback": "Correct match"
}
```

**Response**:
```json
{
  "success": true,
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "whaleIndividualId": "whale_001_helen"
}
```

**Process**:
1. Updates whale_images.metadata.whaleIndividualId
2. Increments known_whales.photoCount
3. Updates known_whales.lastSeen
4. Stores user correction for model retraining

---

#### POST `/api/classify/create-new-whale`
**Purpose**: Create new whale individual record (not previously seen)

**Request**:
```json
{
  "imageId": "550e8400-e29b-41d4-a716-446655440000",
  "whaleName": "Neptune",
  "speciesType": "humpback",
  "distinctiveFeatures": ["large white belly", "two scars on back"]
}
```

**Response**:
```json
{
  "whaleIndividualId": "whale_234_neptune",
  "whaleName": "Neptune",
  "createdAt": "2026-03-21T10:37:00Z"
}
```

---

#### GET `/api/whales/{whaleIndividualId}`
**Purpose**: Get whale individual profile

**Response**:
```json
{
  "whaleIndividualId": "whale_001_helen",
  "name": "Helen",
  "aliases": ["HB-001", "The Queen"],
  "species": "humpback",
  "distinctiveFeatures": ["scar on left fluke", "white tail markings"],
  "firstSeen": "2023-06-15",
  "lastSeen": "2026-03-15",
  "photoCount": 47,
  "migrationPath": {
    "summering": "Gulf of Maine",
    "wintering": "Caribbean"
  },
  "photos": [
    "550e8400-e29b-41d4-a716-446655440000",
    "..."
  ],
  "matchHistory": [
    {
      "imageId": "...",
      "matchedAt": "2026-03-21T10:35:00Z",
      "confidence": 0.87,
      "observerName": "Dr. Johnson"
    }
  ]
}
```

---

#### GET `/api/whales/by-species/{species}`
**Purpose**: Get all known whales of a species

**Response**:
```json
{
  "species": "humpback",
  "count": 47,
  "whales": [
    {
      "whaleIndividualId": "whale_001_helen",
      "name": "Helen",
      "photoCount": 47,
      "lastSeen": "2026-03-15"
    }
  ]
}
```

---

## Database Extensions

### Collection: `known_whales`

```firestore
Document ID: {whaleIndividualId}
├── name: string
├── aliases: [array of strings]
├── species: string
├── distinctiveFeatures: [array of strings]
├── firstSeen: date
├── lastSeen: date
├── photoCount: integer (auto-incremented)
├── photos: [array of imageIds]
├── migrationPath: {
│   ├── summering: string (location)
│   ├── wintering: string (location)
│   └── migrationRoute: [array of {date, location}]
├── matchCount: integer
├── averageMatchConfidence: float
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Collection: `classification_feedback`

For model retraining:

```firestore
Document ID: {feedbackId}
├── imageId: string
├── userCorrection: {
│   ├── speciesProposal: string
│   ├── predictionWasWrong: boolean
│   ├── whaleIndividualId: string
│   ├── confidence: string
├── submittedBy: string
├── submittedAt: timestamp
└── used_in_retraining: boolean
```

### Updated Collection: `whale_images`

Add classification fields:

```firestore
whale_images/{imageId}
├── [Phase 1 fields...]
└── classification: {
    ├── predictedSpecies: string
    ├── speciesConfidence: float (0-1)
    ├── speciesTopChoices: [
    │   {species: string, confidence: float}
    │ ]
    ├── matchedIndividuals: [
    │   {
    │     whaleIndividualId: string,
    │     matchConfidence: float,
    │     matchType: string
    │   }
    │ ]
    ├── selectedMatch: {
    │   ├── whaleIndividualId: string
    │   ├── isNewWhale: boolean
    │   ├── userConfirmed: boolean
    │   └── confirmationTime: timestamp
    ├── modelVersions: {
    │   ├── classifier: string (e.g., "resnet50_v2")
    │   └── matcher: string (e.g., "flukes_v1")
    ├── classifiedAt: timestamp
    └── classification_history: [
        {
          predictedSpecies: string,
          matchedId: string,
          modelVersion: string,
          timestamp: timestamp
        }
      ]
```

---

## Frontend Updates

### Upload Flow Integration

```
[Phase 1 Upload Complete]
    ↓
[Automatic Classification]
    ├─→ Show Spinner: "Analyzing whale species..."
    ├─→ Display Predicted Species with Confidence
    ├─→ Show Top-3 Species Alternatives
    ↓
[Show Matching Results]
    ├─→ "Searching for matching whales..."
    ├─→ Display Top-3 Matches
    ├─→ Show Photos of Matched Whales
    ├─→ User Selects: Match / Different / New Whale
    ↓
[Confirmation]
    └─→ "Analysis complete! Whale profile created/updated"
```

### UI Components

#### Classification Results Card
```
┌─────────────────────────────────────┐
│ 🤖 AI Classification                │
├─────────────────────────────────────┤
│ Species: Humpback Whale             │
│ Confidence: 92%  [████████░░]       │
│                                     │
│ Other possibilities:                │
│ • Fin Whale (6%)                    │
│ • Blue Whale (2%)                   │
│                                     │
│ ✓ Looks correct  ✗ Incorrect       │
└─────────────────────────────────────┘
```

#### Whale Match Suggestions
```
┌─────────────────────────────────────┐
│ 🐋 Possible Matches                 │
├─────────────────────────────────────┤
│ #1 Helen (87% match)                │
│    └─ Last seen: Mar 15, 47 photos  │
│    └─ [View Profile] [Match This]   │
│                                     │
│ #2 Fred (64% match)                 │
│    └─ Last seen: Feb 20, 12 photos  │
│    └─ [View Profile] [Match This]   │
│                                     │
│ ⊕ This is a new whale              │
│   └─ [Name It] [Save As New]        │
└─────────────────────────────────────┘
```

#### Whale Profile Page
```
Whale: Helen
Species: Humpback
First Seen: Jun 15, 2023
Last Seen: Mar 15, 2026
Photos: 47

Distinctive Features:
• Scar on left fluke
• White tail markings

Known Locations:
• Gulf of Maine (summer)
• Caribbean (winter)

Recent Sightings:
[Timeline with photos and dates]

[All Photos Gallery]
```

---

## Model Training Pipeline

### 1. Initial Setup

**Option A: Pre-trained Model**
- Download HappyWhale fluke matcher (if publicly available)
- License/attribution: Academic research collaboration
- Accuracy: ~85-95% for humpback individuals

**Option B: Transfer Learning**
- Start with ImageNet ResNet50
- Fine-tune on collected whale images
- Slower initial accuracy, improves over time

### 2. Continuous Improvement

```
Monthly Retraining Loop:
1. Collect user corrections from feedback collection
2. Identify misclassifications (species + matching)
3. Retrain on collected dataset (1000+ samples)
4. Test on holdout validation set
5. If accuracy improves: deploy new model version
6. Keep model version history for debugging
```

---

## Implementation Timeline

### Week 1-2: Model Setup
- [ ] Choose classifier model (ResNet50 + fine-tuning)
- [ ] Download or create matching model
- [ ] Set up ML training infrastructure (Cloud Vertex AI or local)
- [ ] Create model versioning system

### Week 2-3: Backend Integration
- [ ] Implement `/classify/predict-species` endpoint
- [ ] Implement `/classify/match-whale` endpoint
- [ ] Add whale individual CRUD endpoints
- [ ] Implement feedback collection

### Week 3-4: Frontend Integration
- [ ] Show classification results post-upload
- [ ] Display whale matching suggestions
- [ ] Add whale profile page
- [ ] User confirmation UI for matches
- [ ] Browsable whale database

### Week 4-5: Testing & Refinement
- [ ] Test accuracy on sample images
- [ ] Evaluate match quality
- [ ] Optimize performance (inference time)
- [ ] User acceptance testing

### Week 5-6: Deployment & Monitoring
- [ ] Deploy to production
- [ ] Monitor classification accuracy
- [ ] Set up automated retraining pipeline
- [ ] Documentation & user guide

---

## Performance Considerations

### Image Processing
- Resize to 224×224 for ResNet50 (standard)
- Crop to whale region for better features
- Batch processing for efficiency

### Model Inference
- **Expected latency**: 
  - Species classification: 200-500ms
  - Whale matching: 1-2 seconds (matching against 100+ known whales)
- Cloud Run with GPU: `/gpu` suffix on Cloud Run service
- Cache model in memory for faster inference

### Database Queries
- Index on `species` + `photoCount` for matching
- Pagination for large whale galleries
- Search tags for full-text search on features

---

## Cost Estimation (Phase 2)

### Model Training (Monthly)
- Vertex AI Training: ~$10-20
- Storage for training data: ~$0.50
- Model artifact storage: ~$0.20

### Inference (for 1000 uploads/month)
- Cloud Run with GPU: ~$5-10 per 1000 requests
- Storage bandwidth for model: ~$0.20

### Data Storage Increases
- Classification metadata: +$0.10
- Whale individual profiles: +$0.05
- Feedback collection: +$0.05

**Phase 2 Additional Cost**: ~$15-30/month

---

## Monitoring & Metrics

### Classification Metrics
- Species classification accuracy (%)
- Species confidence distribution
- Top-1, Top-3, Top-5 accuracy
- Per-species accuracy breakdown

### Matching Metrics
- Whale identification accuracy (%)
- Match confidence scores
- False positive rate
- Average matching time (ms)

### Data Quality
- User correction rate (%)
- Feedback submission rate
- New whale creation rate
- Individual whale re-sighting rate

### Service Health
- Inference latency (95th percentile)
- Model serving uptime (%)
- Cache hit rate (%)

---

## Future Enhancements (Phase 3+)

- Mobile app with real-time camera classification
- Acoustic whale identification (if audio available)
- Shark fin matching (for other marine species)
- Whale population dynamics modeling
- Conservation status tracking
- Integration with marine research organizations
- Public whale database API
- Community contributions & citizen science

---

## References

- HappyWhale: http://www.happywhale.com (whale flukes dataset)
- NOAA Marine Life: https://www.fisheries.noaa.gov/
- ResNet50 TensorFlow: https://www.tensorflow.org/api_docs/python/tf/keras/applications/ResNet50
- Fluke matching paper (if available)
- OpenCV documentation: https://docs.opencv.org/

---

## Related Files

- Phase 1 docs: [PHASE1.md](./PHASE1.md)
- Backend app: [app.py](../backend/app.py)
- ML models: [backend/models/](../backend/models/)
- Frontend: [frontend/public/](../frontend/public/)
- Training pipeline: [scripts/train_model.py](../scripts/train_model.py) (to be created)
