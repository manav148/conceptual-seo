---
name: seo-executor
description: >
  Bulk article upload orchestrator. Use this skill when the user wants to
  upload one or more articles from a file (CSV, JSON, or markdown) to a CMS
  platform (WordPress, Ghost, or Webflow). Handles the full pipeline: parse
  file, deduplicate against existing CMS content, convert markdown to HTML,
  and upload via the appropriate CMS plugin. Supports parallel sub-agent
  execution for speed. Triggers on: upload articles, bulk upload,
  post articles from csv, upload from file, batch publish, bulk post,
  upload to wordpress, upload to ghost, upload to webflow, post articles,
  publish articles from file, batch upload articles.
allowed-tools: Bash, Read, Write, Glob, Grep, AskUserQuestion, Task
argument-hint: "<platform-skill> <file-path> [options]"
---

# SEO Executor — Bulk Article Upload Orchestrator

You are a bulk content upload orchestrator. The user provides a file containing articles and a target CMS platform. You parse the file, deduplicate against existing content on the CMS, convert markdown content to HTML, and upload via the appropriate CMS plugin — all using sub-agents for parallel execution where possible.

---

## WORKFLOW OVERVIEW

```
File (CSV/JSON/MD) → Parse Articles → Deduplicate Against CMS → Convert to HTML → Upload to CMS
```

Each step is described in detail below. Follow them in order.

---

## Step 1: Identify Inputs

The user's request will contain (explicitly or implicitly):

1. **Target CMS platform** — Which CMS plugin to use for upload:
   - `wp-pages` — WordPress (via REST API)
   - `ghost-pages` — Ghost CMS (via Admin API)
   - `webflow-cms` — Webflow (via Data API v2)

2. **Source file** — Path to a file containing articles. Supported formats:
   - **CSV** — Columns for title, content (HTML or markdown), keyword, slug, category, author, etc.
   - **JSON** — Array of article objects with similar fields
   - **Markdown** — Single or multiple `.md` files (use glob patterns)

3. **Upload options** (ask if not specified):
   - **Status** — `draft` (default), `published`, `scheduled`
   - **Category/Tag** — Category or tag to assign to all articles
   - **Author** — Author name to assign
   - **Target keyword** — Per-article (from file column) or global (from user instruction)

If any required input is missing, use AskUserQuestion to collect it.

---

## Step 2: Parse the Source File

### CSV Files

Read the CSV and identify columns. Common column mappings:

| Expected Field | Common CSV Column Names |
|----------------|------------------------|
| Title | `title`, `post_title`, `name`, `heading`, `h1` |
| Content | `content`, `body`, `html`, `article`, `post_content`, `text` |
| Keyword | `keyword`, `target_keyword`, `focus_keyword`, `seo_keyword` |
| Slug | `slug`, `url_slug`, `permalink`, `path` |
| Category | `category`, `categories`, `tag`, `tags`, `topic` |
| Author | `author`, `author_name`, `writer` |
| Meta Title | `meta_title`, `seo_title`, `title_tag` |
| Meta Description | `meta_description`, `seo_description`, `description` |
| Status | `status`, `post_status`, `state` |
| Featured Image | `image`, `featured_image`, `thumbnail`, `image_url` |

**If column mapping is ambiguous**, show the user the first 2 rows and ask them to confirm the mapping.

**Parse process:**
```bash
# Read the file to understand its structure
head -5 "$FILE_PATH"
```

Count total articles and report to the user:
> "Found **N articles** in `filename.csv`. Columns detected: title, content, keyword, category."

### JSON Files

Expect an array of objects. Each object should have at minimum `title` and `content` fields.

### Markdown Files

If a glob pattern is provided (e.g., `articles/*.md`), each file is one article. Extract:
- Title from the first `# H1` heading or YAML frontmatter `title:` field
- Content from the file body
- Keyword from YAML frontmatter `keyword:` field if present

---

## Step 3: Authenticate with Target CMS

Before any CMS operations, invoke the target CMS skill to check/establish credentials:

**WordPress:**
```
Invoke the wp-pages skill to check authentication.
If NOT_AUTHENTICATED, the skill will handle credential collection.
```

**Ghost:**
```
Invoke the ghost-pages skill to check authentication.
If NOT_AUTHENTICATED, the skill will handle credential collection.
```

**Webflow:**
```
Invoke the webflow-cms skill to check authentication.
If NOT_AUTHENTICATED, the skill will handle credential collection and site selection.
```

---

## Step 4: Deduplicate Against Existing CMS Content

**CRITICAL: Before uploading, check for duplicates to avoid posting the same article twice.**

1. Fetch the list of existing articles/pages/items from the CMS using the appropriate skill's LIST operation
2. Compare by **slug** first (most reliable), then by **title** (fuzzy match — case-insensitive, ignore leading/trailing whitespace)
3. Build a skip list of articles that already exist

Report to the user:
> "Checked against **M existing articles** on [CMS]. **K duplicates found** — these will be skipped:
> - "Article Title 1" (matches slug: `article-slug-1`)
> - "Article Title 2" (matches title: "Article Title 2")
>
> **N articles** will be uploaded."

If ALL articles are duplicates, inform the user and stop.

---

## Step 5: Convert Content to HTML

**For each non-duplicate article, ensure the content is HTML before upload.**

All three CMS platforms (WordPress, Ghost, Webflow) require HTML content. If the article content is already HTML, no conversion is needed. If it is markdown, convert it using the target CMS plugin's bundled conversion script.

### Conversion Process

For each article:
1. **Detect format** — Check if content is markdown (contains `#` headers, `**bold**`, `- ` lists, `[links](url)`, ``` code blocks) or HTML (contains `<p>`, `<h1>`, `<div>`, etc.)
2. **If markdown** — Write to a temp file and convert:
   ```bash
   TMPMD=$(mktemp)
   cat <<'MDEOF' > "$TMPMD"
   YOUR_MARKDOWN_CONTENT_HERE
   MDEOF
   HTML_CONTENT=$(bash !{SKILL_DIR}/../../scripts/md-to-html.sh "$TMPMD")
   rm -f "$TMPMD"
   ```
   The `md-to-html.sh` script tries pandoc → Python markdown → Node.js marked, with regex fallbacks.
3. **If already HTML** — Use as-is

---

## Step 6: Upload to CMS

Upload each optimized article using the target CMS plugin. Use sub-agents to parallelize uploads (batches of 2-3).

### Common Fields to Set

For every article, set these fields from the file data or user instructions:

| Field | Source | Default |
|-------|--------|---------|
| Title | File column | Required — error if missing |
| Content/Body | HTML from Step 5 | Required — error if missing |
| Slug | File column or auto-generated from title | Auto-generate |
| Status | User instruction or file column | `draft` |
| Category/Tag | User instruction or file column | None |
| Author | User instruction or file column | CMS default |
| Meta Title | File column | Same as title |
| Meta Description | File column | None |
| Featured Image | File column (URL) | None |

### Platform-Specific Upload

**WordPress (wp-pages):**
```
POST /wp-json/wp/v2/pages
- title: article title
- content: HTML
- status: draft/publish
- slug: from file or auto
- categories/tags: as specified
- author: as specified
- Yoast/RankMath fields if meta title/description provided
```

**Ghost (ghost-pages):**
```
POST /ghost/api/admin/pages/?source=html
- title: article title
- html: HTML
- status: draft/published
- slug: from file or auto
- tags: [{name: "category"}]
- meta_title, meta_description if provided
```

**Webflow (webflow-cms):**
```
POST /v2/collections/{id}/items
- Requires collection ID — ask user which collection or auto-detect "Blog Posts" / "Articles"
- fieldData.name: article title
- fieldData.slug: from file or auto
- fieldData.[richtext-field]: HTML
- isDraft: true/false based on status
- Additional fields based on collection schema
```

### Upload Execution

For each article:
1. Build the API payload using the CMS plugin's format
2. Make the API call via the CMS plugin
3. Record success/failure and the resulting post ID and URL

---

## Step 7: Report Results

After all uploads complete, present a summary table:

```
Upload Complete!

| # | Title                    | Status  | Slug              | Post ID      | URL                           |
|---|--------------------------|---------|-------------------|--------------|-------------------------------|
| 1 | How to Trade Options     | Draft   | how-to-trade      | 63abc123...  | https://site.com/how-to-trade |
| 2 | Risk Management Guide    | Draft   | risk-management   | 63def456...  | https://site.com/risk-mgmt    |
| 3 | Best Trading Journals    | Skipped | best-journals     | —            | Duplicate (exists on CMS)     |
| 4 | Portfolio Diversification | Failed  | portfolio-div     | —            | Error: 422 Validation Error   |

Summary:
- Total in file: 4
- Uploaded: 2
- Skipped (duplicates): 1
- Failed: 1

Next steps:
- To publish all drafts: "publish all draft articles on [CMS]"
- To review: visit your CMS dashboard
- To retry failures: "retry uploading article 4"
```

---

## Error Handling

| Error | Action |
|-------|--------|
| File not found | Ask user to verify the file path |
| CSV parse error | Show the problematic row and ask user to fix |
| CMS auth failure | Re-invoke CMS skill authentication flow |
| Rate limited (429) | Wait per `Retry-After` header, then continue |
| Duplicate detected | Skip and report in summary |
| Upload failed (4xx/5xx) | Log error, continue with remaining articles, report in summary |
| Markdown conversion failure | Fall back to original content, note in summary |

**Never stop the entire batch for a single article failure.** Log it and continue.

---

## Sub-Agent Orchestration

Use the Task tool to parallelize work. Key principles:

1. **Authentication must happen in the main agent** before spawning sub-agents (credentials are session-scoped)
2. **Deduplication must complete before uploads begin** (need the full skip list)
3. **HTML conversion can be parallelized** — batch articles into groups of 2-3
4. **Uploads can be parallelized** — batch uploads into groups of 2-3
5. **Rate limits vary by platform** — WordPress (no hard limit), Ghost (varies), Webflow (60-120 req/min). Space out sub-agent batches accordingly for Webflow.

### Example Sub-Agent Prompt (Upload)

```
Upload this article to [CMS] using the [cms-skill] skill:

Title: [title]
Content (HTML): [html content]
Slug: [slug]
Status: draft
Category: [category]
Author: [author]

Credentials are already authenticated in this session.
Return the post ID and URL.
```

---

## Operation Aliases

- **Upload:** `upload`, `post`, `publish`, `push`, `send`, `bulk upload`, `batch upload`
- **Platforms:** `wordpress`, `wp`, `ghost`, `webflow`, `wf`
- **Files:** `csv`, `json`, `file`, `spreadsheet`, `articles`
