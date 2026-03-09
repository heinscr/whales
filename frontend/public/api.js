// API Helper Functions
const API = {
  async request(endpoint, options = {}) {
    const url = `${CONFIG.API_GATEWAY_URL}${endpoint}`;
    
    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options.headers
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`API Error [${endpoint}]:`, error);
      throw error;
    }
  },

  health() {
    return this.request('/health');
  },

  getData() {
    return this.request('/data');
  },

  listItems() {
    return this.request('/items');
  },

  getItem(id) {
    return this.request(`/items/${id}`);
  },

  createItem(data) {
    return this.request('/items', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  },

  updateItem(id, data) {
    return this.request(`/items/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    });
  },

  deleteItem(id) {
    return this.request(`/items/${id}`, {
      method: 'DELETE'
    });
  }
};

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = API;
}
