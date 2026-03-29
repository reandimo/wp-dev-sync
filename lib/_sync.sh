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

# ── Dry-run diff (Shopify CLI style reconciliation) ─────────
# Populates arrays: DIFF_LOCAL_ONLY, DIFF_REMOTE_ONLY, DIFF_CHANGED
# These represent files only present locally, only remotely, and differing.

sync_diff() {
    DIFF_LOCAL_ONLY=()
    DIFF_REMOTE_ONLY=()
    DIFF_CHANGED=()

    if [ "$SYNC_PROTOCOL" = "ftp" ]; then
        _sync_diff_ftp
    else
        _sync_diff_rsync
    fi
}

_sync_diff_rsync() {
    local rsync_opts
    rsync_opts=$(_build_rsync_opts)
    local ssh_cmd="ssh -p ${REMOTE_PORT}"

    # Dry-run local→remote with itemize-changes
    local push_output
    # shellcheck disable=SC2086
    push_output=$(rsync $rsync_opts --dry-run --itemize-changes -e "$ssh_cmd" \
        "$LOCAL_PATH/" \
        "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" 2>&1) || true

    # Dry-run remote→local with itemize-changes
    local pull_output
    local pull_rsync_opts="-avz --compress --checksum"
    IFS=',' read -ra ITEMS <<< "$SYNC_EXCLUDE_ENV"
    for item in "${ITEMS[@]}"; do
        pull_rsync_opts="$pull_rsync_opts --exclude=$item"
    done
    if [ "$SYNCIGNORE_LOADED" = "true" ]; then
        pull_rsync_opts="$pull_rsync_opts --exclude-from=$SYNCIGNORE_FILE"
    fi
    # shellcheck disable=SC2086
    pull_output=$(rsync $pull_rsync_opts --dry-run --itemize-changes -e "$ssh_cmd" \
        "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" \
        "$LOCAL_PATH/" 2>&1) || true

    # Parse itemize-changes output into associative arrays.
    # Format: >f+++++++++ path (new file) or >f.st...... path (changed).
    # The regex requires the 11-char flag field (>fXXXXXXXXX) to avoid
    # capturing rsync noise like summary lines, SSH banners, etc.
    _parse_itemize() {
        local -n _target_map=$1
        local _output="$2"
        while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            # Strict match: >f followed by exactly 9 flag chars, then space(s), then path
            if [[ "$line" =~ ^\>f(.{9})[[:space:]]+(.+)$ ]]; then
                local flags="${BASH_REMATCH[1]}"
                local path="${BASH_REMATCH[2]}"
                # Skip paths that are clearly not files
                [[ "$path" == "."* && ! "$path" == *"/"* && ! "$path" == *"."*"."* ]] && continue
                if [[ "$flags" == "+++++++++" ]]; then
                    _target_map["$path"]="new"
                else
                    _target_map["$path"]="changed"
                fi
            fi
        done <<< "$_output"
    }

    local -A push_files=()
    _parse_itemize push_files "$push_output"

    local -A pull_files=()
    _parse_itemize pull_files "$pull_output"

    # Classify files
    for file in "${!push_files[@]}"; do
        if [[ "${push_files[$file]}" == "new" ]] && [[ -z "${pull_files[$file]:-}" ]]; then
            DIFF_LOCAL_ONLY+=("$file")
        elif [[ -n "${pull_files[$file]:-}" ]]; then
            DIFF_CHANGED+=("$file")
        else
            DIFF_CHANGED+=("$file")
        fi
    done

    for file in "${!pull_files[@]}"; do
        if [[ "${pull_files[$file]}" == "new" ]] && [[ -z "${push_files[$file]:-}" ]]; then
            DIFF_REMOTE_ONLY+=("$file")
        elif [[ -z "${push_files[$file]:-}" ]]; then
            DIFF_CHANGED+=("$file")
        fi
    done

    # Sort arrays (guard against empty — printf with no args emits a blank line)
    if [ ${#DIFF_LOCAL_ONLY[@]} -gt 0 ]; then
        IFS=$'\n' DIFF_LOCAL_ONLY=($(printf '%s\n' "${DIFF_LOCAL_ONLY[@]}" | sort)); unset IFS
    fi
    if [ ${#DIFF_REMOTE_ONLY[@]} -gt 0 ]; then
        IFS=$'\n' DIFF_REMOTE_ONLY=($(printf '%s\n' "${DIFF_REMOTE_ONLY[@]}" | sort)); unset IFS
    fi
    if [ ${#DIFF_CHANGED[@]} -gt 0 ]; then
        IFS=$'\n' DIFF_CHANGED=($(printf '%s\n' "${DIFF_CHANGED[@]}" | sort)); unset IFS
    fi
}

_sync_diff_ftp() {
    local excludes
    excludes=$(_build_lftp_excludes)

    # Dry-run push (local→remote)
    local push_output
    # shellcheck disable=SC2086
    push_output=$(lftp -u "$REMOTE_USER","$REMOTE_PASSWORD" -p "$REMOTE_PORT" "$REMOTE_HOST" -e "
        set ssl:verify-certificate no;
        lcd "$LFTP_LOCAL_PATH";
        cd $REMOTE_PATH;
        mirror --reverse --no-perms --dry-run --verbose=1 $excludes;
        quit
    " 2>&1) || true

    # Dry-run pull (remote→local)
    local pull_output
    # shellcheck disable=SC2086
    pull_output=$(lftp -u "$REMOTE_USER","$REMOTE_PASSWORD" -p "$REMOTE_PORT" "$REMOTE_HOST" -e "
        set ssl:verify-certificate no;
        lcd "$LFTP_LOCAL_PATH";
        cd $REMOTE_PATH;
        mirror --no-perms --dry-run --verbose=1 $excludes;
        quit
    " 2>&1) || true

    # Parse lftp dry-run --verbose=1 output.
    # Actual format (confirmed from live output):
    #   "Transferring file `filename'"        ← file to transfer
    #   "get -O /dest ftp://..."              ← command detail (skip)
    #   "lcd ok, ..." / "cd ok, ..."          ← connection info (skip)
    #   "Total: ..." / "New: ..." / "To be…"  ← summary (skip)
    _parse_lftp_diff() {
        local -n _target=$1
        local _output="$2"
        while IFS= read -r line; do
            line="${line//$'\r'/}"
            [[ -z "$line" ]] && continue
            # Match: Transferring file `some/path/file.ext'
            if [[ "$line" =~ ^Transferring\ file\ \`(.+)\'$ ]]; then
                local fpath="${BASH_REMATCH[1]}"
                fpath="${fpath#./}"
                [[ -n "$fpath" ]] && _target["$fpath"]="changed"
            fi
        done <<< "$_output"
    }

    local -A push_files=()
    _parse_lftp_diff push_files "$push_output"

    local -A pull_files=()
    _parse_lftp_diff pull_files "$pull_output"

    # Classify
    for file in "${!push_files[@]}"; do
        if [[ -z "${pull_files[$file]:-}" ]]; then
            DIFF_LOCAL_ONLY+=("$file")
        else
            DIFF_CHANGED+=("$file")
        fi
    done

    for file in "${!pull_files[@]}"; do
        if [[ -z "${push_files[$file]:-}" ]]; then
            DIFF_REMOTE_ONLY+=("$file")
        fi
    done

    # Sort arrays (guard against empty — printf with no args emits a blank line)
    if [ ${#DIFF_LOCAL_ONLY[@]} -gt 0 ]; then
        IFS=$'\n' DIFF_LOCAL_ONLY=($(printf '%s\n' "${DIFF_LOCAL_ONLY[@]}" | sort)); unset IFS
    fi
    if [ ${#DIFF_REMOTE_ONLY[@]} -gt 0 ]; then
        IFS=$'\n' DIFF_REMOTE_ONLY=($(printf '%s\n' "${DIFF_REMOTE_ONLY[@]}" | sort)); unset IFS
    fi
    if [ ${#DIFF_CHANGED[@]} -gt 0 ]; then
        IFS=$'\n' DIFF_CHANGED=($(printf '%s\n' "${DIFF_CHANGED[@]}" | sort)); unset IFS
    fi
}

# ── Delete remote files ──────────────────────────────────────
# Usage: sync_delete_remote file1 file2 ...
# Deletes specific files from the remote server.

sync_delete_remote() {
    local files=("$@")
    [ ${#files[@]} -eq 0 ] && return

    if [ "$SYNC_PROTOCOL" = "ftp" ]; then
        # Build rm commands, one per file
        local rm_cmds="set ssl:verify-certificate no; cd $REMOTE_PATH;"
        for f in "${files[@]}"; do
            rm_cmds="${rm_cmds} rm -- ${f};"
        done
        rm_cmds="${rm_cmds} quit"

        # Run all deletions in a single lftp session
        local output
        output=$(lftp -u "$REMOTE_USER","$REMOTE_PASSWORD" -p "$REMOTE_PORT" "$REMOTE_HOST" -e "$rm_cmds" 2>&1) || true

        # Debug: save raw output
        echo "$output" > /tmp/wp-sync-lftp-rm.log 2>/dev/null || true

        # Report results per file by checking for errors in output
        for f in "${files[@]}"; do
            if echo "$output" | grep -q "$(printf '%s' "$f").*\(No such file\|Access failed\|Permission denied\)"; then
                local err_line
                err_line=$(echo "$output" | grep "$f" | head -1)
                ui_status "error" "Failed to delete remote: $f"
                [ -n "$err_line" ] && ui_detail "$err_line"
            else
                ui_status "ok" "Deleted remote: $f"
            fi
        done
    else
        local ssh_cmd="ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST}"
        for f in "${files[@]}"; do
            # shellcheck disable=SC2029
            $ssh_cmd "rm -f \"${REMOTE_PATH}/${f}\"" 2>&1 && \
                ui_status "ok" "Deleted remote: $f" || \
                ui_status "error" "Failed to delete remote: $f"
        done
    fi
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

# ── Progress-aware sync (used during reconciliation) ────────
# These use the known file count from sync_diff to show a gradient bar.
# Usage: sync_push_progress <expected_file_count>

sync_push_progress() {
    local total="${1:-0}"
    local file_count=0

    if [ "$total" -le 0 ]; then
        sync_push
        return
    fi

    if [ "$SYNC_PROTOCOL" = "ftp" ]; then
        local delete_flag=""
        [ "$SYNC_DELETE" = "true" ] && delete_flag="--delete"
        local excludes
        excludes=$(_build_lftp_excludes)

        ui_progress_gradient 0 "$total" "Uploading via FTP..."
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
            if _is_tracked_file "$line"; then
                file_count=$((file_count + 1))
                local filename="${line##*/}"
                filename="${filename%% *}"
                ui_progress_gradient "$file_count" "$total" "$CH_UPLOAD $filename"
            fi
        done
    else
        local rsync_opts
        rsync_opts=$(_build_rsync_opts)
        local ssh_cmd="ssh -p ${REMOTE_PORT}"

        ui_progress_gradient 0 "$total" "Uploading via rsync..."
        # shellcheck disable=SC2086
        rsync $rsync_opts -e "$ssh_cmd" \
            "$LOCAL_PATH/" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" 2>&1 | while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            if [[ "$line" == *"/"* ]] && [[ "$line" != *"sending"* ]] && [[ "$line" != *"sent "* ]] && [[ "$line" != *"total size"* ]] && [[ "$line" != *"building"* ]]; then
                file_count=$((file_count + 1))
                ui_progress_gradient "$file_count" "$total" "$CH_UPLOAD $line"
            fi
        done
    fi

    ui_progress_gradient_done
    ui_status "ok" "Sync complete — ${C_BRIGHT_WHITE}${total}${C_RESET} files uploaded"
}

sync_pull_progress() {
    local total="${1:-0}"
    local file_count=0

    if [ "$total" -le 0 ]; then
        sync_pull
        return
    fi

    if [ "$SYNC_PROTOCOL" = "ftp" ]; then
        local excludes
        excludes=$(_build_lftp_excludes)

        ui_progress_gradient 0 "$total" "Downloading via FTP..."
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
                file_count=$((file_count + 1))
                local filename="${line##*/}"
                filename="${filename%% *}"
                ui_progress_gradient "$file_count" "$total" "$CH_DOWNLOAD $filename"
            fi
        done
    else
        local rsync_opts="-avz --compress --checksum"
        IFS=',' read -ra ITEMS <<< "$SYNC_EXCLUDE"
        for item in "${ITEMS[@]}"; do
            rsync_opts="$rsync_opts --exclude=$item"
        done
        local ssh_cmd="ssh -p ${REMOTE_PORT}"

        ui_progress_gradient 0 "$total" "Downloading via rsync..."
        # shellcheck disable=SC2086
        rsync $rsync_opts -e "$ssh_cmd" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/" \
            "$LOCAL_PATH/" 2>&1 | while IFS= read -r line; do
            line="${line//$'\r'/}"
            [ -z "$line" ] && continue
            if [[ "$line" == *"/"* ]] && [[ "$line" != *"receiving"* ]] && [[ "$line" != *"sent "* ]] && [[ "$line" != *"total size"* ]]; then
                file_count=$((file_count + 1))
                ui_progress_gradient "$file_count" "$total" "$CH_DOWNLOAD $line"
            fi
        done
    fi

    ui_progress_gradient_done
    ui_status "ok" "Pull complete — ${C_BRIGHT_WHITE}${total}${C_RESET} files downloaded"
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
