#!/usr/bin/env bash
# image-config.sh — Manage image library configuration
# Usage:
#   image-config.sh set-folder "/path/to/images"
#   image-config.sh get-folder
#   image-config.sh check

CONFIG_FILE="${TMPDIR:-/tmp}/image-manager-config.env"

ACTION="${1}"

case "$ACTION" in
  set-folder)
    FOLDER="${2}"
    if [ -z "$FOLDER" ]; then
      echo "ERROR: No folder path provided"
      exit 1
    fi
    if [ ! -d "$FOLDER" ]; then
      echo "ERROR: Directory does not exist: $FOLDER"
      exit 1
    fi
    echo "IMAGE_FOLDER=${FOLDER}" > "$CONFIG_FILE"
    echo "FOLDER_SET|${FOLDER}"
    ;;

  get-folder)
    if [ -f "$CONFIG_FILE" ]; then
      source "$CONFIG_FILE"
      echo "${IMAGE_FOLDER}"
    else
      echo "NOT_CONFIGURED"
    fi
    ;;

  check)
    if [ -f "$CONFIG_FILE" ]; then
      source "$CONFIG_FILE"
      if [ -n "$IMAGE_FOLDER" ] && [ -d "$IMAGE_FOLDER" ]; then
        echo "CONFIGURED|${IMAGE_FOLDER}"
      else
        echo "NOT_CONFIGURED"
      fi
    else
      echo "NOT_CONFIGURED"
    fi
    ;;

  clear)
    rm -f "$CONFIG_FILE"
    echo "CLEARED"
    ;;

  *)
    echo "Usage: image-config.sh [set-folder|get-folder|check|clear]"
    exit 1
    ;;
esac
