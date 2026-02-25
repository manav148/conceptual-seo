#!/usr/bin/env bash
# list-images.sh — List images from local folder and/or CMS media library
# Usage:
#   list-images.sh local [keyword]               — list local images, optional keyword filter
#   list-images.sh wp [keyword] AUTH SITE_URL    — list WordPress media library
#   list-images.sh ghost [keyword] AUTH SITE_URL — list Ghost media (from posts)
#   list-images.sh all [keyword] AUTH SITE_URL   — local + CMS

SOURCE="${1}"
KEYWORD="${2}"
AUTH="${3}"
SITE_URL="${4}"

CONFIG_FILE="${TMPDIR:-/tmp}/image-manager-config.env"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

IMAGE_EXTENSIONS="jpg|jpeg|png|gif|webp|svg|avif"

list_local() {
  if [ -z "$IMAGE_FOLDER" ] || [ ! -d "$IMAGE_FOLDER" ]; then
    echo "LOCAL_NOT_CONFIGURED"
    return
  fi

  echo "=== LOCAL: ${IMAGE_FOLDER} ==="
  if [ -n "$KEYWORD" ]; then
    find "$IMAGE_FOLDER" -type f | grep -iE "($KEYWORD)" | grep -iE "\.($IMAGE_EXTENSIONS)$" | while read -r f; do
      SIZE=$(du -sh "$f" 2>/dev/null | cut -f1)
      BASENAME=$(basename "$f")
      echo "  [LOCAL] ${BASENAME} | ${SIZE} | ${f}"
    done
  else
    find "$IMAGE_FOLDER" -type f | grep -iE "\.($IMAGE_EXTENSIONS)$" | head -30 | while read -r f; do
      SIZE=$(du -sh "$f" 2>/dev/null | cut -f1)
      BASENAME=$(basename "$f")
      echo "  [LOCAL] ${BASENAME} | ${SIZE} | ${f}"
    done
  fi
}

list_wp() {
  if [ -z "$AUTH" ] || [ -z "$SITE_URL" ]; then
    echo "WP_MISSING_CREDS"
    return
  fi

  SEARCH_PARAM=""
  [ -n "$KEYWORD" ] && SEARCH_PARAM="&search=${KEYWORD}"

  echo "=== WORDPRESS MEDIA LIBRARY: ${SITE_URL} ==="
  curl -s "${SITE_URL}/wp-json/wp/v2/media?per_page=20&media_type=image${SEARCH_PARAM}" \
    -H "Authorization: Basic ${AUTH}" \
    -H "User-Agent: Mozilla/5.0" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, dict) and 'code' in data:
    print(f'  ERROR: {data.get(\"code\")}')
else:
    for m in data:
        mid = m.get('id')
        title = m.get('title', {}).get('rendered', 'untitled')[:50]
        url = m.get('source_url', '')
        alt = m.get('alt_text', '')
        print(f'  [WP:{mid}] {title} | {url}')
" 2>/dev/null || echo "  ERROR: Could not reach WP media library"
}

list_ghost() {
  echo "=== GHOST: Image listing via Ghost Admin API not yet supported. Use local folder. ==="
}

case "$SOURCE" in
  local) list_local ;;
  wp)    list_wp ;;
  ghost) list_ghost ;;
  all)
    list_local
    echo ""
    list_wp
    ;;
  *)
    echo "Usage: list-images.sh [local|wp|ghost|all] [keyword] [auth] [site_url]"
    exit 1
    ;;
esac
