#!/usr/bin/env bash
set -euo pipefail

source "$WP_SYNC_LIB/_env.sh"
source "$WP_SYNC_LIB/_ui.sh"

if [ ! -f "$ENV_FILE" ]; then
    ui_error_box ".env file not found. Run: wp-dev-sync init"
    exit 1
fi

source "$WP_SYNC_LIB/_sync.sh"

ui_banner "WP Dev Sync — Diff" "Comparing local vs remote"

ui_section "Connection" "$CH_LOCK"
ui_table_row "Local:" "$(basename "$LOCAL_PATH")"
ui_table_row "Protocol:" "$SYNC_PROTOCOL" "$([ "$SYNC_PROTOCOL" = "ssh" ] && echo "ok" || echo "warn")"
ui_table_row "Target:" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

ui_section "Comparing" "$CH_SYNC"

ui_spinner_start "Running dry-run diff..."
sync_diff
ui_spinner_stop

# ── Results ─────────────────────────────────────────────────
TOTAL_CHANGES=$(( ${#DIFF_LOCAL_ONLY[@]} + ${#DIFF_REMOTE_ONLY[@]} + ${#DIFF_CHANGED[@]} ))

if [ "$TOTAL_CHANGES" -eq 0 ]; then
    echo ""
    ui_ok "Everything is in sync — no differences found."
    echo ""
    exit 0
fi

echo ""

# ── Local-only files ────────────────────────────────────────
if [ ${#DIFF_LOCAL_ONLY[@]} -gt 0 ]; then
    printf "  %s%sLocal only%s %s(%d files)%s — present locally, missing on remote\n\n" \
        "$C_GREEN" "$C_BOLD" "$C_RESET" \
        "$C_DIM" "${#DIFF_LOCAL_ONLY[@]}" "$C_RESET"
    for f in "${DIFF_LOCAL_ONLY[@]}"; do
        printf "    %s%s+%s  %s\n" "$C_GREEN" "$C_BOLD" "$C_RESET" "$f"
    done
    echo ""
fi

# ── Remote-only files ───────────────────────────────────────
if [ ${#DIFF_REMOTE_ONLY[@]} -gt 0 ]; then
    printf "  %s%sRemote only%s %s(%d files)%s — present on remote, missing locally\n\n" \
        "$C_RED" "$C_BOLD" "$C_RESET" \
        "$C_DIM" "${#DIFF_REMOTE_ONLY[@]}" "$C_RESET"
    for f in "${DIFF_REMOTE_ONLY[@]}"; do
        printf "    %s%s-%s  %s\n" "$C_RED" "$C_BOLD" "$C_RESET" "$f"
    done
    echo ""
fi

# ── Changed files ───────────────────────────────────────────
if [ ${#DIFF_CHANGED[@]} -gt 0 ]; then
    printf "  %s%sModified%s %s(%d files)%s — differ between local and remote\n\n" \
        "$C_YELLOW" "$C_BOLD" "$C_RESET" \
        "$C_DIM" "${#DIFF_CHANGED[@]}" "$C_RESET"
    for f in "${DIFF_CHANGED[@]}"; do
        printf "    %s%s~%s  %s\n" "$C_YELLOW" "$C_BOLD" "$C_RESET" "$f"
    done
    echo ""
fi

# ── Summary ─────────────────────────────────────────────────
ui_divider
echo ""
printf "  %s%s%d%s local only  " "$C_GREEN" "$C_BOLD" "${#DIFF_LOCAL_ONLY[@]}" "$C_RESET"
printf "%s%s%d%s remote only  " "$C_RED" "$C_BOLD" "${#DIFF_REMOTE_ONLY[@]}" "$C_RESET"
printf "%s%s%d%s modified\n" "$C_YELLOW" "$C_BOLD" "${#DIFF_CHANGED[@]}" "$C_RESET"
echo ""
printf "  %sRun %swp-dev-sync push%s%s to upload or %swp-dev-sync watch%s%s to reconcile.%s\n" \
    "$C_DIM" "$C_ACCENT_BRIGHT" "$C_RESET" "$C_DIM" "$C_ACCENT_BRIGHT" "$C_RESET" "$C_DIM" "$C_RESET"
echo ""
