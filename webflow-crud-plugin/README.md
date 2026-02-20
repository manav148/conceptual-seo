# Webflow CRUD Plugin for Claude Code

A Claude Code marketplace plugin that enables full CMS collection item management and static page metadata updates using the Webflow Data API v2.

## Features

- **CMS Items** — Full CRUD: Create, Read, Update, Delete collection items
- **Publish** — Publish items individually or in bulk without full site publish
- **Live endpoints** — Create/update items directly to production in one step
- **Static Pages** — Update page metadata (title, slug, SEO, Open Graph)
- **Collection Schema** — Auto-discovers field types and slugs before operations
- **Markdown auto-conversion** — Markdown content converted to HTML for RichText fields
- **Session-based auth** — Bearer token requested once per session

## Prerequisites

1. A Webflow site with CMS collections
2. A Site API Token with required scopes
3. `curl` available in your terminal

## Generating an API Token

1. Go to your **Webflow workspace**
2. Click the **gear icon** on the target site to open **Site Settings**
3. Navigate to **Apps & integrations** in the left sidebar
4. Scroll to the **API access** section
5. Click **Generate API token**
6. Name it (e.g., "Claude Code") and select these scopes:
   - `sites:read` — List sites
   - `sites:write` — Publish site
   - `pages:read` — List/read pages
   - `pages:write` — Update page metadata
   - `cms:read` — List collections and items
   - `cms:write` — Create, update, delete, publish items
7. Copy the token — it will not be shown again

## Usage

```
/webflow-cms sites                    # List all sites
/webflow-cms collections              # List CMS collections
/webflow-cms items list               # List items in a collection
/webflow-cms items create             # Create a new CMS item
/webflow-cms items update ITEM_ID     # Update an item
/webflow-cms items delete ITEM_ID     # Delete an item
/webflow-cms items publish ITEM_ID    # Publish staged items
/webflow-cms pages                    # List static pages
/webflow-cms pages update PAGE_ID     # Update page SEO metadata
```

Or use natural language:
- "List my Webflow CMS collections"
- "Create a new blog post in Webflow"
- "Update the SEO title for my About page"
- "Publish the latest blog posts on Webflow"

## Important: Static Pages vs CMS Items

| Capability | Static Pages | CMS Items |
|------------|-------------|-----------|
| Create via API | No | Yes |
| Delete via API | No | Yes |
| Update content | No (metadata only) | Yes (full content) |
| Publish | Full site publish | Per-item publish |

For programmatic content management, use **CMS collections**.

## Plugin Structure

```
webflow-crud-plugin/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── skills/
│   └── webflow-cms/
│       └── SKILL.md             # Main skill definition
├── scripts/
│   ├── webflow-credentials.sh   # Session credential manager
│   └── md-to-html.sh            # Markdown to HTML converter
└── README.md                    # This file
```

## License

MIT
