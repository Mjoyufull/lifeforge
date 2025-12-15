// Basic local development origins
export const CORS_ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://localhost:5174',
  'http://localhost:8080',
  'http://localhost:8090'
]

// Add VITE_API_HOST and additional env vars if present
if (process.env.VITE_API_HOST) {
    const host = process.env.VITE_API_HOST;
    if (!CORS_ALLOWED_ORIGINS.includes(host)) {
        CORS_ALLOWED_ORIGINS.push(host);
    }
}

// Allow all LAN IPs provided via environment variable or default
// This is a simplified approach; ideally we'd parse specific ranges or use a regex in the cors middleware options
if (process.env.ADDITIONAL_CORS_ORIGINS) {
  const origins = process.env.ADDITIONAL_CORS_ORIGINS.split(',').map(o => o.trim());
  CORS_ALLOWED_ORIGINS.push(...origins);
}
