#!/usr/bin/env bash
set -euo pipefail

source "$WP_SYNC_LIB/_ui.sh"

# ── Constants ───────────────────────────────────────────────
ENV_DIR="$(pwd)"
ENV_FILE="$ENV_DIR/.env"
ENV_ACTIVE_FILE="$ENV_DIR/.env.active"

# ── Helpers ─────────────────────────────────────────────────

# Get the currently active environment name
_env_current() {
    if [ -f "$ENV_ACTIVE_FILE" ]; then
        cat "$ENV_ACTIVE_FILE" | tr -d '\r\n'
    else
        echo ""
    fi
}

# List all .env.* files (excluding .env.example, .env.active)
_env_list() {
    local envs=()
    for f in "$ENV_DIR"/.env.*; do
        [ -f "$f" ] || continue
        local name="${f##*.env.}"
        # Skip non-environment files
        case "$name" in
            example|active|swp|swo|bak) continue ;;
        esac
        envs+=("$name")
    done
    printf '%s\n' "${envs[@]}" 2>/dev/null | sort
}

# Extract a value from an env file
_env_get_value() {
    local file="$1"
    local key="$2"
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" =~ ^${key}=(.*) ]]; then
            local val="${BASH_REMATCH[1]}"
            val="${val//$'\r'/}"
            # Strip surrounding quotes
            if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                val="${BASH_REMATCH[1]}"
            elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
                val="${BASH_REMATCH[1]}"
            fi
            echo "$val"
            return
        fi
    done < "$file"
}

# Show a compact summary of an env file
_env_summary() {
    local file="$1"
    local protocol host user path
    protocol=$(_env_get_value "$file" "SYNC_PROTOCOL")
    host=$(_env_get_value "$file" "REMOTE_HOST")
    user=$(_env_get_value "$file" "REMOTE_USER")
    path=$(_env_get_value "$file" "REMOTE_PATH")
    printf "%s%s%s@%s%s%s:%s" \
        "$C_DIM" "${protocol:-ssh}" "$C_RESET" \
        "$C_BRIGHT_WHITE" "${user:-?}@${host:-?}" "$C_RESET" \
        "${path:-?}"
}

# ── Subcommands ─────────────────────────────────────────────

cmd_env_list() {
    ui_banner "WP Dev Sync — Environments" "Manage multiple server configs"

    local current
    current=$(_env_current)
    local envs
    envs=$(_env_list)

    if [ -z "$envs" ]; then
        ui_info "No environments found."
        echo ""
        ui_step "Create one with: ${C_ACCENT_BRIGHT}wp-dev-sync env create <name>${C_RESET}"
        ui_detail "Example: wp-dev-sync env create staging"
        echo ""
        return
    fi

    ui_section "Environments" "$CH_FOLDER"
    echo ""

    while IFS= read -r name; do
        local file="$ENV_DIR/.env.$name"
        if [ "$name" = "$current" ]; then
            printf "  %s%s%s  %s%s%-16s%s  %s\n" \
                "$C_GREEN" "$C_BOLD$CH_ARROW_R" "$C_RESET" \
                "$C_BRIGHT_WHITE" "$C_BOLD" "$name" "$C_RESET" \
                "$(_env_summary "$file")"
        else
            printf "     %s%-16s%s  %s\n" \
                "$C_DIM" "$name" "$C_RESET" \
                "$(_env_summary "$file")"
        fi
    done <<< "$envs"

    echo ""
    if [ -n "$current" ]; then
        ui_info "Active: ${C_BRIGHT_WHITE}${C_BOLD}${current}${C_RESET}"
    elif [ -f "$ENV_FILE" ]; then
        ui_warn "No environment selected — using raw .env"
    else
        ui_warn "No .env file found. Run: ${C_ACCENT_BRIGHT}wp-dev-sync init${C_RESET}"
    fi
    echo ""
}

cmd_env_switch() {
    local name="${1:-}"

    if [ -z "$name" ]; then
        # Interactive selection
        local envs_arr=()
        local current
        current=$(_env_current)

        while IFS= read -r env_name; do
            [ -z "$env_name" ] && continue
            envs_arr+=("$env_name")
        done <<< "$(_env_list)"

        if [ ${#envs_arr[@]} -eq 0 ]; then
            ui_error_box "No environments found. Create one first: wp-dev-sync env create <name>"
            exit 1
        fi

        # Build display options with summaries
        local options=()
        for env_name in "${envs_arr[@]}"; do
            local file="$ENV_DIR/.env.$env_name"
            local host
            host=$(_env_get_value "$file" "REMOTE_HOST")
            local proto
            proto=$(_env_get_value "$file" "SYNC_PROTOCOL")
            if [ "$env_name" = "$current" ]; then
                options+=("$env_name  (${proto:-ssh}://${host:-?}) ← active")
            else
                options+=("$env_name  (${proto:-ssh}://${host:-?})")
            fi
        done

        ui_select "Switch to environment:" "${options[@]}"
        name="${envs_arr[$UI_SELECT_RESULT]}"
    fi

    local source_file="$ENV_DIR/.env.$name"

    if [ ! -f "$source_file" ]; then
        ui_error_box "Environment '$name' not found. File .env.$name does not exist."
        exit 1
    fi

    # Backup current .env if it exists and has no active env
    local current
    current=$(_env_current)
    if [ -f "$ENV_FILE" ] && [ -z "$current" ]; then
        cp "$ENV_FILE" "$ENV_FILE.bak"
        ui_detail "Backed up current .env to .env.bak"
    fi

    # Copy environment to .env
    cp "$source_file" "$ENV_FILE"
    echo "$name" > "$ENV_ACTIVE_FILE"

    echo ""
    ui_ok "Switched to ${C_BRIGHT_WHITE}${C_BOLD}${name}${C_RESET}"
    echo ""

    # Show summary
    ui_section "Active Connection" "$CH_LOCK"
    local protocol host user path port
    protocol=$(_env_get_value "$ENV_FILE" "SYNC_PROTOCOL")
    host=$(_env_get_value "$ENV_FILE" "REMOTE_HOST")
    user=$(_env_get_value "$ENV_FILE" "REMOTE_USER")
    path=$(_env_get_value "$ENV_FILE" "REMOTE_PATH")
    port=$(_env_get_value "$ENV_FILE" "REMOTE_PORT")
    ui_table_row "Protocol:" "${protocol:-ssh}" "$([ "${protocol:-ssh}" = "ssh" ] && echo "ok" || echo "warn")"
    ui_table_row "Target:" "${user:-?}@${host:-?}:${path:-?}"
    ui_table_row "Port:" "${port:-22}"
    echo ""
}

cmd_env_create() {
    local name="${1:-}"

    if [ -z "$name" ]; then
        ui_error_box "Usage: wp-dev-sync env create <name>"
        ui_detail "Example: wp-dev-sync env create staging"
        exit 1
    fi

    # Validate name (alphanumeric, hyphens, underscores)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        ui_error_box "Invalid environment name: '$name'. Use only letters, numbers, hyphens, and underscores."
        exit 1
    fi

    local target_file="$ENV_DIR/.env.$name"

    if [ -f "$target_file" ]; then
        ui_warn_box "Environment '$name' already exists."
        ui_detail "Edit it: ${C_BRIGHT_WHITE}.env.${name}${C_RESET}"
        ui_detail "Or delete it and try again."
        exit 0
    fi

    if [ -f "$ENV_FILE" ]; then
        # Copy from current .env
        cp "$ENV_FILE" "$target_file"
        ui_ok "Created ${C_BRIGHT_WHITE}.env.${name}${C_RESET} from current .env"
    elif [ -f "$WP_SYNC_ROOT/.env.example" ]; then
        # Copy from template
        cp "$WP_SYNC_ROOT/.env.example" "$target_file"
        ui_ok "Created ${C_BRIGHT_WHITE}.env.${name}${C_RESET} from template"
    else
        ui_error_box "No .env or template found to copy from."
        exit 1
    fi

    echo ""
    ui_info "Next steps:"
    ui_step "Edit ${C_BRIGHT_WHITE}.env.${name}${C_RESET} with the ${name} server credentials"
    ui_step "Switch to it: ${C_ACCENT_BRIGHT}wp-dev-sync env switch ${name}${C_RESET}"
    echo ""
}

cmd_env_delete() {
    local name="${1:-}"

    if [ -z "$name" ]; then
        ui_error_box "Usage: wp-dev-sync env delete <name>"
        exit 1
    fi

    local target_file="$ENV_DIR/.env.$name"

    if [ ! -f "$target_file" ]; then
        ui_error_box "Environment '$name' not found."
        exit 1
    fi

    local current
    current=$(_env_current)
    if [ "$name" = "$current" ]; then
        ui_error_box "Cannot delete the active environment. Switch to another one first."
        exit 1
    fi

    rm -f "$target_file"
    ui_ok "Deleted environment ${C_BRIGHT_WHITE}${name}${C_RESET}"
}

cmd_env_current() {
    local current
    current=$(_env_current)

    if [ -n "$current" ]; then
        printf "  %s%s%s %s%s%s\n" \
            "$C_GREEN" "$C_BOLD$CH_CHECK" "$C_RESET" \
            "$C_BRIGHT_WHITE$C_BOLD" "$current" "$C_RESET"
    elif [ -f "$ENV_FILE" ]; then
        ui_warn "No named environment active — using raw .env"
    else
        ui_warn "No .env file found."
    fi
}

cmd_env_help() {
    ui_banner "WP Dev Sync — Environments" "Manage multiple server configs"

    printf "  %s%sUsage:%s  wp-dev-sync env %s<subcommand>%s\n\n" \
        "$C_BRIGHT_WHITE" "$C_BOLD" "$C_RESET" \
        "$C_ACCENT_BRIGHT" "$C_RESET"

    printf "  %s%sSubcommands:%s\n\n" "$C_ACCENT_BRIGHT" "$C_BOLD" "$C_RESET"
    printf "    %s%-12s%s %s%s%s\n" "$C_BRIGHT_WHITE" "list" "$C_RESET" "$C_DIM" "Show all environments" "$C_RESET"
    printf "    %s%-12s%s %s%s%s\n" "$C_BRIGHT_WHITE" "switch" "$C_RESET" "$C_DIM" "Switch active environment (interactive or by name)" "$C_RESET"
    printf "    %s%-12s%s %s%s%s\n" "$C_BRIGHT_WHITE" "create" "$C_RESET" "$C_DIM" "Create a new environment from current .env" "$C_RESET"
    printf "    %s%-12s%s %s%s%s\n" "$C_BRIGHT_WHITE" "delete" "$C_RESET" "$C_DIM" "Delete an environment" "$C_RESET"
    printf "    %s%-12s%s %s%s%s\n" "$C_BRIGHT_WHITE" "current" "$C_RESET" "$C_DIM" "Show active environment name" "$C_RESET"
    echo ""

    ui_divider
    echo ""
    printf "  %s%sExamples:%s\n\n" "$C_ACCENT_BRIGHT" "$C_BOLD" "$C_RESET"
    printf "    %s$ wp-dev-sync env create staging%s\n" "$C_BRIGHT_WHITE" "$C_RESET"
    printf "    %s$ wp-dev-sync env create production%s\n" "$C_BRIGHT_WHITE" "$C_RESET"
    printf "    %s$ wp-dev-sync env switch staging%s\n" "$C_BRIGHT_WHITE" "$C_RESET"
    printf "    %s$ wp-dev-sync env switch%s              %s# interactive picker%s\n" "$C_BRIGHT_WHITE" "$C_RESET" "$C_DIM" "$C_RESET"
    printf "    %s$ wp-dev-sync env list%s\n" "$C_BRIGHT_WHITE" "$C_RESET"
    echo ""
}

# ── Dispatch ────────────────────────────────────────────────

SUBCOMMAND="${2:-list}"

case "$SUBCOMMAND" in
    list|ls)          cmd_env_list ;;
    switch|sw|use)    cmd_env_switch "${3:-}" ;;
    create|new|add)   cmd_env_create "${3:-}" ;;
    delete|rm|remove) cmd_env_delete "${3:-}" ;;
    current)          cmd_env_current ;;
    help|-h|--help)   cmd_env_help ;;
    *)
        ui_error_box "Unknown env subcommand: $SUBCOMMAND"
        cmd_env_help
        exit 1
        ;;
esac
