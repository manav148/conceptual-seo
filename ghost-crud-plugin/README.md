# Ghost CRUD Plugin for Claude Code

A Claude Code marketplace plugin that enables full CRUD (Create, Read, Update, Delete) operations on Ghost CMS pages directly from your terminal using the Ghost Admin API.

## Features

- **Create** pages with title, content, status, tags, SEO metadata, and more
- **List/Read** pages with NQL filtering, search, pagination, and field selection
- **Update** any page field with collision detection (`updated_at` enforcement)
- **Delete** pages with confirmation safeguards
- **Session-based JWT auth** — API key requested once, JWT tokens auto-generated per request
- **Markdown auto-conversion** — Markdown content is converted to HTML before posting
- **HTML source mode** — Uses `?source=html` so Ghost handles Lexical conversion internally

## Prerequisites

1. Ghost 5.0+ (for Lexical and Admin API v5 support)
2. A Custom Integration with an Admin API Key
3. `python3` available in your terminal (required for JWT generation)
4. `curl` available in your terminal

## Installation

### From the Marketplace

```bash
# Add the marketplace (if not already added)
# Then install the ghost-crud plugin from Claude Code
```

### Manual Installation

Clone this repository into your Claude Code plugins directory or add it as a project-scoped plugin.

## Getting an Admin API Key

1. Log into your Ghost Admin dashboard
2. Go to **Settings > Integrations** (or visit `https://your-site.com/ghost/#/settings/integrations`)
3. Click **Add Custom Integration**
4. Name it (e.g., "Claude Code")
5. Copy the **Admin API Key** — it looks like `6489abcd1234:8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c`

## Usage

Once installed, use the `/ghost-pages` command or just ask Claude to manage your Ghost pages:

```
/ghost-pages list                    # List all pages
/ghost-pages create                  # Create a new page
/ghost-pages read 63abc123...        # Read page by ID
/ghost-pages update 63abc123...      # Update page by ID
/ghost-pages delete 63abc123...      # Delete page by ID
```

Or use natural language:
- "List all my Ghost pages"
- "Create a new About Us page on Ghost"
- "Update the contact page on my Ghost site"
- "Delete Ghost page 63abc123..."

## How Authentication Works

1. You provide your Admin API Key (`id:secret` format) once per session
2. For each API request, a fresh JWT token is generated (valid for 5 minutes)
3. JWT is signed with HS256 using the secret portion of your key
4. The `Authorization: Ghost {jwt}` header is used (not Bearer)

## Plugin Structure

```
ghost-crud-plugin/
├── .claude-plugin/
│   └── plugin.json            # Plugin manifest
├── skills/
│   └── ghost-pages/
│       └── SKILL.md           # Main skill definition
├── scripts/
│   ├── ghost-credentials.sh   # Session credential & JWT manager
│   └── md-to-html.sh          # Markdown to HTML converter
└── README.md                  # This file
```

## License

MIT
