// Application Logic
document.addEventListener('DOMContentLoaded', async function() {
  // Wait a moment for config to initialize from server
  await new Promise(resolve => setTimeout(resolve, 500));
  
  checkFrontendHealth();
  checkAPIGatewayHealth();
  fetchItems();

  // Refresh status every 30 seconds
  setInterval(checkFrontendHealth, 30000);
  setInterval(checkAPIGatewayHealth, 30000);
});

// ============ Tab Navigation ============
function switchTab(tabName) {
  // Hide all tabs
  document.querySelectorAll('.tab-content').forEach(tab => {
    tab.classList.remove('active');
  });

  // Remove active class from all buttons
  document.querySelectorAll('.tab-button').forEach(btn => {
    btn.classList.remove('active');
  });

  // Show selected tab
  document.getElementById(tabName + '-tab').classList.add('active');
  event.target.classList.add('active');
}

// ============ System Health Check ============
async function checkFrontendHealth() {
  try {
    const response = await fetch('/health');
    const data = await response.json();
    
    const element = document.getElementById('frontend-health');
    element.textContent = `Status: ${data.status}`;
    element.parentElement.classList.add('healthy');
  } catch (error) {
    document.getElementById('frontend-health').textContent = 'Status: Error - Unreachable';
    document.getElementById('frontend-status').classList.add('unhealthy');
  }
}

async function checkAPIGatewayHealth() {
  try {
    const data = await API.health();
    
    const element = document.getElementById('api-gateway-health');
    element.textContent = `Status: ${data.status}`;
    element.parentElement.classList.add('healthy');
  } catch (error) {
    document.getElementById('api-gateway-health').textContent = 'Status: Unreachable';
    document.getElementById('api-gateway-status').classList.add('unhealthy');
  }
}

// ============ Whale Image Upload ============
function updateFileInfo() {
  const fileInput = document.getElementById('imageFile');
  const fileInfo = document.getElementById('fileInfo');
  
  if (fileInput.files.length > 0) {
    const file = fileInput.files[0];
    const sizeMB = (file.size / (1024 * 1024)).toFixed(2);
    fileInfo.textContent = `${file.name} (${sizeMB} MB)`;
  }
}

async function handleWhaleImageUpload(event) {
  event.preventDefault();

  const fileInput = document.getElementById('imageFile');
  const file = fileInput.files[0];

  if (!file) {
    alert('Please select an image file');
    return;
  }

  // Collect metadata
  const behaviors = Array.from(document.querySelectorAll('input[name="behavior"]:checked'))
    .map(cb => cb.value);

  const rawMetadata = {
    speciesType: document.getElementById('speciesType').value,
    whaleName: document.getElementById('whaleName').value,
    confidence: document.getElementById('confidence').value,
    podSize: document.getElementById('podSize').value,
    location_lat: document.getElementById('location_lat').value,
    location_long: document.getElementById('location_long').value,
    region: document.getElementById('region').value,
    behavior: behaviors,
    visibleFeatures: document.getElementById('visibleFeatures').value,
    waterConditions: document.getElementById('waterConditions').value,
    timeOfDay: document.getElementById('timeOfDay').value,
    observerName: document.getElementById('observerName').value,
    vesselName: document.getElementById('vesselName').value,
    notes: document.getElementById('notes').value,
    timestamp: new Date().toISOString()
  };

  const metadata = Object.fromEntries(
    Object.entries(rawMetadata).flatMap(([key, value]) => {
      if (Array.isArray(value)) {
        return value.length > 0 ? [[key, value]] : [];
      }

      if (typeof value === 'string') {
        const trimmed = value.trim();
        if (!trimmed) {
          return [];
        }

        if (key === 'podSize') {
          return [[key, parseInt(trimmed, 10)]];
        }

        if (key === 'location_lat' || key === 'location_long') {
          return [[key, parseFloat(trimmed)]];
        }

        return [[key, trimmed]];
      }

      return value === undefined || value === null ? [] : [[key, value]];
    })
  );

  // Show progress
  document.getElementById('upload-progress').classList.remove('hidden');
  document.getElementById('upload-status').classList.add('hidden');
  
  const progressContainer = document.getElementById('progress-container');
  const progressHTML = `
    <div class="upload-item">
      <p>${file.name}</p>
      <div class="progress-bar-bg">
        <div class="progress-bar" id="progress-${file.name}"></div>
      </div>
    </div>
  `;
  progressContainer.innerHTML = progressHTML;

  try {
    const result = await WhaleImages.uploadWhaleImage(file, metadata);
    
    // Show success
    document.getElementById('upload-status').classList.remove('hidden');
    document.getElementById('upload-status').innerHTML = `
      <div class="status-success">
        <h3>✓ Upload Successful!</h3>
        <p>Image ID: ${result.imageId}</p>
        <p>Your whale image has been uploaded and cataloged.</p>
      </div>
    `;
    
    // Reset form
    document.getElementById('whale-upload-form').reset();
    document.getElementById('fileInfo').textContent = '';
    
  } catch (error) {
    document.getElementById('upload-status').classList.remove('hidden');
    document.getElementById('upload-status').innerHTML = `
      <div class="status-error">
        <h3>✗ Upload Failed</h3>
        <p>${error.message}</p>
      </div>
    `;
  }
}

// ============ Search /Gallery ============

let currentSearchPage = 0;
const SEARCH_LIMIT = 12;

async function performSearch() {
  currentSearchPage = 0;
  await loadSearchResults();
}

async function loadSearchResults() {
  const resultsContainer = document.getElementById('search-results');
  resultsContainer.innerHTML = '<p>Searching...</p>';

  try {
    const filters = {
      species: document.getElementById('search-species').value,
      region: document.getElementById('search-region').value,
      whaleName: document.getElementById('search-whale-name').value,
      startDate: document.getElementById('search-start-date').value ? 
        new Date(document.getElementById('search-start-date').value).toISOString() : '',
      endDate: document.getElementById('search-end-date').value ? 
        new Date(document.getElementById('search-end-date').value).toISOString() : '',
      behavior: document.getElementById('search-behavior').value
    };

    const result = await WhaleImages.searchImages(
      filters,
      SEARCH_LIMIT,
      currentSearchPage * SEARCH_LIMIT
    );

    if (!result.images || result.images.length === 0) {
      resultsContainer.innerHTML = '<p class="no-results">No images found matching your criteria.</p>';
      document.getElementById('pagination').classList.add('hidden');
      return;
    }

    // Render gallery
    const galleryHTML = result.images.map(image => `
      <div class="gallery-item" onclick="showImageDetails('${image.imageId}')">
        <div class="gallery-media">
          ${image.imageUrl ? `
            <img
              class="gallery-image"
              src="${image.imageUrl}"
              alt="${image.metadata.whaleName || 'Whale image'}"
              loading="lazy"
              onerror="this.outerHTML='&lt;div class=&quot;image-placeholder&quot;&gt;&lt;p&gt;🐋&lt;/p&gt;&lt;small&gt;${image.metadata.speciesType || 'Unknown'}&lt;/small&gt;&lt;/div&gt;'"
            />
          ` : `
            <div class="image-placeholder">
              <p>🐋</p>
              <small>${image.metadata.speciesType || 'Unknown'}</small>
            </div>
          `}
        </div>
        <div class="image-info">
          <p><strong>${image.metadata.whaleName || 'Unknown Whale'}</strong></p>
          <p class="image-date">${new Date(image.createdAt).toLocaleDateString()}</p>
          <p class="image-observer">${image.metadata.observerName || 'Unknown'}</p>
        </div>
      </div>
    `).join('');

    resultsContainer.innerHTML = `<div class="gallery">${galleryHTML}</div>`;

    // Show pagination if needed
    if (result.count >= SEARCH_LIMIT) {
      document.getElementById('pagination').classList.remove('hidden');
      document.getElementById('page-info').textContent = 
        `Page ${currentSearchPage + 1} (showing ${result.count} of results)`;
    } else {
      document.getElementById('pagination').classList.add('hidden');
    }

  } catch (error) {
    resultsContainer.innerHTML = `<p class="error">Error searching images: ${error.message}</p>`;
  }
}

async function showImageDetails(imageId) {
  try {
    const image = await WhaleImages.getImageDetails(imageId);
    
    const resultsContainer = document.getElementById('search-results');
    const details = `
      <div class="image-details-modal">
        <div class="modal-content">
          <button class="close-btn" onclick="closeImageDetails()">×</button>
          <h2>${image.metadata.whaleName || 'Whale Image'}</h2>
          ${image.imageUrl ? `<img class="detail-image" src="${image.imageUrl}" alt="${image.metadata.whaleName || 'Whale image'}">` : ''}
          <div class="details-row">
            <p><strong>Species:</strong> ${image.metadata.speciesType}</p>
            <p><strong>Pod Size:</strong> ${image.metadata.podSize || 'N/A'}</p>
          </div>
          <div class="details-row">
            <p><strong>Location:</strong> (${image.metadata.location_lat}, ${image.metadata.location_long})</p>
            <p><strong>Region:</strong> ${image.metadata.region || 'N/A'}</p>
          </div>
          <div class="details-row">
            <p><strong>Behavior:</strong> ${image.metadata.behavior?.join(', ') || 'N/A'}</p>
            <p><strong>Confidence:</strong> ${image.metadata.confidence}</p>
          </div>
          <p><strong>Features:</strong> ${image.metadata.visibleFeatures || 'N/A'}</p>
          <p><strong>Observer:</strong> ${image.metadata.observerName} (${image.metadata.vesselName})</p>
          <p><strong>Date:</strong> ${new Date(image.createdAt).toLocaleString()}</p>
          ${image.metadata.notes ? `<p><strong>Notes:</strong> ${image.metadata.notes}</p>` : ''}
          <button onclick="deleteImage('${imageId}')" class="btn btn-danger">Delete Image</button>
        </div>
      </div>
    `;
    
    resultsContainer.innerHTML += details;
  } catch (error) {
    alert('Error loading image details: ' + error.message);
  }
}

function closeImageDetails() {
  document.querySelector('.image-details-modal').remove();
}

async function deleteImage(imageId) {
  if (confirm('Are you sure you want to delete this image?')) {
    try {
      await WhaleImages.deleteImage(imageId);
      closeImageDetails();
      performSearch();
    } catch (error) {
      alert('Error deleting image: ' + error.message);
    }
  }
}

function clearSearchFilters() {
  document.getElementById('search-species').value = '';
  document.getElementById('search-region').value = '';
  document.getElementById('search-whale-name').value = '';
  document.getElementById('search-start-date').value = '';
  document.getElementById('search-end-date').value = '';
  document.getElementById('search-behavior').value = '';
  document.getElementById('search-results').innerHTML = '<p>Use filters above to search for whale images</p>';
  document.getElementById('pagination').classList.add('hidden');
}

function previousPage() {
  if (currentSearchPage > 0) {
    currentSearchPage--;
    loadSearchResults();
  }
}

function nextPage() {
  currentSearchPage++;
  loadSearchResults();
}

// ============ Legacy Data Management ============
async function fetchItems() {
  const container = document.getElementById('items-container');
  
  try {
    const data = await API.listItems();
    
    if (!data.items || data.items.length === 0) {
      container.innerHTML = '<p class="no-items">No items yet. Create one to get started!</p>';
      return;
    }

    const itemsHTML = data.items.map(item => `
      <div class="item-card">
        <div class="item-header">
          <h4>${escapeHtml(item.title)}</h4>
          <span class="item-value">$${item.value}</span>
        </div>
        <p class="item-id">ID: ${item.id}</p>
        <div class="item-actions">
          <button onclick="deleteItemConfirm('${item.id}')" class="btn btn-danger btn-small">Delete</button>
        </div>
      </div>
    `).join('');

    container.innerHTML = `
      <div class="items-list">
        <p class="items-count">Total items: ${data.items.length}</p>
        ${itemsHTML}
      </div>
    `;
  } catch (error) {
    container.innerHTML = `<p class="error">Error loading items: ${error.message}</p>`;
  }
}

async function createItem(event) {
  event.preventDefault();

  const title = document.getElementById('itemTitle').value;
  const value = parseFloat(document.getElementById('itemValue').value);

  try {
    await API.createItem({ title, value });
    hideCreateForm();
    clearForm();
    fetchItems();
  } catch (error) {
    alert(`Error creating item: ${error.message}`);
  }
}

async function deleteItemConfirm(id) {
  if (confirm('Are you sure you want to delete this item?')) {
    try {
      await API.deleteItem(id);
      fetchItems();
    } catch (error) {
      alert(`Error deleting item: ${error.message}`);
    }
  }
}

function showCreateForm() {
  document.getElementById('create-form').classList.remove('hidden');
  document.getElementById('itemTitle').focus();
}

function hideCreateForm() {
  document.getElementById('create-form').classList.add('hidden');
}

function clearForm() {
  document.getElementById('itemTitle').value = '';
  document.getElementById('itemValue').value = '';
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
