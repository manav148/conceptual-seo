#!/usr/bin/env bash
# WordPress Session Credential Manager
# Stores credentials in a temporary file that is cleaned up on session end

CRED_DIR="${TMPDIR:-/tmp}/.wp-claude-session"
CRED_FILE="$CRED_DIR/credentials"

init() {
  mkdir -p "$CRED_DIR"
  chmod 700 "$CRED_DIR"
}

save() {
  local site_url="$1"
  local username="$2"
  local app_password="$3"

  if [ -z "$site_url" ] || [ -z "$username" ] || [ -z "$app_password" ]; then
    echo "ERROR: Missing arguments. Usage: save <site_url> <username> <app_password>"
    exit 1
  fi

  init

  cat > "$CRED_FILE" << 'ENDCREDS'
ENDCREDS

  printf 'WP_SITE_URL=%s\nWP_USERNAME=%s\nWP_APP_PASSWORD=%s\n' \
    "$site_url" "$username" "$app_password" > "$CRED_FILE" || {
    echo "ERROR: Failed to save credentials"
    exit 1
  }

  chmod 600 "$CRED_FILE"
  echo "Credentials saved for session."
}

load() {
  if [ -f "$CRED_FILE" ] && [ -r "$CRED_FILE" ]; then
    source "$CRED_FILE"
    if [ -z "$WP_SITE_URL" ] || [ -z "$WP_USERNAME" ] || [ -z "$WP_APP_PASSWORD" ]; then
      echo "ERROR: Credential file is incomplete. Please re-authenticate."
      exit 1
    fi
    echo "$WP_SITE_URL|$WP_USERNAME|$WP_APP_PASSWORD"
  else
    echo "NO_CREDENTIALS"
  fi
}

check() {
  if [ -f "$CRED_FILE" ]; then
    source "$CRED_FILE"
    echo "AUTHENTICATED|$WP_SITE_URL"
  else
    echo "NOT_AUTHENTICATED"
  fi
}

clear_creds() {
  rm -rf "$CRED_DIR"
  echo "Credentials cleared."
}

test_connection() {
  if [ ! -f "$CRED_FILE" ]; then
    echo "ERROR: No credentials stored. Run authentication first."
    exit 1
  fi

  source "$CRED_FILE"
  local auth=$(printf '%s:%s' "$WP_USERNAME" "$WP_APP_PASSWORD" | base64)

  response=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Basic $auth" \
    "${WP_SITE_URL}/wp-json/wp/v2/pages?per_page=1")

  if [ "$response" = "200" ]; then
    echo "CONNECTION_OK"
  elif [ "$response" = "401" ]; then
    echo "AUTH_FAILED"
  else
    echo "ERROR:$response"
  fi
}

case "$1" in
  save)   save "$2" "$3" "$4" ;;
  load)   load ;;
  check)  check ;;
  clear)  clear_creds ;;
  test)   test_connection ;;
  *)      echo "Usage: wp-credentials.sh {save|load|check|clear|test}" ;;
esac
