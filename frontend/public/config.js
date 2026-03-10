// Configuration - loaded from server
let CONFIG = {
  API_GATEWAY_URL: 'http://localhost:8080/api',
  TIMEOUT: 5000
};

// Fetch actual API URL from server
async function initConfig() {
  try {
    const response = await fetch('/api/gateway-info');
    if (response.ok) {
      const data = await response.json();
      CONFIG.API_GATEWAY_URL = data.apiGatewayUrl;
      console.log('Config loaded. API URL:', CONFIG.API_GATEWAY_URL);
    }
  } catch (error) {
    console.log('Using default API URL:', CONFIG.API_GATEWAY_URL);
  }
}

// Initialize config on page load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initConfig);
} else {
  initConfig();
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}
