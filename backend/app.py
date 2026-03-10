from flask import Flask, jsonify, request
from flask_cors import CORS
from google.cloud import firestore
from google.cloud import storage
from datetime import datetime
import os
import logging

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

# GCP Clients (initialized after PROJECT_ID is set)
firestore_client = firestore.Client(
    project=PROJECT_ID if PROJECT_ID else None,
    database=FIRESTORE_DB
)
storage_client = storage.Client(project=PROJECT_ID) if PROJECT_ID else storage.Client()

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
