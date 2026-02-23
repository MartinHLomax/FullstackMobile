// Configuration template for environment variables
// Copy this file to config.js and fill in your values
// IMPORTANT: Never commit config.js to version control!

const CONFIG = {
  SUPABASE_URL: 'YOUR_SUPABASE_URL_HERE',
  SUPABASE_ANON_KEY: 'YOUR_SUPABASE_ANON_KEY_HERE'
};

// Export for use in build scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}