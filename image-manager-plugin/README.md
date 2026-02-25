# Image Manager Plugin

Multi-CMS image library manager for Claude Code. Searches a local folder and/or CMS media library, auto-matches images to posts by keyword, uploads, and sets featured images or inserts inline.

## Supported CMS
- **WordPress** (via REST API + existing wp-credentials)
- **Ghost** (via Ghost Admin API)
- **Webflow** (via Webflow API v2)

## Skills
- `image-manager:image-manager` — Main skill

## Usage Examples

```
set featured images on all of Manav's drafts
find an image for post 46689
list my local images matching "pool"
set image folder to /Users/ana/Dropbox/Images
insert an image into the top of post 46672
```

## Configuration
The local image folder is stored in a temp config file and must be set once per session:
- Set: `image-config.sh set-folder "/path"`
- Check: `image-config.sh check`
- Clear: `image-config.sh clear`

## Scripts
| Script | Purpose |
|--------|---------|
| `image-config.sh` | Manage local folder path configuration |
| `list-images.sh` | List images from local folder or CMS media library |
| `upload-image.sh` | Upload a local image to WP / Ghost / Webflow |
| `set-featured.sh` | Set featured/thumbnail image on a post |
