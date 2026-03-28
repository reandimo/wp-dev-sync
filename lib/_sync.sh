#!/usr/bin/env bash
# Shared sync functions for SSH (rsync) and FTP (lftp) protocols.
# Requires _env.sh and _ui.sh to be sourced first.
# @author Renan Diaz <https://reandimo.dev>

SYNC_PROTOCOL="${SYNC_PROTOCOL:-ssh}"
REMOTE_PORT="${REMOTE_PORT:-$([ "$SYNC_PROTOCOL" = "ftp" ] && echo 21 || echo 22)}"
SYNC_EXCLUDE="${SYNC_EXCLUDE:-.git,node_modules,.DS_Store,*.log,.env,public/hot}"
SYNC_DELETE="${SYNC_DELETE:-false}"

# ── .syncignore support ──────────────────────────────────────
# Reads patterns from .syncignore (one per line, # for comments).
# For rsync: uses --exclude-from natively (supports full glob syntax).
# For lftp: merges patterns into SYNC_EXCLUDE.
SYNCIGNORE_FILE="$(pwd)/.syncignore"
SYNCIGNORE_LOADED=false

# Save original env value before merging
SYNC_EXCLUDE_ENV="$SYNC_EXCLUDE"

if [ -f "$SYNCIGNORE_FILE" ]; then
    SYNCIGNORE_LOADED=true
    # For lftp, merge .syncignore patterns into SYNC_EXCLUDE
    if [ "$SYNC_PROTOCOL" = "ftp" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line="${line//$'\r'/}"
            [[ -z "$line" || "$line" == \#* ]] && continue
            SYNC_EXCLUDE="${SYNC_EXCLUDE},${line}"
        done < "$SYNCIGNORE_FILE"
    fi
fi

# Resolve local path (absolute, no ".." — required for lftp lcd)
LOCAL_PATH="${LOCAL_PATH:-.}"
LOCAL_PATH="$(cd "$LOCAL_PATH" 2>/dev/null && pwd)" || {
    ui_error_box "LOCAL_PATH does not exist: $LOCAL_PATH"
    exit 1
}

REMOTE_PATH="${REMOTE_PATH:-}"
if [ -z "$REMOTE_PATH" ]; then
    ui_error_box "REMOTE_PATH is not set in .env"
    exit 1
fi

# lftp on Windows (Chocolatey) needs Windows-style paths, not /c/...
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] && command -v cygpath &>/dev/null; then
    LFTP_LOCAL_PATH="$(cygpath -w "$LOCAL_PATH")"
else
    LFTP_LOCAL_PATH="$LOCAL_PATH"
fi

# ── Build helpers ────────────────────────────────────────────

_build_lftp_excludes() {
    local excludes=""
    IFS=',' read -ra ITEMS <<< "$SYNC_EXCLUDE"
    for item in "${ITEMS[@]}"; do
        local pattern="$item"
        if [[ "$pattern" == \*.* ]]; then
            pattern=$(echo "$pattern" | sed 's/\*//' | sed 's/\./\\./g')
            pattern="${pattern}$"
        fi
        excludes="$excludes --exclude $pattern"
    done
    echo "$excludes"
}

_build_rsync_opts() {
    local opts="-avz --compress --checksum"
    if [ "$SYNC_DELETE" = "true" ]; then
        opts="$opts --delete"
    fi
    # .syncignore → native rsync --exclude-from
    if [ "$SYNCIGNORE_LOADED" = "true" ]; then
        opts="$opts --exclude-from=$SYNCIGNORE_FILE"
    fi
    # SYNC_EXCLUDE from .env
    IFS=',' read -ra ITEMS <<< "$SYNC_EXCLUDE_ENV"
    for item in "${ITEMS[@]}"; do
        opts="$opts --exclude=$item"
    done
    echo "$opts"
}

# ── File type detection ──────────────────────────────────────

_is_tracked_file() {
    local line="$1"
    [[ "$line" == *".php"* ]] || [[ "$line" == *".scss"* ]] || \
    [[ "$line" == *".css"* ]] || [[ "$line" == *".ts"* ]] || \
    [[ "$line" == *".js"* ]] || [[ "$line" == *".html"* ]] || \
    [[ "$line" == *".json"* ]] || [[ "$line" == *".twig"* ]] || \
    [[ "$line" == *".txt"* ]] || [[ "$line" == *".md"* ]] || \
    [[ "$line" == *".svg"* ]] || [[ "$line" == *".png"* ]] || \
    [[ "$line" == *".jpg"* ]] || [[ "$line" == *".webp"* ]]
}

# ── Sync functions ───────────────────────────────────────────

sync_push() {
    local file_count=0

    if [ "$SYNC_PROTOCOL" = "ftp" ]; then
        local delete_flag=""
        [ "$SYNC_DELETE" = "true" ] && delete_flag="--delete"
        local excludes
        excludes=$(_build_lftp_excludes)

        ui_status "upload" "Uploading via ${C_ACCENT_BRIGHT}FTP${C_RESET}${C_DIM}...${C_RESET}"
        # shellcheck disable=SC2086
        lftp -u "$REMOTE_USER","$REMOTE_PASSWORD" -p "$REMOTE_PORT" "$REMOTE_HOST" -e "
            set ssl:verify-certificate no;
            lcd "$LFTP_LOCAL_PATH";
            cd $REMOTE_PATH;
            mirror --reverse --no-perms --verbose=1 $delete_flag $excludes;
            quit
        " 2>&1 | while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            if [[ "$line" == *"Transferring"* ]] || [[ "$line" == *"Removing"* ]]; then
                printf "    %s%s%s\n" "$C_DIM" "$line" "$C_RESET"
            elif [[ "$line" == *"new:"* ]] || [[ "$line" == *"modified:"* ]]; then
                printf "    %s%s%s\n" "$C_DIM" "$line" "$C_RESET"
            elif _is_tracked_file "$line"; then
                local filename="${line##*/}"
                filename="${filename%% *}"
                ui_file_upload "$filename"
                file_count=$((file_count + 1))
            elif [[ "$line" == *"Total:"* ]] || [[ "$line" == *"bytes transferred"* ]]; then
                printf "    %s%s%s\n" "$C_DIM" "$line" "$C_RESET"
            fi
        done
    else
        local rsync_opts
        rsync_opts=$(_build_rsync_opts)
        local ssh_cmd="ssh -p ${REMOTE_PORT}"

        ui_status "upload" "Uploading via ${C_ACCENT_BRIGHT}rsync${C_RESET}${C_DIM}...${C_RESET}"
        # shellcheck disable=SC2086
        rsync $rsync_opts -e "$ssh_cmd" \
            "$LOCAL_PATH/" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" 2>&1 | while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            if [[ "$line" == *"/"* ]] && [[ "$line" != *"sending"* ]] && [[ "$line" != *"sent "* ]] && [[ "$line" != *"total size"* ]] && [[ "$line" != *"building"* ]]; then
                ui_file_upload "$line"
                file_count=$((file_count + 1))
            elif [[ "$line" == *"sent "* ]] || [[ "$line" == *"total size"* ]]; then
                printf "    %s%s%s\n" "$C_DIM" "$line" "$C_RESET"
            fi
        done
    fi

    ui_status "ok" "Sync complete"
}

sync_pull() {
    local file_count=0

    if [ "$SYNC_PROTOCOL" = "ftp" ]; then
        local excludes
        excludes=$(_build_lftp_excludes)

        ui_status "download" "Downloading via ${C_BRIGHT_MAGENTA}FTP${C_RESET}${C_DIM}...${C_RESET}"
        # shellcheck disable=SC2086
        lftp -u "$REMOTE_USER","$REMOTE_PASSWORD" -p "$REMOTE_PORT" "$REMOTE_HOST" -e "
            set ssl:verify-certificate no;
            lcd "$LFTP_LOCAL_PATH";
            cd $REMOTE_PATH;
            mirror --no-perms --verbose=1 $excludes;
            quit
        " 2>&1 | while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            if _is_tracked_file "$line"; then
                local filename="${line##*/}"
                filename="${filename%% *}"
                ui_file_download "$filename"
                file_count=$((file_count + 1))
            elif [[ "$line" == *"Total:"* ]] || [[ "$line" == *"bytes transferred"* ]]; then
                printf "    %s%s%s\n" "$C_DIM" "$line" "$C_RESET"
            else
                printf "    %s%s%s\n" "$C_DIM" "$line" "$C_RESET"
            fi
        done
    else
        local rsync_opts="-avz --compress --checksum"
        IFS=',' read -ra ITEMS <<< "$SYNC_EXCLUDE"
        for item in "${ITEMS[@]}"; do
            rsync_opts="$rsync_opts --exclude=$item"
        done
        local ssh_cmd="ssh -p ${REMOTE_PORT}"

        ui_status "download" "Downloading via ${C_BRIGHT_MAGENTA}rsync${C_RESET}${C_DIM}...${C_RESET}"
        # shellcheck disable=SC2086
        rsync $rsync_opts -e "$ssh_cmd" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" \
            "$LOCAL_PATH/" 2>&1 | while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            if [[ "$line" == *"/"* ]] && [[ "$line" != *"receiving"* ]] && [[ "$line" != *"sent "* ]] && [[ "$line" != *"total size"* ]]; then
                ui_file_download "$line"
                file_count=$((file_count + 1))
            elif [[ "$line" == *"sent "* ]] || [[ "$line" == *"total size"* ]]; then
                printf "    %s%s%s\n" "$C_DIM" "$line" "$C_RESET"
            fi
        done
    fi

    ui_status "ok" "Pull complete"
}
