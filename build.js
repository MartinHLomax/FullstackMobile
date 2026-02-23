#!/usr/bin/env node

/**
 * Build script to inject environment variables into index.html
 * Usage: node build.js
 *
 * This script reads configuration from config.js and creates a production-ready index.html
 * with the actual values injected.
 */

const fs = require('fs');
const path = require('path');

// Check if config.js exists
const configPath = path.join(__dirname, 'config.js');
if (!fs.existsSync(configPath)) {
  console.error('❌ Error: config.js not found!');
  console.error('Please copy config.template.js to config.js and fill in your values.');
  process.exit(1);
}

// Load configuration
const CONFIG = require('./config.js');

// Validate configuration
if (!CONFIG.SUPABASE_URL || CONFIG.SUPABASE_URL === 'YOUR_SUPABASE_URL_HERE') {
  console.error('❌ Error: SUPABASE_URL not configured in config.js');
  process.exit(1);
}

if (!CONFIG.SUPABASE_ANON_KEY || CONFIG.SUPABASE_ANON_KEY === 'YOUR_SUPABASE_ANON_KEY_HERE') {
  console.error('❌ Error: SUPABASE_ANON_KEY not configured in config.js');
  process.exit(1);
}

// Read the template file
const templatePath = path.join(__dirname, 'index.template.html');
const indexPath = path.join(__dirname, 'index.html');

// If template doesn't exist, create it from current index.html
if (!fs.existsSync(templatePath)) {
  console.log('📝 Creating index.template.html from current index.html...');
  const currentIndex = fs.readFileSync(indexPath, 'utf8');

  // Replace current values with placeholders
  const template = currentIndex
    .replace(
      /const SUPABASE_URL = ".*?";/,
      'const SUPABASE_URL = "{{SUPABASE_URL}}";'
    )
    .replace(
      /const SUPABASE_ANON_KEY = ".*?";/,
      'const SUPABASE_ANON_KEY = "{{SUPABASE_ANON_KEY}}";'
    );

  fs.writeFileSync(templatePath, template);
  console.log('✅ Template created successfully!');
}

// Read template
const template = fs.readFileSync(templatePath, 'utf8');

// Replace placeholders with actual values
const output = template
  .replace('{{SUPABASE_URL}}', CONFIG.SUPABASE_URL)
  .replace('{{SUPABASE_ANON_KEY}}', CONFIG.SUPABASE_ANON_KEY);

// Write the output file
fs.writeFileSync(indexPath, output);

console.log('✅ Build complete! index.html has been updated with configuration values.');
console.log('📦 You can now deploy index.html to production.');
console.log('');
console.log('⚠️  Remember:');
console.log('  - Never commit config.js to version control');
console.log('  - Keep index.template.html in version control');
console.log('  - Run this build script before each deployment');