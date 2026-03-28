#!/usr/bin/env bash
set -euo pipefail

source "$WP_SYNC_LIB/_env.sh"
source "$WP_SYNC_LIB/_ui.sh"

if [ ! -f "$ENV_FILE" ]; then
    ui_error_box ".env file not found. Run: wp-dev-sync init"
    exit 1
fi

source "$WP_SYNC_LIB/_sync.sh"

ui_banner "WP Dev Sync — Push" "Uploading to remote server"

ui_section "Details" "$CH_FOLDER"
ui_table_row "Local:" "$(basename "$LOCAL_PATH")"
ui_table_row "Protocol:" "$SYNC_PROTOCOL" "$([ "$SYNC_PROTOCOL" = "ssh" ] && echo "ok" || echo "warn")"
ui_table_row "Target:" "$REMOTE_USER@$REMOTE_HOST"
ui_table_row "Path:" "$REMOTE_PATH"
if [ "$SYNC_DELETE" = "true" ]; then
    ui_table_row "Delete:" "${C_RED}${C_BOLD}ON${C_RESET}" "warn"
else
    ui_table_row "Delete:" "${C_GREEN}off${C_RESET}" "ok"
fi
if [ "$SYNCIGNORE_LOADED" = "true" ]; then
    ui_table_row "Ignore:" ".syncignore" "ok"
fi

ui_section "Upload" "$CH_ARROW_UP"
sync_push

ui_success_box "Push complete!"
