#!/usr/bin/env bash
set -euo pipefail

source "$WP_SYNC_LIB/_env.sh"
source "$WP_SYNC_LIB/_ui.sh"

if [ ! -f "$ENV_FILE" ]; then
    ui_error_box ".env file not found. Run: wp-dev-sync init"
    exit 1
fi

source "$WP_SYNC_LIB/_sync.sh"

ui_banner "WP Dev Sync — Pull" "Downloading from remote server"

ui_section "Details" "$CH_FOLDER"
ui_table_row "Local:" "$(basename "$LOCAL_PATH")"
ui_table_row "Protocol:" "$SYNC_PROTOCOL" "$([ "$SYNC_PROTOCOL" = "ssh" ] && echo "ok" || echo "warn")"
ui_table_row "Source:" "$REMOTE_USER@$REMOTE_HOST"
ui_table_row "Path:" "$REMOTE_PATH"

ui_section "Download" "$CH_ARROW_DOWN"
sync_pull

ui_success_box "Pull complete!"
