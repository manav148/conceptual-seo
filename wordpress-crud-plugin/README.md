# WordPress CRUD Plugin for Claude Code

A Claude Code marketplace plugin that enables full CRUD (Create, Read, Update, Delete) operations on WordPress pages directly from your terminal using the WordPress REST API.

## Features

- **Create** pages with title, content, status, and metadata
- **List/Read** pages with filtering, search, and pagination
- **Update** any page field (title, content, status, slug, etc.)
- **Delete** pages (trash or permanent) with confirmation safeguards
- **Session-based auth** — credentials are requested once and persist for the session
- **Application Passwords** — uses WordPress's built-in secure auth (no plugins needed)

## Prerequisites

1. WordPress 5.6+ (for Application Passwords support)
2. HTTPS enabled on your WordPress site
3. An Application Password generated from your WordPress profile
4. `curl` available in your terminal

## Installation

### From the Marketplace

```bash
# Add the marketplace (if not already added)
# Then install the wordpress-crud plugin from Claude Code
```

### Manual Installation

Clone this repository into your Claude Code plugins directory or add it as a project-scoped plugin.

## Generating an Application Password

1. Log into your WordPress admin dashboard
2. Go to **Users → Profile** (or visit `https://your-site.com/wp-admin/profile.php`)
3. Scroll down to **Application Passwords**
4. Enter a name (e.g., "Claude Code") and click **Add New Application Password**
5. Copy the generated password — you won't see it again

## Usage

Once installed, use the `/wp-pages` command or just ask Claude to manage your WordPress pages:

```
/wp-pages list                    # List all pages
/wp-pages create                  # Create a new page
/wp-pages read 42                 # Read page with ID 42
/wp-pages update 42               # Update page with ID 42
/wp-pages delete 42               # Delete page with ID 42
```

Or use natural language:
- "List all my WordPress pages"
- "Create a new About Us page"
- "Update the contact page content"
- "Delete page 42"

## Credential Security

- Credentials are stored in a temporary directory (`$TMPDIR/.wp-claude-session/`)
- Files are created with restrictive permissions (700/600)
- Credentials do not persist across system reboots
- You can manually clear credentials anytime: `/wp-pages` then say "clear credentials"

## Plugin Structure

```
wordpress-crud-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── skills/
│   └── wp-pages/
│       └── SKILL.md         # Main skill definition
├── scripts/
│   └── wp-credentials.sh   # Session credential manager
└── README.md               # This file
```

## License

MIT
