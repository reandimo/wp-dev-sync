#!/usr/bin/env bash
set -euo pipefail

source "$WP_SYNC_LIB/_env.sh"
source "$WP_SYNC_LIB/_ui.sh"

if [ ! -f "$ENV_FILE" ]; then
    ui_error_box ".env file not found. Run: wp-dev-sync init"
    exit 1
fi

source "$WP_SYNC_LIB/_sync.sh"

# ── Config ──────────────────────────────────────────────────
SITE_URL="${SITE_URL:-}"
DEV_PORT="${DEV_PORT:-9000}"
VITE_PORT="${VITE_PORT:-5173}"
VITE_ENTRY="${VITE_ENTRY:-resources/scripts/frontend/main.ts}"
DEV_OPEN="${DEV_OPEN:-true}"

if [ -z "$SITE_URL" ]; then
    ui_error_box "SITE_URL is not set in .env. Add the WordPress site URL (e.g. SITE_URL=https://mysite.com)"
    exit 1
fi

# ── Banner ──────────────────────────────────────────────────
ui_banner "WP Dev Sync — Dev" "Local development with HMR"

ui_section "Connection" "$CH_LOCK"
ui_table_row "Site URL:" "$SITE_URL"
ui_table_row "Local:" "$(basename "$LOCAL_PATH")"
ui_table_row "Protocol:" "$SYNC_PROTOCOL" "$([ "$SYNC_PROTOCOL" = "ssh" ] && echo "ok" || echo "warn")"
ui_table_row "Target:" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

ui_section "Dev Server" "$CH_STAR"
ui_table_row "Proxy:" "http://127.0.0.1:${DEV_PORT}" "ok"
ui_table_row "Vite HMR:" "http://localhost:${VITE_PORT}" "ok"
ui_table_row "Entry:" "$VITE_ENTRY"

# ── Dependency checks ──────────────────────────────────────
if ! command -v node &>/dev/null; then
    ui_error_box "Node.js is required for the dev proxy. Install it from https://nodejs.org"
    exit 1
fi

NODE_VERSION=$(node -v 2>/dev/null)
ui_table_row "Node.js:" "$NODE_VERSION" "ok"

# ── Detect Vite ─────────────────────────────────────────────
HAS_VITE=false
VITE_BIN=""

if [ -f "$LOCAL_PATH/node_modules/.bin/vite" ]; then
    VITE_BIN="$LOCAL_PATH/node_modules/.bin/vite"
    HAS_VITE=true
elif [ -f "$LOCAL_PATH/package.json" ] && command -v npx &>/dev/null; then
    if grep -q '"vite"' "$LOCAL_PATH/package.json" 2>/dev/null; then
        VITE_BIN="npx --prefix $LOCAL_PATH vite"
        HAS_VITE=true
    fi
fi

if [ "$HAS_VITE" = "true" ]; then
    ui_table_row "Vite:" "detected" "ok"
else
    ui_table_row "Vite:" "not found (start manually)" "warn"
fi

# ── Cleanup on exit ─────────────────────────────────────────
PROXY_PID=""
VITE_PID=""
WATCHER_PID=""

cleanup() {
    echo ""
    ui_status "sync" "Shutting down..."

    [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null && ui_detail "Stopped proxy"
    [ -n "$VITE_PID" ] && kill "$VITE_PID" 2>/dev/null && ui_detail "Stopped Vite"
    [ -n "$WATCHER_PID" ] && kill "$WATCHER_PID" 2>/dev/null && ui_detail "Stopped watcher"

    # Kill any remaining child processes
    jobs -p 2>/dev/null | xargs -r kill 2>/dev/null || true

    echo ""
    ui_ok "Dev server stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# ── Start Vite dev server ──────────────────────────────────
if [ "$HAS_VITE" = "true" ]; then
    ui_section "Vite HMR" "$CH_BULLET"

    (
        cd "$LOCAL_PATH"
        $VITE_BIN --port "$VITE_PORT" --strictPort 2>&1 | while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            # Filter noisy output, show key lines
            if [[ "$line" == *"ready in"* ]] || [[ "$line" == *"Local:"* ]] || [[ "$line" == *"hmr"* ]] || [[ "$line" == *"error"* ]] || [[ "$line" == *"Error"* ]]; then
                printf "  %s%s%s %s\n" "$C_BRIGHT_YELLOW" "$CH_BULLET" "$C_RESET" "$line"
            fi
        done
    ) &
    VITE_PID=$!
    disown "$VITE_PID" 2>/dev/null

    # Wait for Vite to start
    ui_spinner_start "Starting Vite dev server..."
    local_vite_ready=false
    for i in $(seq 1 30); do
        if (echo > /dev/tcp/localhost/"$VITE_PORT") 2>/dev/null; then
            local_vite_ready=true
            break
        fi
        sleep 0.5
    done
    ui_spinner_stop

    if [ "$local_vite_ready" = "true" ]; then
        ui_ok "Vite dev server running on ${C_BRIGHT_WHITE}http://localhost:${VITE_PORT}${C_RESET}"
    else
        ui_warn "Vite may not have started. Check for errors above."
    fi
fi

# ── Start file watcher (background sync) ───────────────────
ui_section "File Sync" "$CH_SYNC"

(
    case "$(uname -s 2>/dev/null || echo "unknown")" in
        Darwin*)
            if command -v fswatch &>/dev/null; then
                fswatch -o -r --latency 0.5 \
                    --exclude "\.git" --exclude "node_modules" --exclude "\.DS_Store" --exclude "public/hot" \
                    "$LOCAL_PATH" | while read -r _; do
                    sync_push 2>&1 | tail -1
                done
            else
                while true; do sleep 2; sync_push 2>&1 | tail -1; done
            fi
            ;;
        Linux*)
            if command -v inotifywait &>/dev/null; then
                inotifywait -m -r -e modify,create,delete,move \
                    --exclude "(\.git|node_modules|public/hot)" \
                    "$LOCAL_PATH" | while read -r _; do
                    sleep 0.5
                    sync_push 2>&1 | tail -1
                done
            else
                while true; do sleep 2; sync_push 2>&1 | tail -1; done
            fi
            ;;
        *)
            while true; do sleep 2; sync_push 2>&1 | tail -1; done
            ;;
    esac
) &
WATCHER_PID=$!
disown "$WATCHER_PID" 2>/dev/null
ui_ok "File watcher started — PHP changes sync to remote automatically"

# ── Start proxy ─────────────────────────────────────────────
ui_section "Proxy" "$CH_LOCK"

export SITE_URL DEV_PORT VITE_PORT VITE_ENTRY LOCAL_PATH

PROXY_SCRIPT="$WP_SYNC_ROOT/lib/proxy.mjs"

if [ ! -f "$PROXY_SCRIPT" ]; then
    ui_error_box "Proxy script not found: $PROXY_SCRIPT"
    exit 1
fi

# Start proxy in background
node "$PROXY_SCRIPT" 2>&1 | while IFS= read -r line; do
    line="${line//$'\r'/}"
    [ -z "$line" ] && continue

    # Detect ready signal
    if [[ "$line" == __PROXY_READY__* ]]; then
        echo ""
        ui_divider
        echo ""
        printf "  %s%s%s Dev server ready: %s%shttp://127.0.0.1:%s%s\n" \
            "$C_BRIGHT_GREEN" "$C_BOLD$CH_BULLET" "$C_RESET" \
            "$C_BRIGHT_WHITE" "$C_BOLD" "$DEV_PORT" "$C_RESET"
        printf "  %s%s%s Proxying: %s → %s\n" \
            "$C_BRIGHT_GREEN" "$C_BOLD$CH_BULLET" "$C_RESET" \
            "${C_BRIGHT_WHITE}http://127.0.0.1:${DEV_PORT}${C_RESET}" \
            "${C_DIM}${SITE_URL}${C_RESET}"
        printf "  %s%s%s Vite HMR: %sinjected automatically%s\n" \
            "$C_BRIGHT_GREEN" "$C_BOLD$CH_BULLET" "$C_RESET" \
            "$C_BRIGHT_YELLOW" "$C_RESET"
        printf "\n  %sPress Ctrl+C to stop.%s\n" "$C_DIM" "$C_RESET"
        echo ""
        ui_divider
        echo ""

        # Open browser
        if [ "$DEV_OPEN" = "true" ]; then
            local_url="http://127.0.0.1:${DEV_PORT}"
            case "$OSTYPE" in
                darwin*)  open "$local_url" 2>/dev/null & ;;
                linux*)   xdg-open "$local_url" 2>/dev/null & ;;
                msys*|cygwin*) start "$local_url" 2>/dev/null & ;;
            esac
        fi
    elif [[ "$line" == "[proxy]"* ]]; then
        # Proxy log messages
        if [[ "$line" == *"Error"* ]]; then
            ui_status "error" "${line#\[proxy\] }"
        else
            ui_status "sync" "${line#\[proxy\] }"
        fi
    fi
done &
PROXY_PID=$!

# Wait for proxy process — keeps the script alive until Ctrl+C
wait "$PROXY_PID" 2>/dev/null || true
