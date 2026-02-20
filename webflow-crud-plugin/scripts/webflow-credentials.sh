#!/usr/bin/env bash
# Webflow Session Credential Manager
# Stores API token and site/collection context for the session

CRED_DIR="${TMPDIR:-/tmp}/.webflow-claude-session"
CRED_FILE="$CRED_DIR/credentials"
CONTEXT_FILE="$CRED_DIR/context"

init() {
  mkdir -p "$CRED_DIR"
  chmod 700 "$CRED_DIR"
}

save() {
  local api_token="$1"

  if [ -z "$api_token" ]; then
    echo "ERROR: Missing arguments. Usage: save <api_token>"
    exit 1
  fi

  init

  printf 'WEBFLOW_API_TOKEN=%s\n' "$api_token" > "$CRED_FILE" || {
    echo "ERROR: Failed to save credentials"
    exit 1
  }

  chmod 600 "$CRED_FILE"
  echo "Credentials saved for session."
}

save_context() {
  local site_id="$1"
  local site_name="$2"

  if [ -z "$site_id" ]; then
    echo "ERROR: Missing site_id."
    exit 1
  fi

  init

  printf 'WEBFLOW_SITE_ID=%s\nWEBFLOW_SITE_NAME=%s\n' \
    "$site_id" "$site_name" > "$CONTEXT_FILE" || {
    echo "ERROR: Failed to save context"
    exit 1
  }

  chmod 600 "$CONTEXT_FILE"
  echo "Site context saved."
}

load() {
  if [ -f "$CRED_FILE" ] && [ -r "$CRED_FILE" ]; then
    source "$CRED_FILE"
    if [ -z "$WEBFLOW_API_TOKEN" ]; then
      echo "ERROR: Credential file is incomplete. Please re-authenticate."
      exit 1
    fi
    local site_id=""
    local site_name=""
    if [ -f "$CONTEXT_FILE" ]; then
      source "$CONTEXT_FILE"
      site_id="$WEBFLOW_SITE_ID"
      site_name="$WEBFLOW_SITE_NAME"
    fi
    echo "$WEBFLOW_API_TOKEN|$site_id|$site_name"
  else
    echo "NO_CREDENTIALS"
  fi
}

check() {
  if [ -f "$CRED_FILE" ]; then
    source "$CRED_FILE"
    local site_info=""
    if [ -f "$CONTEXT_FILE" ]; then
      source "$CONTEXT_FILE"
      site_info="|$WEBFLOW_SITE_ID|$WEBFLOW_SITE_NAME"
    fi
    echo "AUTHENTICATED$site_info"
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

  response=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $WEBFLOW_API_TOKEN" \
    -H "accept: application/json" \
    "https://api.webflow.com/v2/sites")

  if [ "$response" = "200" ]; then
    echo "CONNECTION_OK"
  elif [ "$response" = "401" ]; then
    echo "AUTH_FAILED"
  elif [ "$response" = "403" ]; then
    echo "FORBIDDEN"
  elif [ "$response" = "429" ]; then
    echo "RATE_LIMITED"
  else
    echo "ERROR:$response"
  fi
}

case "$1" in
  save)          save "$2" ;;
  save-context)  save_context "$2" "$3" ;;
  load)          load ;;
  check)         check ;;
  clear)         clear_creds ;;
  test)          test_connection ;;
  *)             echo "Usage: webflow-credentials.sh {save|save-context|load|check|clear|test}" ;;
esac
