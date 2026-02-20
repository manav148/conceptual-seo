#!/usr/bin/env bash
# Ghost CMS Session Credential Manager
# Stores Admin API key and generates JWT tokens for authentication

CRED_DIR="${TMPDIR:-/tmp}/.ghost-claude-session"
CRED_FILE="$CRED_DIR/credentials"

init() {
  mkdir -p "$CRED_DIR"
  chmod 700 "$CRED_DIR"
}

save() {
  local site_url="$1"
  local admin_api_key="$2"

  if [ -z "$site_url" ] || [ -z "$admin_api_key" ]; then
    echo "ERROR: Missing arguments. Usage: save <site_url> <admin_api_key>"
    exit 1
  fi

  # Validate API key format (id:secret)
  if [[ ! "$admin_api_key" == *":"* ]]; then
    echo "ERROR: Invalid API key format. Expected format: id:secret"
    exit 1
  fi

  init

  printf 'GHOST_SITE_URL=%s\nGHOST_ADMIN_API_KEY=%s\n' \
    "$site_url" "$admin_api_key" > "$CRED_FILE" || {
    echo "ERROR: Failed to save credentials"
    exit 1
  }

  chmod 600 "$CRED_FILE"
  echo "Credentials saved for session."
}

load() {
  if [ -f "$CRED_FILE" ] && [ -r "$CRED_FILE" ]; then
    source "$CRED_FILE"
    if [ -z "$GHOST_SITE_URL" ] || [ -z "$GHOST_ADMIN_API_KEY" ]; then
      echo "ERROR: Credential file is incomplete. Please re-authenticate."
      exit 1
    fi
    echo "$GHOST_SITE_URL|$GHOST_ADMIN_API_KEY"
  else
    echo "NO_CREDENTIALS"
  fi
}

check() {
  if [ -f "$CRED_FILE" ]; then
    source "$CRED_FILE"
    echo "AUTHENTICATED|$GHOST_SITE_URL"
  else
    echo "NOT_AUTHENTICATED"
  fi
}

clear_creds() {
  rm -rf "$CRED_DIR"
  echo "Credentials cleared."
}

# Generate a JWT token from the Admin API key using Python
generate_token() {
  if [ ! -f "$CRED_FILE" ]; then
    echo "ERROR: No credentials stored. Run authentication first."
    exit 1
  fi

  source "$CRED_FILE"

  if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required for JWT token generation."
    exit 1
  fi

  python3 -c "
import sys, json, time, hmac, hashlib, base64

api_key = '$GHOST_ADMIN_API_KEY'
kid, secret = api_key.split(':')

# JWT header
header = json.dumps({'alg': 'HS256', 'typ': 'JWT', 'kid': kid}, separators=(',', ':'))

# JWT payload
iat = int(time.time())
payload = json.dumps({'iat': iat, 'exp': iat + 300, 'aud': '/admin/'}, separators=(',', ':'))

# Base64url encode
def b64url(data):
    if isinstance(data, str):
        data = data.encode('utf-8')
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('utf-8')

# Sign
signing_input = b64url(header) + '.' + b64url(payload)
key_bytes = bytes.fromhex(secret)
signature = hmac.new(key_bytes, signing_input.encode('utf-8'), hashlib.sha256).digest()

token = signing_input + '.' + b64url(signature)
print(token)
"
}

test_connection() {
  if [ ! -f "$CRED_FILE" ]; then
    echo "ERROR: No credentials stored. Run authentication first."
    exit 1
  fi

  source "$CRED_FILE"
  TOKEN=$(generate_token 2>&1)

  if [[ "$TOKEN" == ERROR:* ]]; then
    echo "TOKEN_GENERATION_FAILED: $TOKEN"
    exit 1
  fi

  response=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Ghost $TOKEN" \
    -H "Accept-Version: v5.0" \
    "${GHOST_SITE_URL}/ghost/api/admin/pages/?limit=1")

  if [ "$response" = "200" ]; then
    echo "CONNECTION_OK"
  elif [ "$response" = "401" ]; then
    echo "AUTH_FAILED"
  elif [ "$response" = "403" ]; then
    echo "FORBIDDEN"
  else
    echo "ERROR:$response"
  fi
}

case "$1" in
  save)     save "$2" "$3" ;;
  load)     load ;;
  check)    check ;;
  clear)    clear_creds ;;
  token)    generate_token ;;
  test)     test_connection ;;
  *)        echo "Usage: ghost-credentials.sh {save|load|check|clear|token|test}" ;;
esac
