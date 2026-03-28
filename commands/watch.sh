#!/usr/bin/env bash
set -euo pipefail

source "$WP_SYNC_LIB/_env.sh"
source "$WP_SYNC_LIB/_ui.sh"

if [ ! -f "$ENV_FILE" ]; then
    ui_error_box ".env file not found. Run: wp-dev-sync init"
    exit 1
fi

source "$WP_SYNC_LIB/_sync.sh"

# ── Banner ───────────────────────────────────────────────────
ui_banner "WP Dev Sync — Watch" "Watching for changes..."

ui_section "Connection" "$CH_LOCK"
ui_table_row "Local:" "$(basename "$LOCAL_PATH")"
ui_table_row "Protocol:" "$SYNC_PROTOCOL" "$([ "$SYNC_PROTOCOL" = "ssh" ] && echo "ok" || echo "warn")"
ui_table_row "Target:" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
if [ "$SYNC_DELETE" = "true" ]; then
    ui_table_row "Delete:" "${C_RED}${C_BOLD}ON${C_RESET}" "warn"
else
    ui_table_row "Delete:" "${C_GREEN}off${C_RESET}" "ok"
fi
if [ "$SYNCIGNORE_LOADED" = "true" ]; then
    ui_table_row "Ignore:" ".syncignore" "ok"
fi

# Detect watcher
WATCHER="polling"
case "$OSTYPE" in
    darwin*)
        command -v fswatch &>/dev/null && WATCHER="fswatch"
        ;;
    linux-gnu*)
        command -v inotifywait &>/dev/null && WATCHER="inotifywait"
        ;;
esac
ui_table_row "Watcher:" "$WATCHER" "$([ "$WATCHER" != "polling" ] && echo "ok")"

ui_section "Sync Log" "$CH_SYNC"

# ── Initial sync ─────────────────────────────────────────────
ui_status "sync" "Initial sync..."
sync_push

echo ""
ui_divider
printf "\n  %s%s%s Watching for changes... %s(Ctrl+C to stop)%s\n\n" \
    "$C_BRIGHT_GREEN" "$C_BOLD$CH_BULLET" "$C_RESET" \
    "$C_DIM" "$C_RESET"
ui_divider
echo ""

# ── Watch loop ───────────────────────────────────────────────
case "$WATCHER" in
    fswatch)
        fswatch -o -r --latency 0.5 \
            --exclude "\.git" --exclude "node_modules" --exclude "\.DS_Store" \
            "$LOCAL_PATH" | while read -r _; do
            sync_push
        done
        ;;
    inotifywait)
        inotifywait -m -r -e modify,create,delete,move \
            --exclude "(\.git|node_modules)" \
            "$LOCAL_PATH" | while read -r _; do
            sleep 0.5
            sync_push
        done
        ;;
    polling)
        ui_status "watch" "${C_DIM}Polling every 2s...${C_RESET}"
        while true; do
            sleep 2
            sync_push
        done
        ;;
esac
