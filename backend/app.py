from flask import Flask, jsonify, request
from flask_cors import CORS
import google.auth
from google.cloud import firestore
from google.cloud import storage
from google.auth.transport.requests import Request
from datetime import datetime, timedelta
import os
import logging
import uuid
import re

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Enable CORS for all routes
CORS(app, resources={r"/api/*": {"origins": "*"}})

# Configuration (must come before GCP Clients)
PROJECT_ID = os.getenv('GCP_PROJECT_ID', '')
ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
FIRESTORE_DB = os.getenv('FIRESTORE_DATABASE', '(default)')
UPLOADS_BUCKET = os.getenv('STORAGE_BUCKET', '')
WHALE_IMAGES_BUCKET = os.getenv('WHALE_IMAGES_BUCKET', '')
SIGNING_SERVICE_ACCOUNT = os.getenv('SIGNING_SERVICE_ACCOUNT', '')
SIGNING_SCOPES = ['https://www.googleapis.com/auth/cloud-platform']

# GCP Clients (initialized after PROJECT_ID is set)
firestore_client = firestore.Client(
    project=PROJECT_ID if PROJECT_ID else None,
    database=FIRESTORE_DB
)
storage_client = storage.Client(project=PROJECT_ID) if PROJECT_ID else storage.Client()
signing_credentials, _ = google.auth.default(scopes=SIGNING_SCOPES)

# Constants for validation
VALID_SPECIES = ['humpback', 'fin', 'blue', 'gray', 'right', 'sperm', 'beluga', 'orca', 'other']
VALID_BEHAVIORS = ['feeding', 'breaching', 'fluking', 'spyhopping', 'traveling', 'resting']
VALID_WATER_CONDITIONS = ['excellent', 'good', 'fair', 'poor']
VALID_CONFIDENCE = ['high', 'medium', 'low']


def generate_upload_signed_url(blob, expiration_minutes=15):
    """Generate a signed upload URL locally or on Cloud Run.

    Service account JSON credentials can sign directly. Cloud Run metadata
    credentials require IAM-based signing using the runtime service account and
    an access token.
    """
    credentials = signing_credentials

    if hasattr(credentials, 'signer') and getattr(credentials, 'service_account_email', None):
        return blob.generate_signed_url(
            version='v4',
            expiration=timedelta(minutes=expiration_minutes),
            method='PUT'
        )

    if not getattr(credentials, 'token', None):
        credentials.refresh(Request())

    service_account_email = SIGNING_SERVICE_ACCOUNT or getattr(credentials, 'service_account_email', None)
    if not service_account_email:
        raise RuntimeError('No service account email available for IAM-based URL signing')

    return blob.generate_signed_url(
        version='v4',
        expiration=timedelta(minutes=expiration_minutes),
        method='PUT',
        service_account_email=service_account_email,
        access_token=credentials.token,
    )


def generate_download_signed_url(blob, expiration_minutes=60):
    """Generate a signed download URL locally or on Cloud Run."""
    credentials = signing_credentials

    if hasattr(credentials, 'signer') and getattr(credentials, 'service_account_email', None):
        return blob.generate_signed_url(
            version='v4',
            expiration=timedelta(minutes=expiration_minutes),
            method='GET'
        )

    if not getattr(credentials, 'token', None):
        credentials.refresh(Request())

    service_account_email = SIGNING_SERVICE_ACCOUNT or getattr(credentials, 'service_account_email', None)
    if not service_account_email:
        raise RuntimeError('No service account email available for IAM-based URL signing')

    return blob.generate_signed_url(
        version='v4',
        expiration=timedelta(minutes=expiration_minutes),
        method='GET',
        service_account_email=service_account_email,
        access_token=credentials.token,
    )


def attach_image_url(document_data):
    """Attach a signed read URL for a stored whale image when available."""
    gcs_path = document_data.get('storage', {}).get('gcsPath')
    if not gcs_path:
        document_data['imageUrl'] = None
        return document_data

    try:
        bucket = storage_client.bucket(WHALE_IMAGES_BUCKET)
        blob = bucket.blob(gcs_path)
        document_data['imageUrl'] = generate_download_signed_url(blob)
    except Exception as exc:
        logger.warning(f"Could not generate image URL for {gcs_path}: {exc}")
        document_data['imageUrl'] = None

    return document_data


def parse_metadata_timestamp(value):
    """Parse metadata timestamps that may be stored as ISO strings or datetimes."""
    if not value:
        return None

    if isinstance(value, datetime):
        return value

    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace('Z', '+00:00'))
        except ValueError:
            return None

    return None

# ============== Metadata Validation ==============
def validate_whale_metadata(metadata):
    """Validate whale image metadata"""
    errors = []
    
    # Validate species
    if 'speciesType' in metadata:
        if metadata['speciesType'] not in VALID_SPECIES:
            errors.append(f"Invalid species. Must be one of: {', '.join(VALID_SPECIES)}")
    
    # Validate coordinates
    if 'location_lat' in metadata:
        try:
            lat = float(metadata['location_lat'])
            if lat < -90 or lat > 90:
                errors.append("Latitude must be between -90 and 90")
        except (ValueError, TypeError):
            errors.append("Latitude must be a valid number")
    
    if 'location_long' in metadata:
        try:
            lng = float(metadata['location_long'])
            if lng < -180 or lng > 180:
                errors.append("Longitude must be between -180 and 180")
        except (ValueError, TypeError):
            errors.append("Longitude must be a valid number")
    
    # Validate behaviors
    if 'behavior' in metadata and isinstance(metadata['behavior'], list):
        for behavior in metadata['behavior']:
            if behavior not in VALID_BEHAVIORS:
                errors.append(f"Invalid behavior '{behavior}'. Must be one of: {', '.join(VALID_BEHAVIORS)}")
    
    # Validate pod size
    if 'podSize' in metadata:
        try:
            pod_size = int(metadata['podSize'])
            if pod_size < 1:
                errors.append("Pod size must be at least 1")
        except (ValueError, TypeError):
            errors.append("Pod size must be an integer")
    
    # Validate confidence
    if 'confidence' in metadata:
        if metadata['confidence'] not in VALID_CONFIDENCE:
            errors.append(f"Invalid confidence. Must be one of: {', '.join(VALID_CONFIDENCE)}")
    
    # Validate file size (max 50MB for images)
    if 'fileSize' in metadata:
        try:
            file_size = int(metadata['fileSize'])
            if file_size > 50 * 1024 * 1024:  # 50MB
                errors.append("File size cannot exceed 50MB")
        except (ValueError, TypeError):
            errors.append("File size must be an integer")
    
    return errors

def generate_search_tags(metadata):
    """Generate searchable tags from metadata"""
    tags = []
    
    if 'speciesType' in metadata:
        tags.append(metadata['speciesType'])
    
    if 'region' in metadata:
        tags.append(metadata['region'])
    
    if 'visibleFeatures' in metadata:
        # Split features into individual words for search
        features = str(metadata['visibleFeatures']).lower().split()
        tags.extend(features[:5])  # Limit to 5 features
    
    if 'behavior' in metadata and isinstance(metadata['behavior'], list):
        tags.extend(metadata['behavior'])
    
    if 'whaleName' in metadata:
        tags.append(str(metadata['whaleName']).lower())
    
    return list(set(tags))  # Remove duplicates

# ============== Whale Images - Phase 1 Endpoints ==============

@app.route('/api/images/request-upload', methods=['POST'])
def request_image_upload():
    """
    Request a presigned URL for uploading a whale image.
    
    Request body:
    {
        "fileName": "whale_photo.jpg",
        "fileSize": 5242880,
        "mimeType": "image/jpeg",
        "metadata": {
            "speciesType": "humpback",
            "location_lat": 42.3601,
            "location_long": -71.0589,
            "region": "alaska",
            "behavior": ["breaching"],
            "podSize": 3,
            "visibleFeatures": "distinctive scar on left fluke",
            "confidence": "high",
            "observerName": "Dr. Sarah Johnson",
            "vesselName": "Whale Watch Explorer",
            "whaleName": "Helen",
            "timestamp": "2026-03-21T10:30:00Z",
            "notes": "Additional observations"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'Request body is required'}), 400
        
        # Validate required fields
        required_fields = ['fileName', 'fileSize', 'mimeType']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({'error': f'{field} is required'}), 400
        
        # Validate metadata if provided
        metadata = data.get('metadata', {})
        validation_errors = validate_whale_metadata(data)
        if validation_errors:
            return jsonify({'error': 'Invalid metadata', 'details': validation_errors}), 400
        
        # Generate unique image ID
        image_id = str(uuid.uuid4())
        
        # Create Firestore document stub
        timestamp = datetime.utcnow()
        image_doc = {
            'imageId': image_id,
            'metadata': metadata,
            'uploadStatus': 'pending',
            'createdAt': timestamp,
            'storage': {
                'fileName': data['fileName'],
                'fileSizeBytes': data['fileSize'],
                'mimeType': data['mimeType'],
                'gcsPath': None,
            }
        }
        
        firestore_client.collection('whale_images').document(image_id).set(image_doc)
        logger.info(f"Created image document stub: {image_id}")
        
        # Generate presigned URL (15 minute expiration)
        gcs_path = f"whale_images/{image_id}/{data['fileName']}"
        bucket = storage_client.bucket(WHALE_IMAGES_BUCKET)
        blob = bucket.blob(gcs_path)
        
        presigned_url = generate_upload_signed_url(blob, expiration_minutes=15)
        
        return jsonify({
            'imageId': image_id,
            'presignedUrl': presigned_url,
            'expiresIn': 900,  # 15 minutes in seconds
            'uploadPath': gcs_path
        }), 200
    
    except Exception as e:
        logger.error(f"Error requesting image upload: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/images/confirm-upload', methods=['POST'])
def confirm_image_upload():
    """
    Confirm that an image has been successfully uploaded to Cloud Storage.
    
    Request body:
    {
        "imageId": "uuid-here",
        "gcsPath": "whale_images/uuid/filename.jpg"
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'imageId' not in data or 'gcsPath' not in data:
            return jsonify({'error': 'imageId and gcsPath are required'}), 400
        
        image_id = data['imageId']
        gcs_path = data['gcsPath']
        
        # Verify file exists in Cloud Storage
        bucket = storage_client.bucket(WHALE_IMAGES_BUCKET)
        blob = bucket.blob(gcs_path)
        
        if not blob.exists():
            logger.warning(f"File not found in storage: {gcs_path}")
            return jsonify({'error': 'File not found in Cloud Storage'}), 400
        
        # Update Firestore document
        update_data = {
            'uploadStatus': 'complete',
            'storage.gcsPath': gcs_path,
            'storage.uploadedAt': datetime.utcnow(),
            'storage.fileSizeActual': blob.size,
            'searchTags': firestore.ArrayUnion(generate_search_tags(
                firestore_client.collection('whale_images').document(image_id).get().to_dict().get('metadata', {})
            ))
        }
        
        firestore_client.collection('whale_images').document(image_id).update(update_data)
        logger.info(f"Confirmed upload for image: {image_id}")
        
        return jsonify({
            'success': True,
            'imageId': image_id,
            'message': 'Upload confirmed successfully'
        }), 200
    
    except Exception as e:
        logger.error(f"Error confirming upload: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/images/search', methods=['GET'])
def search_whale_images():
    """
    Search whale images with filters.
    
    Query parameters:
    - species: Filter by species (e.g., 'humpback')
    - region: Filter by region
    - startDate: ISO format start date
    - endDate: ISO format end date
    - behavior: Filter by behavior
    - whaleName: Filter by whale name
    - observerName: Filter by observer name
    - limit: Number of results (default 20, max 100)
    - offset: Pagination offset (default 0)
    """
    try:
        # Get query parameters
        species = request.args.get('species', '').lower()
        region = request.args.get('region', '').lower()
        start_date = request.args.get('startDate')
        end_date = request.args.get('endDate')
        behavior = request.args.get('behavior', '').lower()
        whale_name = request.args.get('whaleName', '').lower()
        observer_name = request.args.get('observerName', '')
        
        limit = min(int(request.args.get('limit', 20)), 100)  # Max 100
        offset = int(request.args.get('offset', 0))
        
        # Apply date filters (if provided)
        start_dt = None
        if start_date:
            try:
                start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            except ValueError:
                return jsonify({'error': 'Invalid startDate format. Use ISO format.'}), 400

        end_dt = None
        if end_date:
            try:
                end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            except ValueError:
                return jsonify({'error': 'Invalid endDate format. Use ISO format.'}), 400

        docs = firestore_client.collection('whale_images').where('uploadStatus', '==', 'complete').stream()
        
        results = []
        for doc in docs:
            result = doc.to_dict()
            metadata = result.get('metadata', {})

            if species and str(metadata.get('speciesType', '')).lower() != species:
                continue

            if region and str(metadata.get('region', '')).lower() != region:
                continue

            if behavior:
                behaviors = [str(item).lower() for item in metadata.get('behavior', [])]
                if behavior not in behaviors:
                    continue

            if observer_name and str(metadata.get('observerName', '')) != observer_name:
                continue

            if whale_name and str(metadata.get('whaleName', '')).lower() != whale_name:
                continue

            metadata_timestamp = parse_metadata_timestamp(metadata.get('timestamp'))
            if start_dt and (metadata_timestamp is None or metadata_timestamp < start_dt):
                continue

            if end_dt and (metadata_timestamp is None or metadata_timestamp > end_dt):
                continue

            result['imageId'] = doc.id
            results.append(attach_image_url(result))

        results.sort(key=lambda item: item.get('createdAt', datetime.min), reverse=True)
        results = results[offset:offset + limit]
        
        return jsonify({
            'images': results,
            'count': len(results),
            'offset': offset,
            'limit': limit,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    
    except Exception as e:
        logger.error(f"Error searching images: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/images/<image_id>', methods=['GET'])
def get_whale_image(image_id):
    """Get image metadata by ID"""
    try:
        doc = firestore_client.collection('whale_images').document(image_id).get()
        
        if not doc.exists:
            return jsonify({'error': 'Image not found'}), 404
        
        result = doc.to_dict()
        result['imageId'] = doc.id
        result = attach_image_url(result)
        
        return jsonify(result), 200
    
    except Exception as e:
        logger.error(f"Error getting image: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/images/<image_id>', methods=['DELETE'])
def delete_whale_image(image_id):
    """Delete image by ID"""
    try:
        doc = firestore_client.collection('whale_images').document(image_id).get()
        
        if not doc.exists:
            return jsonify({'error': 'Image not found'}), 404
        
        # Get GCS path and delete the file
        doc_data = doc.to_dict()
        gcs_path = doc_data.get('storage', {}).get('gcsPath')
        
        if gcs_path:
            bucket = storage_client.bucket(WHALE_IMAGES_BUCKET)
            blob = bucket.blob(gcs_path)
            if blob.exists():
                blob.delete()
                logger.info(f"Deleted file: {gcs_path}")
        
        # Delete Firestore document
        firestore_client.collection('whale_images').document(image_id).delete()
        logger.info(f"Deleted document: {image_id}")
        
        return jsonify({
            'imageId': image_id,
            'message': 'Image deleted successfully'
        }), 204
    
    except Exception as e:
        logger.error(f"Error deleting image: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'backend-api',
        'environment': ENVIRONMENT,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/api/data', methods=['GET'])
def get_data():
    """Fetch sample data"""
    try:
        data = [
            {'id': 1, 'name': 'Item 1', 'value': 100},
            {'id': 2, 'name': 'Item 2', 'value': 200},
            {'id': 3, 'name': 'Item 3', 'value': 300}
        ]
        return jsonify({
            'message': 'Sample data from backend',
            'data': data,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Error fetching data: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/items', methods=['GET'])
def list_items():
    """List items from Firestore"""
    try:
        docs = firestore_client.collection('items').stream()
        items = []
        for doc in docs:
            item = doc.to_dict()
            item['id'] = doc.id
            items.append(item)
        
        return jsonify({
            'items': items,
            'count': len(items),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Error listing items: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/items', methods=['POST'])
def create_item():
    """Create a new item in Firestore"""
    try:
        data = request.get_json()
        
        if not data or 'title' not in data or 'value' not in data:
            return jsonify({'error': 'Title and value are required'}), 400
        
        new_item = {
            'title': data['title'],
            'value': data['value'],
            'createdAt': datetime.utcnow(),
            'updatedAt': datetime.utcnow()
        }
        
        doc_ref = firestore_client.collection('items').document()
        doc_ref.set(new_item)
        
        return jsonify({
            'id': doc_ref.id,
            **new_item,
            'createdAt': new_item['createdAt'].isoformat(),
            'updatedAt': new_item['updatedAt'].isoformat()
        }), 201
    except Exception as e:
        logger.error(f"Error creating item: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/items/<item_id>', methods=['GET'])
def get_item(item_id):
    """Get a specific item from Firestore"""
    try:
        doc = firestore_client.collection('items').document(item_id).get()
        
        if not doc.exists:
            return jsonify({'error': 'Item not found'}), 404
        
        item = doc.to_dict()
        item['id'] = doc.id
        
        return jsonify(item), 200
    except Exception as e:
        logger.error(f"Error getting item: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/items/<item_id>', methods=['PUT'])
def update_item(item_id):
    """Update an item in Firestore"""
    try:
        data = request.get_json()
        
        update_data = {}
        if 'title' in data:
            update_data['title'] = data['title']
        if 'value' in data:
            update_data['value'] = data['value']
        
        update_data['updatedAt'] = datetime.utcnow()
        
        firestore_client.collection('items').document(item_id).update(update_data)
        
        return jsonify({
            'id': item_id,
            'message': 'Item updated successfully',
            **update_data,
            'updatedAt': update_data['updatedAt'].isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Error updating item: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/items/<item_id>', methods=['DELETE'])
def delete_item(item_id):
    """Delete an item from Firestore"""
    try:
        firestore_client.collection('items').document(item_id).delete()
        
        return jsonify({
            'id': item_id,
            'message': 'Item deleted successfully'
        }), 200
    except Exception as e:
        logger.error(f"Error deleting item: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/upload', methods=['POST'])
def upload_file():
    """Upload a file to Cloud Storage"""
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        bucket = storage_client.bucket(UPLOADS_BUCKET)
        blob = bucket.blob(f"uploads/{datetime.utcnow().timestamp()}-{file.filename}")
        blob.upload_from_string(file.read(), content_type=file.content_type)
        
        return jsonify({
            'message': 'File uploaded successfully',
            'bucket': UPLOADS_BUCKET,
            'path': blob.name,
            'url': blob.public_url
        }), 201
    except Exception as e:
        logger.error(f"Error uploading file: {e}")
        return jsonify({'error': str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not Found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal error: {error}")
    return jsonify({'error': 'Internal Server Error'}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=ENVIRONMENT == 'development')
