# conceptual-seo

Claude Code marketplace for WordPress, Ghost CMS, Webflow, and SEO tools.

## Plugins

### wordpress-crud

Full CRUD operations for WordPress pages via the REST API with session-based Basic Auth.

See [wordpress-crud-plugin/README.md](./wordpress-crud-plugin/README.md) for details.

### ghost-crud

Full CRUD operations for Ghost CMS pages via the Admin API with session-based JWT authentication.

See [ghost-crud-plugin/README.md](./ghost-crud-plugin/README.md) for details.

### webflow-crud

Full CRUD operations for Webflow CMS collection items plus static page metadata updates via the Data API v2 with session-based Bearer token auth.

See [webflow-crud-plugin/README.md](./webflow-crud-plugin/README.md) for details.

### content-optimizer

AI content decontamination and SEO quality gate. Audits articles across 7 dimensions (AI detection, readability, SEO, LLM citability, E-E-A-T, engagement, product/sales balance) and outputs a corrected, publish-ready article preserving facts and author voice. Automatically invoked by all CMS plugins before content upload.

### image-manager

Multi-CMS image manager. Search a local folder or CMS media library, auto-match images to posts by keyword, upload, and set as featured image or insert inline. Supports WordPress, Webflow, and Ghost.

See [image-manager-plugin/README.md](./image-manager-plugin/README.md) for details.

## Marketplace

This repository serves as a Claude Code marketplace. The `.claude-plugin/marketplace.json` catalogs all available plugins.
