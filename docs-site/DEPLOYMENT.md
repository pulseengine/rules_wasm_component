# Deployment Setup for rules_wasm_component.pulseengine.eu

This guide explains how to set up automated deployment of the documentation site to your Netcup hosting.

## Prerequisites

- Netcup Webhosting 1000 NUE account
- FTP/SFTP access credentials
- GitHub repository with admin access
- (Optional) Cloudflare account for CDN

## Step 1: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Go to `Settings` → `Secrets and variables` → `Actions`
2. Add these repository secrets:

### Required Secrets

- `NETCUP_URI` - Your Netcup FTP server (e.g., `wp123.netcup-webspace.de`)
- `NETCUP_USER` - Your FTP username
- `NETCUP_PASSWORD` - Your FTP password

### Optional Secrets (for Cloudflare CDN)

- `CLOUDFLARE_ZONE_ID` - Your domain's zone ID
- `CLOUDFLARE_TOKEN` - API token with zone edit permissions

## Step 2: FTP Credentials Setup

### Find Your Netcup FTP Details

1. Log into [Netcup Customer Control Panel](https://www.customercontrolpanel.de/)
2. Navigate to your webhosting package
3. Find FTP access details under "FTP-Zugänge"

Example values:

```env
NETCUP_URI: wp123.netcup-webspace.de
NETCUP_USER: wp123-username
NETCUP_PASSWORD: your-ftp-password
```

## Step 3: Domain Configuration

### DNS Setup

Point your domain to Netcup:

1. Log into your domain registrar
2. Update DNS A record:
   - Name: `rules_wasm_component` (or `@` for root domain)
   - Value: Your Netcup hosting IP
   - TTL: 3600

### Netcup Domain Setup

1. In Netcup CCP, go to "Domains" → "Domain-Verwaltung"
2. Add `rules_wasm_component.pulseengine.eu` as a subdomain
3. Point it to your webhosting root directory

## Step 4: Test Deployment

### Manual Test

1. Build the site locally:

   ```bash
   cd docs-site
   npm install
   npm run build
   ```

2. Upload `dist/` contents to your FTP manually to test

### Automated Deployment

1. Push changes to the `main` branch
2. GitHub Actions will automatically:
   - Build the documentation site
   - Deploy to your Netcup hosting
   - (Optional) Purge Cloudflare cache

## Step 5: Cloudflare Setup (Optional)

For better global performance, add Cloudflare:

### Add Site to Cloudflare

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Add `pulseengine.eu` as a site
3. Update nameservers at your registrar

### Configure Cloudflare

1. **SSL/TLS**: Set to "Full (strict)"
2. **Caching**:
   - Browser TTL: 4 hours
   - Edge TTL: 2 hours
3. **Page Rules**:
   - `rules_wasm_component.pulseengine.eu/*` → Cache Everything

### Get API Credentials

1. Go to "My Profile" → "API Tokens"
2. Create token with permissions:
   - Zone: Zone Settings: Edit
   - Zone: Cache Purge: Edit
   - Zone Resources: Include specific zone

## Step 6: Build Configuration

The deployment is configured via `.github/workflows/deploy.yml`:

```yaml
# Triggers on:
- Push to main branch with changes in docs-site/
- Manual workflow dispatch

# Build process:
1. Checkout code
2. Setup Node.js 20
3. Install dependencies (npm ci)
4. Build site (npm run build)
5. Deploy via FTP to Netcup
6. Optional: Purge Cloudflare cache
```

## Step 7: Monitoring

### Check Deployment Status

- GitHub Actions tab shows build/deploy status
- Successful deploys show ✅ green checkmark
- Failed deploys show ❌ red X with error logs

### Verify Site

After deployment, check:

- <https://rules_wasm_component.pulseengine.eu> loads correctly
- All pages and assets work
- Search functionality works
- Mobile responsiveness

## Directory Structure

```text
docs-site/
├── .github/
│   └── workflows/
│       └── deploy.yml          # Deployment automation
├── src/
│   ├── content/
│   │   └── docs/              # Documentation content
│   ├── styles/
│   │   └── custom.css         # Custom styling
│   └── assets/                # Images, logos
├── astro.config.mjs           # Astro configuration
├── package.json               # Dependencies
└── DEPLOYMENT.md              # This file
```

## Troubleshooting

### Common Issues

**FTP connection fails:**

- Verify FTP credentials in GitHub secrets
- Check if Netcup FTP service is running
- Try connecting manually with an FTP client

**Build fails:**

- Check Node.js version compatibility
- Verify package.json dependencies
- Look at GitHub Actions logs for specific errors

**Site loads but styles missing:**

- Check if CSS files are being uploaded
- Verify file permissions on Netcup
- Clear browser cache

**Search doesn't work:**

- Ensure search index files are generated
- Check if JavaScript files are uploaded correctly
- Verify MIME types on server

### Debug Commands

```bash
# Test build locally
cd docs-site
npm run build
npm run preview

# Check generated files
ls -la dist/

# Test FTP connection
ftp wp123.netcup-webspace.de
# (enter credentials)
```

### Performance Optimization

**Enable Compression:**
Add to `.htaccess` in webhosting root:

```apache
# Enable compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
</IfModule>

# Cache static assets
<IfModule mod_expires.c>
    ExpiresActive on
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/svg+xml "access plus 1 month"
</IfModule>
```

## Security

**Protect sensitive paths:**

```apache
# Block access to source files
<Files "*.md">
    Order allow,deny
    Deny from all
</Files>

<Files "*.json">
    Order allow,deny
    Deny from all
</Files>

# Except for search index
<Files "search-index.json">
    Order deny,allow
    Allow from all
</Files>
```

Your documentation site should now be automatically deployed to `https://rules_wasm_component.pulseengine.eu` whenever you
push changes to the main branch!
