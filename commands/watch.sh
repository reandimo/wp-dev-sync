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

# ── Reconciliation strategy ──────────────────────────────────
ui_spinner_start "Comparing local and remote files..."
sync_diff
ui_spinner_stop

if [ ${#DIFF_LOCAL_ONLY[@]} -eq 0 ] && [ ${#DIFF_REMOTE_ONLY[@]} -eq 0 ] && [ ${#DIFF_CHANGED[@]} -eq 0 ]; then
    ui_ok "Local and remote are in sync — no differences found."
else
    # ── Files only present locally ───────────────────────────
    if [ ${#DIFF_LOCAL_ONLY[@]} -gt 0 ]; then
        ui_info_box "The files listed below are only present locally. What would you like to do?" "${DIFF_LOCAL_ONLY[@]}"
        echo ""
        ui_select "Reconciliation Strategy:" \
            "Upload local files to the remote server" \
            "Delete local files"

        case "$UI_SELECT_RESULT" in
            0)
                sync_push_progress ${#DIFF_LOCAL_ONLY[@]}
                ;;
            1)
                ui_status "sync" "Deleting local-only files..."
                for f in "${DIFF_LOCAL_ONLY[@]}"; do
                    rm -f "$LOCAL_PATH/$f"
                    ui_status "ok" "Deleted $f"
                done
                ;;
        esac
    fi

    # ── Files only present on remote ─────────────────────────
    if [ ${#DIFF_REMOTE_ONLY[@]} -gt 0 ]; then
        ui_info_box "The files listed below are only present on the remote server. What would you like to do?" "${DIFF_REMOTE_ONLY[@]}"
        echo ""
        ui_select "Reconciliation Strategy:" \
            "Download remote files to local directory" \
            "Delete remote files"

        case "$UI_SELECT_RESULT" in
            0)
                sync_pull_progress ${#DIFF_REMOTE_ONLY[@]}
                ;;
            1)
                ui_status "sync" "Deleting remote-only files..."
                sync_delete_remote "${DIFF_REMOTE_ONLY[@]}"
                ;;
        esac
    fi

    # ── Files that differ between local and remote ───────────
    if [ ${#DIFF_CHANGED[@]} -gt 0 ]; then
        ui_info_box "The files listed below differ between the local and remote versions. What would you like to do?" "${DIFF_CHANGED[@]}"
        echo ""
        ui_select "Reconciliation Strategy:" \
            "Keep the local version" \
            "Keep the remote version"

        case "$UI_SELECT_RESULT" in
            0)
                sync_push_progress ${#DIFF_CHANGED[@]}
                ;;
            1)
                sync_pull_progress ${#DIFF_CHANGED[@]}
                ;;
        esac
    fi
fi

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
