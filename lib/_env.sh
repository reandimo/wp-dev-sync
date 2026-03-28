#!/usr/bin/env bash
# Shared environment for wp-dev-sync.
# Safely loads .env (handles passwords with special chars) and extends
# PATH on Windows so tools installed via Chocolatey/Scoop are found.
# @author Renan Diaz <https://reandimo.dev>

# Resolve lib dir (where this file lives)
WP_SYNC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Look for .env in the current working directory (project root)
ENV_FILE="$(pwd)/.env"

# Windows: Git Bash doesn't inherit all system PATH entries.
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    WIN_PATHS=(
        "/c/ProgramData/chocolatey/bin"
        "/c/ProgramData/chocolatey/lib/rsync/tools/bin"
        "$HOME/scoop/shims"
        "/c/Program Files/Git/usr/bin"
        "/c/Windows/System32/OpenSSH"
    )
    for p in "${WIN_PATHS[@]}"; do
        [[ -d "$p" ]] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$p:$PATH" ;; esac
    done
fi

# Load .env safely — line-by-line parser that handles special characters
# in values (parentheses, ampersands, dollar signs, etc.)
if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        # Extract key=value, strip matching surrounding quotes from value
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            # Strip Windows carriage return
            val="${val//$'\r'/}"
            # Remove matching surrounding quotes (single or double)
            if [[ "$val" =~ ^\"(.*)\"$ ]]; then
                val="${BASH_REMATCH[1]}"
            elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
                val="${BASH_REMATCH[1]}"
            fi
            export "$key=$val"
        fi
    done < "$ENV_FILE"
fi
