// Configuration
const CONFIG = {
  API_GATEWAY_URL: window.location.origin + '/api' || 'http://localhost:8000/api',
  TIMEOUT: 5000
};

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}
