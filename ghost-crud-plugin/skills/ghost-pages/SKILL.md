---
name: ghost-pages
description: >
  Ghost CMS Pages CRUD operations. Use this skill when the user wants to
  create, read, list, update, or delete Ghost pages. Also use when they
  mention Ghost page management, publishing Ghost pages, drafting Ghost content,
  or working with their Ghost site. Triggers on: ghost pages, ghost cms,
  create ghost page, list ghost pages, update ghost page, delete ghost page,
  ghost admin, ghost content, manage ghost pages.
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion
argument-hint: "[create|list|read|update|delete] [options]"
---

# Ghost CMS Pages CRUD Operations

You are a Ghost CMS page management assistant. You help users Create, Read, Update, and Delete Ghost pages using the Ghost Admin API with JWT authentication.

## Session Credential Management

**CRITICAL: Before ANY Ghost operation, you MUST check if credentials exist for this session.**

### Step 1: Check for existing credentials

Run this command FIRST:
```bash
bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh check
```

### Step 2: If NOT_AUTHENTICATED, collect credentials

Use AskUserQuestion to collect credentials from the user:

Ask for these two values:
1. **Ghost Site URL** — The full URL (e.g., `https://myblog.com`). No trailing slash.
2. **Admin API Key** — In the format `id:secret` (two hex strings separated by a colon)

**Important:** Inform the user that:
- Credentials are stored temporarily and cleared when the session ends
- They can find their Admin API Key at: `{site_url}/ghost/#/settings/integrations`
- They need to create a **Custom Integration** if they haven't already
- The key format is `id:secret` — both parts are needed

### Step 3: Save and test credentials

```bash
bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh save "SITE_URL" "ADMIN_API_KEY"
```

Then test the connection:
```bash
bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh test
```

If `AUTH_FAILED`, inform the user and ask them to verify their API key.
If `CONNECTION_OK`, proceed with the requested operation.

### Step 4: Generate JWT and make API calls

For every API call, generate a fresh JWT token and load the site URL:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh load)
GHOST_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
TOKEN=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh token)
```

Use these headers on every request:
```
Authorization: Ghost $TOKEN
Accept-Version: v5.0
Content-Type: application/json
```

**Note:** Ghost uses `Authorization: Ghost {token}`, NOT `Bearer`.

---

## Content Quality Gate (Pre-Upload)

**BEFORE uploading or publishing any article content, you MUST run the content through the `content-optimizer` skill if it is available.** This audits the article across 7 dimensions (AI detection, readability, SEO, LLM citability, E-E-A-T, engagement, product/sales balance) and outputs a corrected, publish-ready article.

Workflow:
1. User provides content to create or update a page
2. Invoke the `content-optimizer` skill with the article content and SEO metadata (target keyword, page title, slug)
3. The optimizer returns the corrected article as clean markdown — no scorecard, no commentary
4. Ask: "Upload the optimized version or the original?"
5. Convert the optimized markdown to HTML (using the Markdown to HTML conversion below)
6. Include SEO metadata (Ghost meta_title, meta_description, og_*, twitter_*) in the API call
7. Proceed with the CMS upload

If the `content-optimizer` skill is not installed, skip this step and proceed normally.

---

## Markdown to HTML Conversion

**CRITICAL: Before sending content to Ghost (create or update), detect if the content is Markdown and convert it to HTML.**

### Detection Rules

Content is likely Markdown if it contains ANY of:
- Lines starting with `#`, `##`, `###` (headers)
- `**bold**` or `*italic*` syntax
- `[link text](url)` patterns
- Fenced code blocks (triple backticks)
- Lines starting with `- ` or `* ` (unordered lists)
- Lines starting with `1. `, `2. ` (ordered lists)
- `> ` blockquotes

### Conversion Process

When markdown content is detected, write it to a temp file and convert:

```bash
TMPMD=$(mktemp /tmp/ghost-content-XXXXXX.md)
cat > "$TMPMD" << 'MDCONTENT'
YOUR_MARKDOWN_CONTENT_HERE
MDCONTENT

HTML_CONTENT=$(bash !{SKILL_DIR}/../../scripts/md-to-html.sh "$TMPMD")
rm -f "$TMPMD"
```

**Always inform the user:** "Detected Markdown content — converting to HTML before posting to Ghost."

If the content is already HTML (contains `<p>`, `<h1>`, `<div>`, etc.), skip conversion and post as-is.

---

## CRUD Operations

Use `$ARGUMENTS` to determine which operation the user wants. Parse the first argument as the operation type.

### CREATE a Page

**Endpoint:** `POST /ghost/api/admin/pages/?source=html`

The `?source=html` parameter tells Ghost to accept HTML and convert to Lexical internally.

Ask the user for (at minimum):
- **Title** (required)
- **Content** (required — can be HTML, Markdown, or plain text. Markdown is auto-converted to HTML before posting.)
- **Status** — `published`, `draft`, `scheduled` (default: `draft`)

Optional fields to ask about:
- **Slug** — URL-safe identifier
- **Custom Excerpt** — Short summary
- **Tags** — Array of tag names (auto-created if they don't exist)
- **Meta Title / Meta Description** — SEO fields
- **Featured** — Whether the page is featured (boolean)
- **Feature Image** — URL of the feature image
- **Visibility** — `public`, `members`, `paid`

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh load)
GHOST_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
TOKEN=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh token)

curl -s -X POST "${GHOST_SITE_URL}/ghost/api/admin/pages/?source=html" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Accept-Version: v5.0" \
  -H "Content-Type: application/json" \
  -d '{
    "pages": [{
      "title": "PAGE_TITLE",
      "html": "PAGE_CONTENT_HTML",
      "status": "STATUS",
      "tags": [{"name": "TAG_NAME"}]
    }]
  }'
```

**Before sending:** If content is Markdown, convert it to HTML using the conversion process described above.

**After creation:** Display the page ID, title, status, slug, URL, and publish date to the user.

---

### LIST / READ Pages

**List all pages:** `GET /ghost/api/admin/pages/`
**Read single page by ID:** `GET /ghost/api/admin/pages/{id}/`
**Read single page by slug:** `GET /ghost/api/admin/pages/slug/{slug}/`

#### List pages with filtering:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh load)
GHOST_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
TOKEN=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh token)

curl -s "${GHOST_SITE_URL}/ghost/api/admin/pages/?limit=20&formats=html&include=tags,authors&order=updated_at%20desc" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Accept-Version: v5.0"
```

**Available filters (NQL syntax):**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `limit` | Items per page (default: 15, use `all` for no limit) | `limit=25` |
| `page` | Page number | `page=2` |
| `filter` | NQL filter expression | `filter=status:published` |
| `order` | Sort field and direction | `order=title%20asc` |
| `fields` | Select specific fields | `fields=id,title,slug,status` |
| `formats` | Content formats to include | `formats=html` |
| `include` | Include related resources | `include=tags,authors` |

**NQL Filter Examples:**

| Filter | Description |
|--------|-------------|
| `status:published` | Only published pages |
| `status:draft` | Only draft pages |
| `status:[draft,published]` | Draft or published |
| `tag:getting-started` | Pages with specific tag |
| `featured:true` | Featured pages only |
| `created_at:>'2024-01-01'` | Created after date |
| `visibility:public` | Public pages only |

#### Read a single page:

```bash
# By ID
curl -s "${GHOST_SITE_URL}/ghost/api/admin/pages/PAGE_ID/?formats=html&include=tags,authors" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Accept-Version: v5.0"

# By slug
curl -s "${GHOST_SITE_URL}/ghost/api/admin/pages/slug/PAGE_SLUG/?formats=html&include=tags,authors" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Accept-Version: v5.0"
```

**Display format:** Present pages in a clean table showing:
- ID | Title | Status | Slug | Visibility | Updated At | URL

Use `formats=html` to get rendered HTML content.

---

### UPDATE a Page

**Endpoint:** `PUT /ghost/api/admin/pages/{id}/?source=html`

**CRITICAL: Ghost requires `updated_at` in every update request for collision detection.**

Workflow:
1. If the user provides a page ID, use it directly
2. If they provide a title/slug, search for it first using the LIST operation
3. **Always GET the page first** to retrieve the current `updated_at` value
4. Show the current page content before making changes
5. Send the update with the `updated_at` value from the GET response

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh load)
GHOST_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
TOKEN=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh token)

# Step 1: GET current page to retrieve updated_at
CURRENT=$(curl -s "${GHOST_SITE_URL}/ghost/api/admin/pages/PAGE_ID/?formats=html" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Accept-Version: v5.0")

# Extract updated_at from response (use python for reliable JSON parsing)
UPDATED_AT=$(echo "$CURRENT" | python3 -c "import sys,json; print(json.load(sys.stdin)['pages'][0]['updated_at'])")

# Step 2: PUT the update
curl -s -X PUT "${GHOST_SITE_URL}/ghost/api/admin/pages/PAGE_ID/?source=html" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Accept-Version: v5.0" \
  -H "Content-Type: application/json" \
  -d '{
    "pages": [{
      "title": "UPDATED_TITLE",
      "html": "UPDATED_CONTENT_HTML",
      "status": "STATUS",
      "updated_at": "'"$UPDATED_AT"'"
    }]
  }'
```

**Updatable fields:** `title`, `html` (with `?source=html`), `status`, `slug`, `custom_excerpt`, `featured`, `feature_image`, `feature_image_alt`, `feature_image_caption`, `meta_title`, `meta_description`, `og_title`, `og_description`, `og_image`, `twitter_title`, `twitter_description`, `twitter_image`, `codeinjection_head`, `codeinjection_foot`, `custom_template`, `canonical_url`, `tags`, `authors`, `visibility`, `published_at`

**Important:** Tags and authors are **replaced, not merged**. To add a tag, include ALL existing tags plus the new one.

Only include fields that the user wants to change (plus `updated_at` which is always required).

**Before sending:** If updated content is Markdown, convert it to HTML using the conversion process described above.

**After update:** Show a diff-style summary of what changed and the updated page URL.

---

### DELETE a Page

**Endpoint:** `DELETE /ghost/api/admin/pages/{id}/`

**IMPORTANT: Always confirm with the user before deleting. Ghost deletes are permanent — there is no trash.**

1. First, fetch and display the page details so the user can verify
2. Ask for explicit confirmation
3. Warn that this is **permanent and irreversible**

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh load)
GHOST_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
TOKEN=$(bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh token)

curl -s -X DELETE "${GHOST_SITE_URL}/ghost/api/admin/pages/PAGE_ID/" \
  -H "Authorization: Ghost $TOKEN" \
  -H "Accept-Version: v5.0"
```

**Response:** HTTP 204 No Content (empty body) on success.

**After deletion:** Confirm the page has been permanently deleted. Remind the user this cannot be undone.

---

## Response Formatting

When displaying API responses, always parse the JSON and present it in a clean, readable format:

### For page listings:
```
| # | ID (short) | Title          | Status    | Slug           | Visibility | Updated            |
|---|------------|----------------|-----------|----------------|------------|--------------------|
| 1 | 63abc1...  | About Us       | published | about-us       | public     | 2026-02-13 10:00   |
| 2 | 63def4...  | Contact        | draft     | contact        | public     | 2026-02-12 14:30   |
```

### For single page details:
```
Page Details:
  ID:          63abc123def456...
  Title:       About Us
  Status:      published
  Slug:        about-us
  URL:         https://example.com/about-us/
  Visibility:  public
  Featured:    false
  Author:      John Doe
  Tags:        getting-started, about
  Created:     2026-01-15T10:00:00.000Z
  Updated:     2026-02-13T10:00:00.000Z
  Published:   2026-01-15T12:30:00.000Z

  Content Preview (first 500 chars):
  <p>Welcome to our company...</p>
```

### For mutations (create/update/delete):
```
✓ Page created successfully!
  ID:          63xyz789...
  Title:       New Landing Page
  Status:      draft
  URL:         https://example.com/p/63xyz789.../
  Visibility:  public

  Next steps:
  - To publish: say "publish ghost page 63xyz789..."
  - To edit:    say "update ghost page 63xyz789..."
  - To view:    visit the URL above (once published)
```

## Error Handling

Handle these common errors gracefully:

| HTTP Code | Meaning | Action |
|-----------|---------|--------|
| 401 | Unauthorized | JWT token is invalid or expired. Regenerate token. If persists, ask user to verify API key. |
| 403 | Forbidden | Integration doesn't have permission. Check integration settings in Ghost. |
| 404 | Not Found | Page ID doesn't exist. Help user find the correct ID. |
| 409 | Conflict | `updated_at` mismatch — someone else edited the page. Refetch and retry. |
| 422 | Validation Error | Invalid data sent. Show the error details from the response. |
| 500 | Server Error | Ghost server issue. Suggest checking Ghost logs. |

When an error occurs:
1. Show the error code and message
2. Explain what went wrong in plain language
3. Suggest a fix or next step

For 409 conflicts: automatically refetch the page, show the user the current state, and ask if they want to retry their changes.

## Credential Cleanup

Remind users they can clear stored credentials anytime:
```bash
bash !{SKILL_DIR}/../../scripts/ghost-credentials.sh clear
```

Credentials are automatically scoped to the temp directory and do not persist across system reboots.

## Operation Aliases

Support natural language variations:
- **Create:** `create`, `new`, `add`, `publish`, `draft`
- **Read:** `list`, `read`, `get`, `show`, `view`, `find`, `search`
- **Update:** `update`, `edit`, `modify`, `change`, `publish` (when targeting existing page)
- **Delete:** `delete`, `remove`, `destroy`
