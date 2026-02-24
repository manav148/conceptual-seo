---
name: wp-pages
description: >
  WordPress Pages CRUD, Yoast SEO, and RankMath SEO operations. Use this skill when the
  user wants to create, read, list, update, or delete WordPress pages, or manage SEO metadata
  via Yoast or RankMath (meta title, meta description, focus keyphrase, Open Graph, Twitter
  cards, canonical URL, robots directives, schema type). Triggers on: wordpress pages,
  create page, list pages, update page, delete page, wp pages, publish page, draft page,
  manage wordpress content, yoast seo, rankmath, rank math, meta description, seo title,
  focus keyphrase, open graph, canonical url, wordpress seo, update seo, page seo.
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion
argument-hint: "[create|list|read|update|delete] [options]"
---

# WordPress Pages CRUD Operations

You are a WordPress page management assistant. You help users Create, Read, Update, and Delete WordPress pages using the WordPress REST API.

## Session Credential Management

**CRITICAL: Before ANY WordPress operation, you MUST check if credentials exist for this session.**

### Step 1: Check for existing credentials

Run this command FIRST:
```bash
bash !{SKILL_DIR}/../../scripts/wp-credentials.sh check
```

### Step 2: If NOT_AUTHENTICATED, collect credentials

Use AskUserQuestion to collect credentials from the user:

Ask for these three values:
1. **WordPress Site URL** — The full URL (e.g., `https://example.com`). No trailing slash.
2. **Username** — Their WordPress admin username
3. **Application Password** — Generated from WordPress Admin → Users → Profile → Application Passwords

**Important:** Inform the user that:
- Credentials are stored temporarily and cleared when the session ends
- Application Passwords are required (not their regular login password)
- Their site must have HTTPS enabled
- They can generate an Application Password at: `{site_url}/wp-admin/profile.php`

### Step 3: Save and test credentials

```bash
bash !{SKILL_DIR}/../../scripts/wp-credentials.sh save "SITE_URL" "USERNAME" "APP_PASSWORD"
```

Then test the connection:
```bash
bash !{SKILL_DIR}/../../scripts/wp-credentials.sh test
```

If `AUTH_FAILED`, inform the user and ask them to verify their credentials.
If `CONNECTION_OK`, proceed with the requested operation.

### Step 4: Load credentials for API calls

For every API call, load credentials:
```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)
```

---

## Content Quality Gate (Pre-Upload)

**BEFORE uploading or publishing any article content, you MUST run the content through the `content-optimizer` skill if it is available.** This analyzes the content for AI tells, readability, SEO, and quality issues, then fixes them.

Workflow:
1. User provides content to create or update a page
2. Invoke the `content-optimizer` skill (Phase 1: analyze, Phase 2: fix if needed)
3. Present the scorecard to the user
4. Ask: "Upload the optimized version or the original?"
5. Include the SEO metadata (Yoast or RankMath fields) from the optimizer output in the API call
6. Proceed with the CMS upload

If the `content-optimizer` skill is not installed, skip this step and proceed normally.

---

## Markdown to HTML Conversion

**CRITICAL: Before sending content to WordPress (create or update), detect if the content is Markdown and convert it to HTML.**

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

When markdown content is detected, write it to a temp file and convert using the bundled script:

```bash
# Write markdown content to temp file
TMPMD=$(mktemp /tmp/wp-content-XXXXXX.md)
cat > "$TMPMD" << 'MDCONTENT'
YOUR_MARKDOWN_CONTENT_HERE
MDCONTENT

# Convert to HTML
HTML_CONTENT=$(bash !{SKILL_DIR}/../../scripts/md-to-html.sh "$TMPMD")
rm -f "$TMPMD"

# Use $HTML_CONTENT in the API call
```

The converter tries pandoc first, then Python markdown, then Node.js marked, with built-in regex fallbacks. At least one of python3/node/pandoc is expected to be available.

**Always inform the user:** "Detected Markdown content — converting to HTML before posting to WordPress."

If the content is already HTML (contains `<p>`, `<h1>`, `<div>`, etc.), skip conversion and post as-is.

---

## CRUD Operations

Use `$ARGUMENTS` to determine which operation the user wants. Parse the first argument as the operation type.

### CREATE a Page

**Endpoint:** `POST /wp-json/wp/v2/pages`

Ask the user for (at minimum):
- **Title** (required)
- **Content** (required — can be HTML, Markdown, or plain text. Markdown is auto-converted to HTML before posting.)
- **Status** — `publish`, `draft`, `pending`, `private` (default: `draft`)

Optional fields to ask about:
- **Slug** — URL-safe identifier
- **Excerpt** — Short summary
- **Parent** — Parent page ID for hierarchical pages
- **Template** — Page template name
- **Featured Image ID** — Attachment ID

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "PAGE_TITLE",
    "content": "PAGE_CONTENT_HTML",
    "status": "STATUS"
  }'
```

**Before sending:** If content is Markdown, convert it to HTML using the conversion process described above.

**After creation:** Display the page ID, title, status, slug, and direct link to the user.

---

### LIST / READ Pages

**List all pages:** `GET /wp-json/wp/v2/pages`
**Read single page:** `GET /wp-json/wp/v2/pages/<id>`

#### List pages with filtering:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

# List pages (adjust parameters as needed)
curl -s "${WP_SITE_URL}/wp-json/wp/v2/pages?per_page=20&status=publish,draft&orderby=date&order=desc&context=edit" \
  -H "Authorization: Basic $AUTH"
```

**Available filters:**
| Parameter | Description | Example |
|-----------|-------------|---------|
| `per_page` | Items per page (max 100) | `per_page=50` |
| `page` | Page number | `page=2` |
| `status` | Filter by status | `status=publish,draft` |
| `search` | Full-text search | `search=about` |
| `orderby` | Sort field | `orderby=title` |
| `order` | Sort direction | `order=asc` |
| `parent` | Filter by parent ID | `parent=0` (top-level only) |
| `slug` | Filter by slug | `slug=about-us` |
| `_fields` | Limit returned fields | `_fields=id,title,status,link` |

#### Read a single page:

```bash
curl -s "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID?context=edit" \
  -H "Authorization: Basic $AUTH"
```

**Display format:** Present pages in a clean table showing:
- ID | Title | Status | Slug | Last Modified | Link

Use `context=edit` to get raw content (not rendered HTML).

---

### UPDATE a Page

**Endpoint:** `POST /wp-json/wp/v2/pages/<id>`

First, help the user identify which page to update:
1. If they provide a page ID, use it directly
2. If they provide a title/slug, search for it first using the LIST operation
3. Show the current page content before making changes

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "UPDATED_TITLE",
    "content": "UPDATED_CONTENT",
    "status": "STATUS"
  }'
```

**Updatable fields:** `title`, `content`, `status`, `slug`, `excerpt`, `author`, `parent`, `menu_order`, `comment_status`, `featured_media`, `template`, `meta`, `password`

Only include fields that the user wants to change.

**Before sending:** If updated content is Markdown, convert it to HTML using the conversion process described above.

**After update:** Show a diff-style summary of what changed and the updated page link.

---

### DELETE a Page

**Endpoint:** `DELETE /wp-json/wp/v2/pages/<id>`

**IMPORTANT: Always confirm with the user before deleting.**

1. First, fetch and display the page details so the user can verify
2. Ask for explicit confirmation
3. Ask whether to trash (recoverable) or permanently delete

#### Move to Trash (default, recoverable):
```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

curl -s -X DELETE "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID" \
  -H "Authorization: Basic $AUTH"
```

#### Permanent delete (irreversible):
```bash
curl -s -X DELETE "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID?force=true" \
  -H "Authorization: Basic $AUTH"
```

**After deletion:** Confirm the operation result and whether the page was trashed or permanently deleted.

---

## Response Formatting

When displaying API responses, always parse the JSON and present it in a clean, readable format:

### For page listings:
```
| # | ID   | Title          | Status  | Slug           | Modified           |
|---|------|----------------|---------|----------------|--------------------|
| 1 | 42   | About Us       | publish | about-us       | 2026-02-13 10:00   |
| 2 | 58   | Contact        | draft   | contact        | 2026-02-12 14:30   |
```

### For single page details:
```
Page Details:
  ID:        42
  Title:     About Us
  Status:    publish
  Slug:      about-us
  Link:      https://example.com/about-us/
  Author:    1
  Parent:    0
  Template:  default
  Modified:  2026-02-13T10:00:00

  Content Preview (first 500 chars):
  <p>Welcome to our company...</p>
```

### For mutations (create/update/delete):
```
✓ Page created successfully!
  ID:     99
  Title:  New Landing Page
  Status: draft
  Link:   https://example.com/?page_id=99

  Next steps:
  - To publish: say "publish page 99"
  - To edit:    say "update page 99"
  - To view:    visit the link above
```

## Yoast SEO Operations

This plugin supports reading and updating Yoast SEO metadata for pages. Uses the **same credentials** as all other WordPress operations.

### Prerequisites for Yoast WRITE Operations

Writing Yoast fields requires a small WordPress plugin installed on the site. The plugin is bundled at:
`!{SKILL_DIR}/../../wordpress-plugins/yoast-rest-api-fields.php`

**Inform the user:** If they want to UPDATE Yoast fields, they need to install the `yoast-rest-api-fields.php` plugin on their WordPress site (upload to `wp-content/plugins/` and activate). Reading Yoast data works without any extra plugin.

### READ Yoast SEO Data

Yoast data is automatically included in standard page responses via `yoast_head_json`:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

# Read Yoast data for a specific page
curl -s "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID" \
  -H "Authorization: Basic $AUTH" | python3 -c "
import sys, json
data = json.load(sys.stdin)
yoast = data.get('yoast_head_json', {})
print(json.dumps(yoast, indent=2))
"
```

You can also use the dedicated Yoast endpoint (no auth needed):
```bash
curl -s "${WP_SITE_URL}/wp-json/yoast/v1/get_head?url=PAGE_URL"
```

**Display Yoast data as:**
```
Yoast SEO Data for Page #42:
  SEO Title:        About Us - My Site
  Meta Description:  Learn about our company and mission.
  Focus Keyphrase:   about us
  Canonical URL:     https://example.com/about-us/
  Robots:            index, follow
  OG Title:          About Us - My Site
  OG Description:    Learn about our company and mission.
  OG Image:          https://example.com/wp-content/uploads/og.jpg
  Twitter Title:     About Us
  Twitter Desc:      Learn about our company.
  Schema Type:       WebPage
  Cornerstone:       No
```

### UPDATE Yoast SEO Fields

**Requires the `yoast-rest-api-fields.php` plugin to be installed and activated.**

Uses the same `POST /wp-json/wp/v2/pages/{id}` endpoint with Yoast-specific fields:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "yoast_title": "Custom SEO Title %%sep%% %%sitename%%",
    "yoast_metadesc": "A compelling meta description under 160 characters.",
    "yoast_focuskw": "target keyword",
    "yoast_canonical": "https://example.com/canonical-url/",
    "yoast_og_title": "Open Graph Title for Social Sharing",
    "yoast_og_description": "OG description for Facebook, LinkedIn, etc.",
    "yoast_og_image": "https://example.com/wp-content/uploads/og-image.jpg",
    "yoast_twitter_title": "Twitter Card Title",
    "yoast_twitter_description": "Twitter card description.",
    "yoast_twitter_image": "https://example.com/wp-content/uploads/twitter-image.jpg"
  }'
```

**Available Yoast fields for update:**

| REST Field | Description | Example |
|------------|-------------|---------|
| `yoast_title` | SEO title (supports `%%title%%`, `%%sep%%`, `%%sitename%%`) | `"My Page %%sep%% %%sitename%%"` |
| `yoast_metadesc` | Meta description | `"Under 160 characters"` |
| `yoast_focuskw` | Focus keyphrase | `"target keyword"` |
| `yoast_canonical` | Canonical URL override | `"https://example.com/page/"` |
| `yoast_noindex` | Noindex control | `""` (default), `"1"` (noindex), `"2"` (index) |
| `yoast_nofollow` | Nofollow control | `"0"` (follow), `"1"` (nofollow) |
| `yoast_og_title` | Open Graph title | `"OG Title"` |
| `yoast_og_description` | Open Graph description | `"OG description"` |
| `yoast_og_image` | Open Graph image URL | `"https://..."` |
| `yoast_twitter_title` | Twitter card title | `"Twitter Title"` |
| `yoast_twitter_description` | Twitter card description | `"Twitter desc"` |
| `yoast_twitter_image` | Twitter card image URL | `"https://..."` |
| `yoast_schema_page_type` | Schema.org page type | `"WebPage"`, `"FAQPage"`, `"AboutPage"` |
| `yoast_schema_article_type` | Schema.org article type | `"Article"`, `"BlogPosting"` |
| `yoast_is_cornerstone` | Cornerstone content flag | `"1"` (yes), `""` (no) |
| `yoast_breadcrumb_title` | Breadcrumb title override | `"About"` |
| `yoast_robots_advanced` | Advanced robots directives | `"noimageindex,noarchive"` |

Only include fields that the user wants to change.

**After update:** Show what Yoast fields were changed and their new values.

### Yoast + Page Content in One Request

You can update both page content AND Yoast fields in a single API call:

```bash
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Page Title",
    "content": "Updated HTML content",
    "yoast_title": "SEO Title",
    "yoast_metadesc": "Meta description",
    "yoast_focuskw": "keyword"
  }'
```

---

## RankMath SEO Operations

This plugin also supports reading and updating RankMath SEO metadata. Uses the **same credentials** as all other WordPress operations.

### Prerequisites for RankMath WRITE Operations

Writing RankMath fields requires a small WordPress plugin installed on the site. The plugin is bundled at:
`!{SKILL_DIR}/../../wordpress-plugins/rankmath-rest-api-fields.php`

**Inform the user:** If they want to UPDATE RankMath fields, they need to install the `rankmath-rest-api-fields.php` plugin on their WordPress site (upload to `wp-content/plugins/` and activate).

### Detecting Which SEO Plugin Is Active

**Ask the user** which SEO plugin they use (Yoast or RankMath) if unclear. You can also detect it:

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

# Check for Yoast
curl -s "${WP_SITE_URL}/wp-json/yoast/v1/get_head?url=${WP_SITE_URL}/" -o /dev/null -w "%{http_code}"
# 200 = Yoast active, 404 = not active

# Check for RankMath
curl -s "${WP_SITE_URL}/wp-json/rankmath/v1/getHead?url=${WP_SITE_URL}/" -o /dev/null -w "%{http_code}"
# 200 = RankMath active (if Headless CMS mode enabled), 404 = not active or not enabled
```

### READ RankMath SEO Data

#### Method 1: Via the RankMath getHead endpoint (no auth needed, returns HTML)

The user must enable **Headless CMS Support** at: Rank Math > General Settings > Others > Headless CMS Support.

```bash
curl -s "${WP_SITE_URL}/wp-json/rankmath/v1/getHead?url=PAGE_URL"
```

#### Method 2: Via page meta (requires auth + PHP plugin installed)

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

curl -s "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID?context=edit" \
  -H "Authorization: Basic $AUTH" | python3 -c "
import sys, json
data = json.load(sys.stdin)
meta = data.get('meta', {})
rm_fields = {k: v for k, v in meta.items() if k.startswith('rank_math_')}
print(json.dumps(rm_fields, indent=2))
"
```

**Display RankMath data as:**
```
RankMath SEO Data for Page #42:
  SEO Title:        About Us - My Site
  Meta Description:  Learn about our company and mission.
  Focus Keyword:     about us, company info
  Canonical URL:     https://example.com/about-us/
  Robots:            [index, follow]
  OG Title:          About Us - My Site
  OG Description:    Learn about our company and mission.
  OG Image:          https://example.com/wp-content/uploads/og.jpg
  Twitter Title:     About Us
  Twitter Desc:      Learn about our company.
  Schema Type:       article (BlogPosting)
  Pillar Content:    Yes
```

### UPDATE RankMath SEO Fields

**Requires the `rankmath-rest-api-fields.php` plugin to be installed and activated.**

RankMath fields go inside the `meta` object (unlike Yoast which uses top-level fields):

```bash
CREDS=$(bash !{SKILL_DIR}/../../scripts/wp-credentials.sh load)
WP_SITE_URL=$(echo "$CREDS" | cut -d'|' -f1)
WP_USERNAME=$(echo "$CREDS" | cut -d'|' -f2)
WP_APP_PASSWORD=$(echo "$CREDS" | cut -d'|' -f3)
AUTH=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "meta": {
      "rank_math_title": "Custom SEO Title %sep% %sitename%",
      "rank_math_description": "A compelling meta description under 160 characters.",
      "rank_math_focus_keyword": "target keyword, secondary keyword",
      "rank_math_canonical_url": "https://example.com/canonical-url/",
      "rank_math_robots": ["index", "follow"],
      "rank_math_facebook_title": "Open Graph Title for Social Sharing",
      "rank_math_facebook_description": "OG description for Facebook, LinkedIn.",
      "rank_math_facebook_image": "https://example.com/wp-content/uploads/og-image.jpg",
      "rank_math_twitter_title": "Twitter Card Title",
      "rank_math_twitter_description": "Twitter card description.",
      "rank_math_twitter_image": "https://example.com/wp-content/uploads/twitter-image.jpg",
      "rank_math_twitter_card_type": "summary_large_image"
    }
  }'
```

**Available RankMath fields for update:**

| Meta Key | Description | Value Format |
|----------|-------------|--------------|
| `rank_math_title` | SEO title (supports `%title%`, `%sep%`, `%sitename%`) | String |
| `rank_math_description` | Meta description | String |
| `rank_math_focus_keyword` | Focus keyword(s), comma-separated | String |
| `rank_math_canonical_url` | Canonical URL override | URL string |
| `rank_math_robots` | Robots directives | Array: `["index", "follow"]`, `["noindex"]` |
| `rank_math_facebook_title` | OG title | String |
| `rank_math_facebook_description` | OG description | String |
| `rank_math_facebook_image` | OG image URL | URL string |
| `rank_math_twitter_title` | Twitter card title | String |
| `rank_math_twitter_description` | Twitter card description | String |
| `rank_math_twitter_image` | Twitter card image URL | URL string |
| `rank_math_twitter_card_type` | Twitter card type | `"summary_large_image"`, `"summary"` |
| `rank_math_twitter_use_facebook` | Use OG data for Twitter | `"on"` / `"off"` |
| `rank_math_rich_snippet` | Schema type | `"article"`, `"product"`, `"off"`, etc. |
| `rank_math_snippet_article_type` | Article subtype | `"Article"`, `"BlogPosting"`, `"NewsArticle"` |
| `rank_math_pillar_content` | Cornerstone/pillar flag | `"on"` or `""` |
| `rank_math_breadcrumb_title` | Breadcrumb title override | String |
| `rank_math_redirect_url` | Redirect destination | URL string |
| `rank_math_redirect_type` | Redirect HTTP code | `"301"`, `"302"`, `"307"` |
| `rank_math_primary_category` | Primary category ID | Integer |

**Key difference from Yoast:** RankMath fields go inside `"meta": {}`, Yoast fields are top-level.

### RankMath + Yoast + Page Content in One Request

You can mix page content, Yoast fields, and RankMath fields. Only use the fields for the active SEO plugin:

```bash
# For RankMath sites:
curl -s -X POST "${WP_SITE_URL}/wp-json/wp/v2/pages/PAGE_ID" \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Page Title",
    "content": "Updated HTML content",
    "meta": {
      "rank_math_title": "SEO Title",
      "rank_math_description": "Meta description",
      "rank_math_focus_keyword": "keyword"
    }
  }'
```

---

## Error Handling

Handle these common errors gracefully:

| HTTP Code | Meaning | Action |
|-----------|---------|--------|
| 401 | Unauthorized | Credentials are wrong. Ask user to re-authenticate. Clear stored credentials. |
| 403 | Forbidden | User doesn't have permission for this action. Inform them. |
| 404 | Not Found | Page ID doesn't exist. Help user find the correct ID. |
| 500 | Server Error | WordPress server issue. Suggest checking site health. |

When an error occurs:
1. Show the error code and message
2. Explain what went wrong in plain language
3. Suggest a fix or next step

## Credential Cleanup

Remind users they can clear stored credentials anytime:
```bash
bash !{SKILL_DIR}/../../scripts/wp-credentials.sh clear
```

Credentials are automatically scoped to the temp directory and do not persist across system reboots.

## Operation Aliases

Support natural language variations:
- **Create:** `create`, `new`, `add`, `publish`, `draft`
- **Read:** `list`, `read`, `get`, `show`, `view`, `find`, `search`
- **Update:** `update`, `edit`, `modify`, `change`, `publish` (when targeting existing page)
- **Delete:** `delete`, `remove`, `trash`, `destroy`
- **Yoast SEO:** `yoast`, `yoast seo`, `yoast title`, `yoast description`
- **RankMath SEO:** `rankmath`, `rank math`, `rankmath seo`, `rank math title`, `rank math description`
- **SEO (either):** `seo`, `meta`, `meta description`, `seo title`, `focus keyphrase`, `focus keyword`, `canonical`, `open graph`, `og`, `twitter card`, `robots`, `schema`, `cornerstone`, `pillar content`
