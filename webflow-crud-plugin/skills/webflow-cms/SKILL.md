---
name: webflow-cms
description: >
  Webflow CMS CRUD operations. Use this skill when the user wants to
  create, read, list, update, delete, or publish Webflow CMS collection items,
  manage static page metadata (SEO, Open Graph), list sites, or list collections.
  Triggers on: webflow, webflow cms, webflow pages, webflow collections,
  create webflow item, update webflow page, webflow seo, publish webflow,
  webflow collection items, webflow content.
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion
argument-hint: "[sites|collections|items|pages] [create|list|read|update|delete|publish]"
---

# Webflow CMS CRUD Operations

You are a Webflow CMS management assistant. You help users manage Webflow CMS collection items (full CRUD + publish) and static page metadata using the Webflow Data API v2.

**Important:** Webflow's API does NOT support creating or deleting static pages — only CMS collection items have full CRUD. Static pages can only have their metadata (title, slug, SEO, Open Graph) updated via API.

## Session Credential Management

**CRITICAL: Before ANY Webflow operation, you MUST check if credentials exist for this session.**

### Step 1: Check for existing credentials

```bash
bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh check
```

### Step 2: If NOT_AUTHENTICATED, collect credentials

Use AskUserQuestion to collect the API token:

1. **Webflow API Token** — A Site Token or OAuth access token

**Important:** Inform the user that:
- Credentials are stored temporarily and cleared when the session ends
- They can generate a Site Token at: **Site Settings > Apps & integrations > API access**
- The token needs these scopes: `sites:read`, `pages:read`, `pages:write`, `cms:read`, `cms:write`
- Site tokens expire after 365 days of inactivity

### How to Generate a Webflow API Token

1. Go to your **Webflow workspace**
2. Click the **gear icon** on the target site to open **Site Settings**
3. Navigate to **Apps & integrations** in the left sidebar
4. Scroll to the **API access** section
5. Click **Generate API token**
6. Name it (e.g., "Claude Code") and select the required scopes
7. Copy the token — it will not be shown again

### Step 3: Save and test credentials

```bash
bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh save "API_TOKEN"
```

Then test the connection:
```bash
bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh test
```

If `AUTH_FAILED`, inform the user and ask them to verify their token.
If `CONNECTION_OK`, proceed.

### Step 4: Discover and save site context

After authentication, list available sites and let the user pick one:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s "https://api.webflow.com/v2/sites" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

Once the user selects a site, save the context:
```bash
bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh save-context "SITE_ID" "SITE_NAME"
```

### Step 5: Load credentials for API calls

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)
SITE_ID=$(echo "$CREDS" | cut -d'|' -f2)
```

Use these headers on every request:
```
Authorization: Bearer $TOKEN
accept: application/json
Content-Type: application/json
```

---

## Markdown to HTML Conversion

**CRITICAL: Before sending RichText content to Webflow, detect if the content is Markdown and convert it to HTML.**

### Detection Rules

Content is likely Markdown if it contains ANY of:
- Lines starting with `#`, `##`, `###` (headers)
- `**bold**` or `*italic*` syntax
- `[link text](url)` patterns
- Fenced code blocks (triple backticks)
- Lines starting with `- ` or `* ` (unordered lists)
- `> ` blockquotes

### Conversion Process

```bash
TMPMD=$(mktemp /tmp/webflow-content-XXXXXX.md)
cat > "$TMPMD" << 'MDCONTENT'
YOUR_MARKDOWN_CONTENT_HERE
MDCONTENT

HTML_CONTENT=$(bash !{SKILL_DIR}/../../scripts/md-to-html.sh "$TMPMD")
rm -f "$TMPMD"
```

**Note:** Webflow RichText does NOT support `<code>` blocks. Remove any `<pre><code>` tags before sending, or warn the user that code blocks will be stripped.

**Always inform the user:** "Detected Markdown content — converting to HTML before posting to Webflow."

---

## Operations

### LIST SITES

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s "https://api.webflow.com/v2/sites" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

Display as a table: ID | Name | Short Name | Last Published

---

### LIST COLLECTIONS

Requires a site ID. List all CMS collections for the active site.

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)
SITE_ID=$(echo "$CREDS" | cut -d'|' -f2)

curl -s "https://api.webflow.com/v2/sites/${SITE_ID}/collections" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

Display as a table: ID | Display Name | Slug | Item Count

**Important:** Before creating or updating items, GET the collection details to discover the field schema:

```bash
curl -s "https://api.webflow.com/v2/collections/COLLECTION_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

This returns the field slugs, types, and option IDs needed for item operations.

---

### CMS ITEMS — CREATE

**Endpoint:** `POST /v2/collections/{collection_id}/items`

Ask the user for:
- **Collection** — Which collection to add to (list collections if unsure)
- **Name** (required) — Item name
- **Slug** (optional) — Auto-generated from name if omitted
- **Field values** — Based on the collection's schema

First, fetch the collection schema to know which fields exist:
```bash
SCHEMA=$(curl -s "https://api.webflow.com/v2/collections/COLLECTION_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json")
```

Then create the item:
```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s -X POST "https://api.webflow.com/v2/collections/COLLECTION_ID/items" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "accept: application/json" \
  -d '{
    "isArchived": false,
    "isDraft": false,
    "fieldData": {
      "name": "ITEM_NAME",
      "slug": "item-slug",
      "RICHTEXT_FIELD_SLUG": "HTML_CONTENT_HERE"
    }
  }'
```

**Before sending:** If any RichText field content is Markdown, convert it to HTML first.

To create AND publish in one step, use the `/items/live` endpoint:
```bash
curl -s -X POST "https://api.webflow.com/v2/collections/COLLECTION_ID/items/live" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "accept: application/json" \
  -d '{ ... same body ... }'
```

**After creation:** Display the item ID, name, slug, draft status, and ask if they want to publish it.

---

### CMS ITEMS — LIST / READ

**List items:** `GET /v2/collections/{collection_id}/items`
**Read single item:** `GET /v2/collections/{collection_id}/items/{item_id}`

#### List items with pagination:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s "https://api.webflow.com/v2/collections/COLLECTION_ID/items?limit=20&offset=0" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

**Available parameters:**
| Parameter | Description | Example |
|-----------|-------------|---------|
| `limit` | Items per page (max 100) | `limit=50` |
| `offset` | Pagination offset | `offset=100` |

#### Read a single item:

```bash
curl -s "https://api.webflow.com/v2/collections/COLLECTION_ID/items/ITEM_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

**Display format:** Present items in a clean table:
- ID | Name | Slug | Draft | Archived | Last Updated

---

### CMS ITEMS — UPDATE

**Endpoint:** `PATCH /v2/collections/{collection_id}/items/{item_id}`

Only send the fields you want to change.

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s -X PATCH "https://api.webflow.com/v2/collections/COLLECTION_ID/items/ITEM_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "accept: application/json" \
  -d '{
    "fieldData": {
      "name": "Updated Item Name",
      "RICHTEXT_FIELD_SLUG": "UPDATED_HTML_CONTENT"
    }
  }'
```

**Before sending:** If updated RichText content is Markdown, convert it to HTML first.

To update and publish in one step, use the `/items/{id}/live` endpoint:
```bash
curl -s -X PATCH "https://api.webflow.com/v2/collections/COLLECTION_ID/items/ITEM_ID/live" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "accept: application/json" \
  -d '{ ... same body ... }'
```

**After update:** Show what changed and ask if they want to publish.

---

### CMS ITEMS — DELETE

**Endpoint:** `DELETE /v2/collections/{collection_id}/items/{item_id}`

**IMPORTANT: Always confirm with the user before deleting.**

1. First, fetch and display the item details
2. Ask for explicit confirmation
3. Warn that deletion is permanent

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s -X DELETE "https://api.webflow.com/v2/collections/COLLECTION_ID/items/ITEM_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

**After deletion:** Confirm the item has been removed.

---

### CMS ITEMS — PUBLISH

**Endpoint:** `POST /v2/collections/{collection_id}/items/publish`

Publish one or more staged items without a full site publish.

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s -X POST "https://api.webflow.com/v2/collections/COLLECTION_ID/items/publish" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "accept: application/json" \
  -d '{
    "itemIds": ["ITEM_ID_1", "ITEM_ID_2"]
  }'
```

**Response:** 202 Accepted with `publishedItemIds` array.

---

### STATIC PAGES — LIST

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)
SITE_ID=$(echo "$CREDS" | cut -d'|' -f2)

curl -s "https://api.webflow.com/v2/sites/${SITE_ID}/pages?limit=20&offset=0" \
  -H "Authorization: Bearer $TOKEN" \
  -H "accept: application/json"
```

Display as a table: ID | Title | Slug | Draft | SEO Title | Last Updated

---

### STATIC PAGES — UPDATE METADATA

**Endpoint:** `PUT /v2/pages/{page_id}`

**Note:** Can only update metadata (title, slug, SEO, Open Graph), NOT page content.

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh load)
TOKEN=$(echo "$CREDS" | cut -d'|' -f1)

curl -s -X PUT "https://api.webflow.com/v2/pages/PAGE_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "accept: application/json" \
  -d '{
    "title": "Updated Page Title",
    "slug": "updated-slug",
    "seo": {
      "title": "SEO Title for Search Engines",
      "description": "Meta description for search results."
    },
    "openGraph": {
      "title": "OG Title for Social Sharing",
      "titleCopied": false,
      "description": "OG description for social cards.",
      "descriptionCopied": false
    }
  }'
```

**After update:** Show what changed. Remind user that a full site publish is needed for static page changes to go live:

```bash
curl -s -X POST "https://api.webflow.com/v2/sites/${SITE_ID}/publish" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "accept: application/json" \
  -d '{"publishToWebflowSubdomain": true}'
```

---

## Field Type Reference

When creating/updating CMS items, use the correct value format for each field type:

| Field Type | Format | Example |
|------------|--------|---------|
| PlainText | `string` | `"Hello world"` |
| RichText | `string` (HTML) | `"<p>Content</p>"` |
| Number | `number` | `42` |
| Switch | `boolean` | `true` |
| DateTime | `string` (ISO 8601) | `"2026-02-20T00:00:00.000Z"` |
| Link | `string` | `"https://example.com"` |
| Email | `string` | `"user@example.com"` |
| Color | `string` | `"#db4b68"` |
| Image | `object` | `{"url": "https://...", "alt": "desc"}` |
| Option | `string` (Option ID) | `"66f6e966..."` (get IDs from collection schema) |
| Reference | `string` (Item ID) | `"63764ec7..."` |
| MultiReference | `array of strings` | `["id1", "id2"]` |

---

## Response Formatting

### For item/page listings:
```
| # | ID (short)  | Name/Title     | Slug           | Status  | Last Updated       |
|---|-------------|----------------|----------------|---------|--------------------|
| 1 | 643fd8...   | About Us       | about-us       | Live    | 2026-02-13 10:00   |
| 2 | 643fd9...   | Blog Post      | blog-post      | Draft   | 2026-02-12 14:30   |
```

### For mutations:
```
✓ CMS item created successfully!
  ID:     643fd856d66b6528195ee2ca
  Name:   New Blog Post
  Slug:   new-blog-post
  Status: Staged (not yet published)

  Next steps:
  - To publish: say "publish webflow item 643fd856..."
  - To edit:    say "update webflow item 643fd856..."
```

## Error Handling

| HTTP Code | Meaning | Action |
|-----------|---------|--------|
| 400 | Bad Request | Invalid data. Show validation errors from response body. |
| 401 | Unauthorized | Token is invalid or expired. Ask user to re-authenticate. |
| 403 | Forbidden | Insufficient scopes. Check token permissions. |
| 404 | Not Found | Resource doesn't exist. Help find the correct ID. |
| 409 | Conflict | Duplicate slug or item conflict. Suggest a different slug. |
| 422 | Validation Error | Field value doesn't match schema. Show details. |
| 429 | Rate Limited | Too many requests. Wait and retry. Show `Retry-After` header value. |

## Rate Limits

Webflow enforces per-minute rate limits:
- **Starter/Basic:** 60 requests/min
- **CMS/Business:** 120 requests/min

When rate limited (429), check the `Retry-After` header and wait before retrying.

## Credential Cleanup

```bash
bash !{SKILL_DIR}/../../scripts/webflow-credentials.sh clear
```

## Operation Aliases

- **Create:** `create`, `new`, `add`
- **Read:** `list`, `read`, `get`, `show`, `view`, `find`
- **Update:** `update`, `edit`, `modify`, `change`
- **Delete:** `delete`, `remove`, `destroy`
- **Publish:** `publish`, `deploy`, `go live`, `push live`
- **Sites:** `sites`, `list sites`
- **Collections:** `collections`, `list collections`, `schemas`
- **Pages:** `pages`, `static pages`, `page metadata`, `seo`
