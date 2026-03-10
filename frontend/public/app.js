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
