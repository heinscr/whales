// Whale Images Management Module
const WhaleImages = (() => {
  // Constants
  const SPECIES_OPTIONS = ['humpback', 'fin', 'blue', 'gray', 'right', 'sperm', 'beluga', 'orca', 'other'];
  const BEHAVIOR_OPTIONS = ['feeding', 'breaching', 'fluking', 'spyhopping', 'traveling', 'resting'];
  const WATER_CONDITIONS = ['excellent', 'good', 'fair', 'poor'];
  const CONFIDENCE_LEVELS = ['high', 'medium', 'low'];

  // State
  let uploadProgress = {};
  let currentSearchFilters = {};

  // ============ Upload Functions ============

  async function requestUpload(file, metadata) {
    try {
      const requestBody = {
        fileName: file.name,
        fileSize: file.size,
        mimeType: file.type,
        metadata: metadata
      };

      const response = await fetch(`${window.config.apiGatewayUrl}/images/request-upload`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to request upload');
      }

      const data = await response.json();
      return data;  // Returns { imageId, presignedUrl, expiresIn, uploadPath }
    } catch (error) {
      console.error('Error requesting upload:', error);
      throw error;
    }
  }

  async function uploadFileToCloud(presignedUrl, file, imageId) {
    try {
      const xhr = new XMLHttpRequest();

      // Track upload progress
      return new Promise((resolve, reject) => {
        xhr.upload.addEventListener('progress', (e) => {
          if (e.lengthComputable) {
            const percentComplete = (e.loaded / e.total) * 100;
            uploadProgress[imageId] = percentComplete;
            updateUploadProgress(imageId, percentComplete);
          }
        });

        xhr.addEventListener('load', async () => {
          if (xhr.status === 200) {
            resolve({
              imageId: imageId,
              status: 'uploaded'
            });
          } else {
            reject(new Error(`Upload failed with status ${xhr.status}`));
          }
        });

        xhr.addEventListener('error', () => {
          reject(new Error('Upload error'));
        });

        xhr.open('PUT', presignedUrl);
        xhr.setRequestHeader('Content-Type', file.type);
        xhr.send(file);
      });
    } catch (error) {
      console.error('Error uploading file:', error);
      throw error;
    }
  }

  async function confirmUpload(imageId, gcsPath) {
    try {
      const response = await fetch(`${window.config.apiGatewayUrl}/images/confirm-upload`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          imageId: imageId,
          gcsPath: gcsPath
        })
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to confirm upload');
      }

      return await response.json();
    } catch (error) {
      console.error('Error confirming upload:', error);
      throw error;
    }
  }

  async function uploadWhaleImage(file, metadata) {
    try {
      // Step 1: Request presigned URL
      console.log('Step 1: Requesting presigned URL...');
      const uploadRequest = await requestUpload(file, metadata);
      const imageId = uploadRequest.imageId;
      const presignedUrl = uploadRequest.presignedUrl;
      const gcsPath = uploadRequest.uploadPath;

      // Step 2: Upload file directly to Cloud Storage
      console.log('Step 2: Uploading file to Cloud Storage...');
      await uploadFileToCloud(presignedUrl, file, imageId);

      // Step 3: Confirm upload
      console.log('Step 3: Confirming upload...');
      await confirmUpload(imageId, gcsPath);

      console.log('Upload complete for image:', imageId);
      return {
        success: true,
        imageId: imageId,
        message: 'Image uploaded successfully'
      };
    } catch (error) {
      console.error('Error in upload workflow:', error);
      throw error;
    }
  }

  // ============ Search Functions ============

  async function searchImages(filters = {}, limit = 20, offset = 0) {
    try {
      const params = new URLSearchParams();

      if (filters.species) params.append('species', filters.species);
      if (filters.region) params.append('region', filters.region);
      if (filters.startDate) params.append('startDate', filters.startDate);
      if (filters.endDate) params.append('endDate', filters.endDate);
      if (filters.behavior) params.append('behavior', filters.behavior);
      if (filters.whaleName) params.append('whaleName', filters.whaleName);
      if (filters.observerName) params.append('observerName', filters.observerName);
      
      params.append('limit', limit);
      params.append('offset', offset);

      const queryString = params.toString();
      const url = `${window.config.apiGatewayUrl}/images/search${queryString ? '?' + queryString : ''}`;

      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Search failed');
      }

      return await response.json();
    } catch (error) {
      console.error('Error searching images:', error);
      throw error;
    }
  }

  async function getImageDetails(imageId) {
    try {
      const response = await fetch(`${window.config.apiGatewayUrl}/images/${imageId}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error('Failed to fetch image details');
      }

      return await response.json();
    } catch (error) {
      console.error('Error fetching image details:', error);
      throw error;
    }
  }

  async function deleteImage(imageId) {
    try {
      const response = await fetch(`${window.config.apiGatewayUrl}/images/${imageId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to delete image');
      }

      return { success: true, imageId: imageId };
    } catch (error) {
      console.error('Error deleting image:', error);
      throw error;
    }
  }

  // ============ UI Helper Functions ============

  function updateUploadProgress(imageId, percent) {
    const progressBar = document.getElementById(`progress-${imageId}`);
    if (progressBar) {
      progressBar.style.width = percent + '%';
      progressBar.textContent = Math.round(percent) + '%';
    }
  }

  function getSpeciesOptions() {
    return SPECIES_OPTIONS;
  }

  function getBehaviorOptions() {
    return BEHAVIOR_OPTIONS;
  }

  function getWaterConditions() {
    return WATER_CONDITIONS;
  }

  function getConfidenceLevels() {
    return CONFIDENCE_LEVELS;
  }

  // ============ Public API ============

  return {
    uploadWhaleImage,
    searchImages,
    getImageDetails,
    deleteImage,
    getSpeciesOptions,
    getBehaviorOptions,
    getWaterConditions,
    getConfidenceLevels,
    updateUploadProgress
  };
})();
