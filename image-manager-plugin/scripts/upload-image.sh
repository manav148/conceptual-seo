#!/usr/bin/env bash
# upload-image.sh — Upload a local image to a CMS media library
# Usage:
#   upload-image.sh wp   FILE_PATH AUTH SITE_URL [alt_text]
#   upload-image.sh ghost FILE_PATH GHOST_ADMIN_KEY SITE_URL [alt_text]
#   upload-image.sh webflow FILE_PATH WEBFLOW_TOKEN SITE_ID [alt_text]
#
# Returns: UPLOADED|media_id|url  on success
#          ERROR|message          on failure

CMS="${1}"
FILE_PATH="${2}"
AUTH_OR_KEY="${3}"
SITE_URL="${4}"
ALT_TEXT="${5:-}"

if [ ! -f "$FILE_PATH" ]; then
  echo "ERROR|File not found: ${FILE_PATH}"
  exit 1
fi

FILENAME=$(basename "$FILE_PATH")
MIME_TYPE=$(file --mime-type -b "$FILE_PATH" 2>/dev/null || echo "image/jpeg")

case "$CMS" in
  wp)
    RESULT=$(curl -s -X POST "${SITE_URL}/wp-json/wp/v2/media" \
      -H "Authorization: Basic ${AUTH_OR_KEY}" \
      -H "User-Agent: Mozilla/5.0" \
      -H "Content-Disposition: attachment; filename=\"${FILENAME}\"" \
      -H "Content-Type: ${MIME_TYPE}" \
      --data-binary @"${FILE_PATH}")

    python3 -c "
import sys, json
data = json.loads('''${RESULT}'''.replace(\"'''\", ''))
if 'code' in data:
    print(f'ERROR|{data.get(\"code\")}: {data.get(\"message\",\"\")[:80]}')
else:
    mid = data.get('id')
    url = data.get('source_url', '')
    print(f'UPLOADED|{mid}|{url}')
" 2>/dev/null || echo "ERROR|Failed to parse WP response"
    ;;

  ghost)
    # Ghost image upload endpoint
    RESULT=$(curl -s -X POST "${SITE_URL}/ghost/api/admin/images/upload/" \
      -H "Authorization: Ghost ${AUTH_OR_KEY}" \
      -F "file=@${FILE_PATH};type=${MIME_TYPE}" \
      -F "purpose=image")

    python3 -c "
import sys, json
try:
    data = json.loads('''${RESULT}''')
    images = data.get('images', [{}])
    url = images[0].get('url', '') if images else ''
    print(f'UPLOADED|ghost-image|{url}')
except:
    print('ERROR|Could not parse Ghost response')
" 2>/dev/null || echo "ERROR|Ghost upload failed"
    ;;

  webflow)
    # Webflow Assets API
    RESULT=$(curl -s -X POST "https://api.webflow.com/v2/sites/${SITE_URL}/assets" \
      -H "Authorization: Bearer ${AUTH_OR_KEY}" \
      -H "accept-version: 1.0.0" \
      -F "file=@${FILE_PATH}")

    python3 -c "
import sys, json
try:
    data = json.loads('''${RESULT}''')
    asset_id = data.get('id', '')
    url = data.get('url', '')
    print(f'UPLOADED|{asset_id}|{url}')
except:
    print('ERROR|Could not parse Webflow response')
" 2>/dev/null || echo "ERROR|Webflow upload failed"
    ;;

  *)
    echo "ERROR|Unsupported CMS: ${CMS}. Use wp, ghost, or webflow."
    exit 1
    ;;
esac
