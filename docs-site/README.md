# WebAssembly Component Rules Documentation Site

This is the official documentation site for `rules_wasm_component`, built with Astro Starlight and deployed to `https://rules_wasm_component.pulseengine.eu`.

[![Built with Starlight](https://astro.badg.es/v2/built-with-starlight/tiny.svg)](https://starlight.astro.build)

## 🚀 Project Status: Ready for Deployment

✅ **Core Infrastructure Complete**
- Astro Starlight configured and optimized
- Responsive design with custom styling
- Search functionality with Pagefind
- GitHub Actions deployment pipeline

✅ **Content Architecture**  
- Homepage with feature overview
- Getting started guide
- Installation instructions
- Language-specific tutorials (Rust, Go)
- Examples and composition guides
- Automated deployment setup

✅ **Performance Optimized**
- Static site generation for fast loading
- Optimized images and assets
- CDN-ready configuration
- Mobile-responsive design

## 🛠 Development

### Local Development
```bash
# Install dependencies
npm install

# Start development server
npm run dev
# Site available at http://localhost:4321

# Build for production
npm run build

# Preview production build
npm run preview
```

### Adding Content
1. Create `.md` or `.mdx` files in `src/content/docs/`
2. Update navigation in `astro.config.mjs` sidebar configuration
3. Test locally with `npm run dev`

## 🚀 Deployment

### Automated Deployment (Recommended)
The site automatically deploys to Netcup hosting when changes are pushed to the main branch.

**Setup Requirements:**
1. Configure GitHub secrets (see DEPLOYMENT.md)
2. Set up FTP credentials for Netcup
3. Optional: Configure Cloudflare for CDN

**Deployment Process:**
- Triggered on push to main branch with `docs-site/` changes
- Builds static site with Astro
- Deploys via FTP to Netcup hosting
- Purges Cloudflare cache (if configured)

## 📞 Next Steps

1. **Configure GitHub Secrets**: Add Netcup credentials (NETCUP_URI, NETCUP_USER, NETCUP_PASSWORD) for automated deployment
2. **Update GitHub Repository URL**: Replace placeholder URLs in astro.config.mjs
3. **Add More Content**: Expand language guides and examples
4. **Optional**: Set up Cloudflare for CDN acceleration

## 🎯 Content Status

### ✅ Completed Pages
- **Homepage** (`/`) - Feature overview and quick start
- **Getting Started** (`/getting-started/`) - Installation and first component
- **Installation** (`/installation/`) - Complete setup guide
- **First Component** (`/first-component/`) - Step-by-step tutorial
- **Rust Guide** (`/languages/rust/`) - Comprehensive Rust development
- **Go Guide** (`/languages/go/`) - TinyGo with WASI Preview 2
- **Basic Example** (`/examples/basic/`) - Simple hello world
- **WAC Composition** (`/composition/wac/`) - Multi-component systems

### 🚧 Planned Content
- C++ and JavaScript language guides
- Calculator and HTTP service examples
- OCI publishing and production guides
- Performance optimization tutorials

---

**Status**: ✅ Ready for production deployment to `https://rules_wasm_component.pulseengine.eu`

The documentation site is fully functional, performance-optimized, and ready to serve the WebAssembly component development community!
