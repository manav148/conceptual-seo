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

AI content decontamination and SEO quality gate. Analyzes articles across 6 dimensions (AI detection, readability, SEO, LLM citability, E-E-A-T, engagement), scores them, and rewrites to sound human while preserving facts. Automatically invoked by all CMS plugins before content upload.

## Marketplace

This repository serves as a Claude Code marketplace. The `.claude-plugin/marketplace.json` catalogs all available plugins.
