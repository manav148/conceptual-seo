#!/usr/bin/env bash
# set-featured.sh — Set a featured image on a CMS post/page
# Usage:
#   set-featured.sh wp    POST_ID MEDIA_ID  AUTH SITE_URL
#   set-featured.sh ghost POST_ID IMAGE_URL GHOST_KEY SITE_URL
#   set-featured.sh webflow ITEM_ID IMAGE_URL WEBFLOW_TOKEN COLLECTION_ID
#
# Returns: SET|post_id|image_ref   on success
#          ERROR|message           on failure

CMS="${1}"
POST_ID="${2}"
IMAGE_REF="${3}"   # media_id for WP, image URL for Ghost/Webflow
AUTH="${4}"
SITE_OR_COLLECTION="${5}"

case "$CMS" in
  wp)
    RESULT=$(curl -s -X POST "${SITE_OR_COLLECTION}/wp-json/wp/v2/posts/${POST_ID}" \
      -H "Authorization: Basic ${AUTH}" \
      -H "Content-Type: application/json" \
      -H "User-Agent: Mozilla/5.0" \
      -d "{\"featured_media\": ${IMAGE_REF}}")

    python3 -c "
import sys, json
data = json.loads('''${RESULT}'''.replace(\"'''\", ''))
if 'code' in data:
    print(f'ERROR|{data.get(\"code\")}: {data.get(\"message\",\"\")[:80]}')
else:
    featured = data.get('featured_media', 0)
    title = data.get('title', {}).get('rendered', '')[:50]
    print(f'SET|${POST_ID}|media:{featured}|{title}')
" 2>/dev/null || echo "ERROR|Could not parse WP response"
    ;;

  wp-page)
    RESULT=$(curl -s -X POST "${SITE_OR_COLLECTION}/wp-json/wp/v2/pages/${POST_ID}" \
      -H "Authorization: Basic ${AUTH}" \
      -H "Content-Type: application/json" \
      -H "User-Agent: Mozilla/5.0" \
      -d "{\"featured_media\": ${IMAGE_REF}}")

    python3 -c "
import sys, json
data = json.loads('''${RESULT}'''.replace(\"'''\", ''))
if 'code' in data:
    print(f'ERROR|{data.get(\"code\")}: {data.get(\"message\",\"\")[:80]}')
else:
    featured = data.get('featured_media', 0)
    print(f'SET|${POST_ID}|media:{featured}')
" 2>/dev/null || echo "ERROR|Could not parse WP page response"
    ;;

  ghost)
    # Ghost uses feature_image URL field
    GHOST_KEY="${AUTH}"
    # Generate JWT for Ghost Admin API
    JWT=$(python3 -c "
import sys, json, time, hmac, hashlib, base64
key = '${GHOST_KEY}'
parts = key.split(':')
if len(parts) != 2:
    print('ERROR_JWT')
    sys.exit(1)
kid, secret = parts
iat = int(time.time())
exp = iat + 300
header = base64.urlsafe_b64encode(json.dumps({'alg':'HS256','typ':'JWT','kid':kid}).encode()).rstrip(b'=').decode()
payload = base64.urlsafe_b64encode(json.dumps({'iat':iat,'exp':exp,'aud':'/admin/'}).encode()).rstrip(b'=').decode()
sig_input = f'{header}.{payload}'.encode()
sig = hmac.new(bytes.fromhex(secret), sig_input, hashlib.sha256).digest()
sig_b64 = base64.urlsafe_b64encode(sig).rstrip(b'=').decode()
print(f'{header}.{payload}.{sig_b64}')
" 2>/dev/null)

    if [ "$JWT" = "ERROR_JWT" ]; then
      echo "ERROR|Invalid Ghost Admin API key format (expected id:secret)"
      exit 1
    fi

    RESULT=$(curl -s -X PUT "${SITE_OR_COLLECTION}/ghost/api/admin/posts/${POST_ID}/" \
      -H "Authorization: Ghost ${JWT}" \
      -H "Content-Type: application/json" \
      -d "{\"posts\": [{\"feature_image\": \"${IMAGE_REF}\"}]}")

    python3 -c "
import sys, json
try:
    data = json.loads('''${RESULT}''')
    posts = data.get('posts', [{}])
    post = posts[0] if posts else {}
    fi = post.get('feature_image', '')
    print(f'SET|${POST_ID}|{fi}')
except Exception as e:
    print(f'ERROR|{e}')
" 2>/dev/null || echo "ERROR|Ghost set featured failed"
    ;;

  webflow)
    # Webflow CMS item update with image field
    WEBFLOW_TOKEN="${AUTH}"
    COLLECTION_ID="${SITE_OR_COLLECTION}"

    RESULT=$(curl -s -X PATCH "https://api.webflow.com/v2/collections/${COLLECTION_ID}/items/${POST_ID}" \
      -H "Authorization: Bearer ${WEBFLOW_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "accept-version: 1.0.0" \
      -d "{\"fieldData\": {\"main-image\": {\"url\": \"${IMAGE_REF}\"}}}")

    python3 -c "
import sys, json
try:
    data = json.loads('''${RESULT}''')
    item_id = data.get('id', '')
    print(f'SET|${POST_ID}|{item_id}')
except Exception as e:
    print(f'ERROR|{e}')
" 2>/dev/null || echo "ERROR|Webflow set featured failed"
    ;;

  *)
    echo "ERROR|Unsupported CMS: ${CMS}. Use wp, wp-page, ghost, or webflow."
    exit 1
    ;;
esac
