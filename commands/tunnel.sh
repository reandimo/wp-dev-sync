#!/usr/bin/env bash
set -euo pipefail

source "$WP_SYNC_LIB/_env.sh"
source "$WP_SYNC_LIB/_ui.sh"

if [ ! -f "$ENV_FILE" ]; then
    ui_error_box ".env file not found. Run: wp-sync init"
    exit 1
fi

TUNNEL_TOOL="${TUNNEL_TOOL:-cloudflared}"
TUNNEL_DOMAIN="${TUNNEL_DOMAIN:-}"

if [ -z "$TUNNEL_DOMAIN" ]; then
    ui_error_box "TUNNEL_DOMAIN is not set in .env"
    exit 1
fi

ui_banner "WP Sync — Tunnel" "Exposing remote site to the internet"

ui_section "Configuration" "$CH_LOCK"
ui_table_row "Tool:" "${C_ACCENT_BRIGHT}${C_BOLD}$TUNNEL_TOOL${C_RESET}" "ok"
ui_table_row "Domain:" "${C_UNDERLINE}$TUNNEL_DOMAIN${C_RESET}"

ui_section "Tunnel" "$CH_STAR"

case "$TUNNEL_TOOL" in
    ngrok)
        if ! command -v ngrok &>/dev/null; then
            ui_fail "ngrok is not installed"
            ui_detail "Install: ${C_YELLOW}choco install ngrok${C_RESET}"
            exit 1
        fi
        ui_status "ok" "Starting ngrok tunnel..."
        echo ""
        ui_divider
        echo ""
        ngrok http "https://$TUNNEL_DOMAIN"
        ;;
    cloudflared)
        if ! command -v cloudflared &>/dev/null; then
            ui_fail "cloudflared is not installed"
            ui_detail "Install: ${C_YELLOW}choco install cloudflared${C_RESET}"
            exit 1
        fi
        ui_status "ok" "Starting Cloudflare tunnel..."
        echo ""
        ui_divider
        echo ""
        cloudflared tunnel --url "https://$TUNNEL_DOMAIN"
        ;;
    *)
        ui_error_box "Unknown TUNNEL_TOOL '$TUNNEL_TOOL'. Use 'ngrok' or 'cloudflared'."
        exit 1
        ;;
esac
