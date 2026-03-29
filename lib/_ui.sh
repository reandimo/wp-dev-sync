#!/usr/bin/env bash
# Shared UI functions for beautiful terminal output.
# Inspired by Claude Code's visual style.
# Source this after _env.sh in any script.
# @author Renan Diaz <https://reandimo.dev>

# ── Terminal width ───────────────────────────────────────────

_term_width() {
    local w
    w=$(tput cols 2>/dev/null || echo 60)
    [ "$w" -gt 80 ] && w=80
    [ "$w" -lt 40 ] && w=40
    echo "$w"
}

# ── ANSI Colors ─────────────────────────────────────────────

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'
C_ITALIC=$'\033[3m'
C_UNDERLINE=$'\033[4m'
C_BLINK=$'\033[5m'
C_INVERSE=$'\033[7m'
C_STRIKETHROUGH=$'\033[9m'

C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'
C_MAGENTA=$'\033[35m'
C_CYAN=$'\033[36m'
C_WHITE=$'\033[37m'
C_BRIGHT_BLACK=$'\033[90m'
C_BRIGHT_RED=$'\033[91m'
C_BRIGHT_WHITE=$'\033[97m'
C_BRIGHT_CYAN=$'\033[96m'
C_BRIGHT_GREEN=$'\033[92m'
C_BRIGHT_YELLOW=$'\033[93m'
C_BRIGHT_MAGENTA=$'\033[95m'
C_BRIGHT_BLUE=$'\033[94m'

# Background colors
C_BG_RED=$'\033[41m'
C_BG_GREEN=$'\033[42m'
C_BG_YELLOW=$'\033[43m'
C_BG_BLUE=$'\033[44m'
C_BG_MAGENTA=$'\033[45m'
C_BG_CYAN=$'\033[46m'
C_BG_BRIGHT_BLACK=$'\033[100m'

# ── Gradient / Theme ────────────────────────────────────────

# Primary accent (cyan-based like Claude Code)
C_ACCENT="$C_CYAN"
C_ACCENT_BOLD="${C_CYAN}${C_BOLD}"
C_ACCENT_BRIGHT="$C_BRIGHT_CYAN"

# ── Special Characters ──────────────────────────────────────

CH_BULLET="●"
CH_CIRCLE="○"
CH_CHECK="✔"
CH_CROSS="✘"
CH_WARN="▲"
CH_INFO="ℹ"
CH_ARROW_R="▸"
CH_ARROW_D="▾"
CH_ARROW_UP="↑"
CH_ARROW_DOWN="↓"
CH_DOT="·"
CH_DASH="─"
CH_PIPE="│"
CH_CORNER_TL="╭"
CH_CORNER_TR="╮"
CH_CORNER_BL="╰"
CH_CORNER_BR="╯"
CH_FILE="◇"
CH_FOLDER="◈"
CH_SYNC="⟳"
CH_UPLOAD="⬆"
CH_DOWNLOAD="⬇"
CH_LOCK="◆"
CH_STAR="★"

# ── Line drawing ────────────────────────────────────────────

_repeat_char() {
    local char="$1" count="$2"
    printf '%0.s'"$char" $(seq 1 "$count")
}

# ── Banner ──────────────────────────────────────────────────

ui_banner() {
    local title="$1"
    local subtitle="${2:-}"
    local w=$(_term_width)
    local inner=$((w - 4))

    echo ""

    # Top border with gradient effect
    printf "  %s%s%s%s%s%s\n" \
        "$C_ACCENT_BOLD" "$CH_CORNER_TL" "$(_repeat_char "$CH_DASH" "$inner")" "$CH_CORNER_TR" "$C_RESET" ""

    # Empty line
    printf "  %s%s%s%s%*s%s%s%s\n" \
        "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET" "" "$inner" "" "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET"

    # Title centered
    local pad_left=$(( (inner - ${#title}) / 2 ))
    local pad_right=$(( inner - ${#title} - pad_left ))
    printf "  %s%s%s%*s%s%s%s%*s%s%s%s\n" \
        "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET" \
        "$pad_left" "" \
        "$C_BRIGHT_WHITE" "$C_BOLD" "$title" \
        "$pad_right" "" \
        "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET"

    # Subtitle
    if [ -n "$subtitle" ]; then
        local spad_left=$(( (inner - ${#subtitle}) / 2 ))
        local spad_right=$(( inner - ${#subtitle} - spad_left ))
        printf "  %s%s%s%*s%s%s%*s%s%s%s\n" \
            "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET" \
            "$spad_left" "" \
            "$C_DIM" "$subtitle" \
            "$spad_right" "" \
            "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET"
    fi

    # Empty line
    printf "  %s%s%s%s%*s%s%s%s\n" \
        "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET" "" "$inner" "" "$C_ACCENT_BOLD" "$CH_PIPE" "$C_RESET"

    # Bottom border
    printf "  %s%s%s%s%s\n" \
        "$C_ACCENT_BOLD" "$CH_CORNER_BL" "$(_repeat_char "$CH_DASH" "$inner")" "$CH_CORNER_BR" "$C_RESET"

    echo ""
}

# ── Section headers ─────────────────────────────────────────

ui_section() {
    local title="$1"
    local icon="${2:-$CH_LOCK}"
    local w=$(_term_width)
    local line_len=$((w - ${#title} - 8))
    [ "$line_len" -lt 4 ] && line_len=4

    echo ""
    printf "  %s%s %s%s %s%s%s\n" \
        "$C_ACCENT_BRIGHT" "$icon" \
        "$C_BRIGHT_WHITE" "$C_BOLD$title$C_RESET" \
        "$C_DIM" "$(_repeat_char "$CH_DASH" "$line_len")" "$C_RESET"
}

# ── Status messages ──────────────────────────────────────────

ui_ok() {
    local text="$1"
    local detail="${2:-}"
    if [ -n "$detail" ]; then
        printf "  %s%s%s%s %s %s%s%s\n" \
            "$C_GREEN" "$C_BOLD" "$CH_CHECK" "$C_RESET" \
            "$text" \
            "$C_DIM" "$detail" "$C_RESET"
    else
        printf "  %s%s%s%s %s\n" \
            "$C_GREEN" "$C_BOLD" "$CH_CHECK" "$C_RESET" "$text"
    fi
}

ui_fail() {
    printf "  %s%s%s%s %s\n" \
        "$C_RED" "$C_BOLD" "$CH_CROSS" "$C_RESET" "$1"
}

ui_warn() {
    printf "  %s%s%s%s %s\n" \
        "$C_YELLOW" "$C_BOLD" "$CH_WARN" "$C_RESET" "$1"
}

ui_info() {
    printf "  %s%s%s %s\n" \
        "$C_BRIGHT_BLUE" "$CH_INFO" "$C_RESET" "$1"
}

ui_skip() {
    printf "  %s%s %s%s\n" "$C_DIM" "$CH_CIRCLE" "$1" "$C_RESET"
}

ui_step() {
    printf "  %s%s%s %s\n" "$C_DIM" "$CH_ARROW_R" "$C_RESET" "$1"
}

ui_detail() {
    printf "    %s%s%s\n" "$C_DIM" "$1" "$C_RESET"
}

# ── Key-value display ────────────────────────────────────────

ui_key_value() {
    local key="$1"
    local value="$2"
    printf "  %s%s%-14s%s %s%s%s\n" \
        "$C_DIM" "$CH_PIPE" "$key" "$C_RESET" \
        "$C_BRIGHT_WHITE" "$value" "$C_RESET"
}

# ── Boxes ────────────────────────────────────────────────────

ui_error_box() {
    local msg="$1"
    local w=$(_term_width)
    local inner=$((w - 6))
    echo ""
    printf "  %s%s%s %s%s%s%s\n" \
        "$C_RED" "$C_BOLD" "$CH_CORNER_TL" "$(_repeat_char "$CH_DASH" 2)" " Error " "$(_repeat_char "$CH_DASH" $((inner - 9)))" "$CH_CORNER_TR$C_RESET"
    printf "  %s%s%s%s %s%s\n" \
        "$C_RED" "$C_BOLD" "$CH_PIPE" "$C_RESET" "$msg" ""
    printf "  %s%s%s%s%s\n" \
        "$C_RED" "$C_BOLD" "$CH_CORNER_BL" "$(_repeat_char "$CH_DASH" $((inner + 1)))" "$CH_CORNER_BR$C_RESET"
    echo ""
}

ui_success_box() {
    local msg="$1"
    local w=$(_term_width)
    local inner=$((w - 6))
    echo ""
    printf "  %s%s%s %s%s%s%s\n" \
        "$C_GREEN" "$C_BOLD" "$CH_CORNER_TL" "$(_repeat_char "$CH_DASH" 2)" " Success " "$(_repeat_char "$CH_DASH" $((inner - 11)))" "$CH_CORNER_TR$C_RESET"
    printf "  %s%s%s%s %s%s\n" \
        "$C_GREEN" "$C_BOLD" "$CH_PIPE" "$C_RESET" "$msg" ""
    printf "  %s%s%s%s%s\n" \
        "$C_GREEN" "$C_BOLD" "$CH_CORNER_BL" "$(_repeat_char "$CH_DASH" $((inner + 1)))" "$CH_CORNER_BR$C_RESET"
    echo ""
}

ui_warn_box() {
    local msg="$1"
    local w=$(_term_width)
    local inner=$((w - 6))
    echo ""
    printf "  %s%s%s %s%s%s%s\n" \
        "$C_YELLOW" "$C_BOLD" "$CH_CORNER_TL" "$(_repeat_char "$CH_DASH" 2)" " Warning " "$(_repeat_char "$CH_DASH" $((inner - 11)))" "$CH_CORNER_TR$C_RESET"
    printf "  %s%s%s%s %s%s\n" \
        "$C_YELLOW" "$C_BOLD" "$CH_PIPE" "$C_RESET" "$msg" ""
    printf "  %s%s%s%s%s\n" \
        "$C_YELLOW" "$C_BOLD" "$CH_CORNER_BL" "$(_repeat_char "$CH_DASH" $((inner + 1)))" "$CH_CORNER_BR$C_RESET"
    echo ""
}

# ── Info box with file list (Shopify CLI style) ─────────────
# Usage: ui_info_box "message text" file1 file2 file3 ...
ui_info_box() {
    local msg="$1"
    shift
    local files=("$@")
    local w=$(_term_width)
    local inner=$((w - 6))

    echo ""
    # Top border: ╭─ info ───...───╮
    printf "  %s%s%s %s%s%s%s\n" \
        "$C_BRIGHT_BLUE" "$C_BOLD" "$CH_CORNER_TL" "$(_repeat_char "$CH_DASH" 2)" " info " "$(_repeat_char "$CH_DASH" $((inner - 8)))" "$CH_CORNER_TR$C_RESET"

    # Empty line
    printf "  %s%s%s%s%*s%s%s%s\n" \
        "$C_BRIGHT_BLUE" "$C_BOLD" "$CH_PIPE" "$C_RESET" "$inner" "" "$C_BRIGHT_BLUE$C_BOLD" "$CH_PIPE" "$C_RESET"

    # Message text (word-wrapped)
    local line_max=$((inner - 2))
    local words=()
    read -ra words <<< "$msg"
    local current_line=""
    for word in "${words[@]}"; do
        if [ -z "$current_line" ]; then
            current_line="$word"
        elif [ $(( ${#current_line} + 1 + ${#word} )) -le "$line_max" ]; then
            current_line="$current_line $word"
        else
            local pad=$(( inner - ${#current_line} - 2 ))
            printf "  %s%s%s%s  %s%*s%s%s%s\n" \
                "$C_BRIGHT_BLUE" "$C_BOLD" "$CH_PIPE" "$C_RESET" \
                "$current_line" "$pad" "" \
                "$C_BRIGHT_BLUE$C_BOLD" "$CH_PIPE" "$C_RESET"
            current_line="$word"
        fi
    done
    if [ -n "$current_line" ]; then
        local pad=$(( inner - ${#current_line} - 2 ))
        printf "  %s%s%s%s  %s%*s%s%s%s\n" \
            "$C_BRIGHT_BLUE" "$C_BOLD" "$CH_PIPE" "$C_RESET" \
            "$current_line" "$pad" "" \
            "$C_BRIGHT_BLUE$C_BOLD" "$CH_PIPE" "$C_RESET"
    fi

    # File list (bulleted)
    for file in "${files[@]}"; do
        local entry="  $CH_BULLET $file"
        local pad=$(( inner - ${#entry} - 2 ))
        [ "$pad" -lt 0 ] && pad=0
        printf "  %s%s%s%s  %s%s%s%s%*s%s%s%s\n" \
            "$C_BRIGHT_BLUE" "$C_BOLD" "$CH_PIPE" "$C_RESET" \
            "  " "$C_BRIGHT_WHITE" "$CH_BULLET" " $file" "$pad" "" \
            "$C_BRIGHT_BLUE$C_BOLD" "$CH_PIPE" "$C_RESET"
    done

    # Empty line
    printf "  %s%s%s%s%*s%s%s%s\n" \
        "$C_BRIGHT_BLUE" "$C_BOLD" "$CH_PIPE" "$C_RESET" "$inner" "" "$C_BRIGHT_BLUE$C_BOLD" "$CH_PIPE" "$C_RESET"

    # Bottom border
    printf "  %s%s%s%s%s\n" \
        "$C_BRIGHT_BLUE" "$C_BOLD" "$CH_CORNER_BL" "$(_repeat_char "$CH_DASH" $((inner + 1)))" "$CH_CORNER_BR$C_RESET"
}

# ── Dividers ─────────────────────────────────────────────────

ui_divider() {
    local w=$(_term_width)
    printf "  %s%s%s\n" "$C_DIM" "$(_repeat_char "$CH_DASH" $((w - 4)))" "$C_RESET"
}

ui_divider_dot() {
    local w=$(_term_width)
    printf "  %s%s%s\n" "$C_DIM" "$(_repeat_char "$CH_DOT" $((w - 4)))" "$C_RESET"
}

# ── File change indicators ───────────────────────────────────

ui_file_upload() {
    local file="$1"
    local ext="${file##*.}"
    local icon=""
    case "$ext" in
        php)            icon="${C_MAGENTA}PHP" ;;
        scss|css)       icon="${C_CYAN}CSS" ;;
        ts|js)          icon="${C_YELLOW}JS " ;;
        html|twig)      icon="${C_GREEN}HTM" ;;
        json)           icon="${C_BRIGHT_YELLOW}JSN" ;;
        *)              icon="${C_DIM}···" ;;
    esac
    printf "    %s%s%s %s[%s]%s %s%s%s\n" \
        "$C_CYAN" "$CH_UPLOAD" "$C_RESET" \
        "$C_DIM" "$icon$C_DIM" "$C_RESET" \
        "$C_BRIGHT_WHITE" "$file" "$C_RESET"
}

ui_file_download() {
    local file="$1"
    local ext="${file##*.}"
    local icon=""
    case "$ext" in
        php)            icon="${C_MAGENTA}PHP" ;;
        scss|css)       icon="${C_CYAN}CSS" ;;
        ts|js)          icon="${C_YELLOW}JS " ;;
        html|twig)      icon="${C_GREEN}HTM" ;;
        json)           icon="${C_BRIGHT_YELLOW}JSN" ;;
        *)              icon="${C_DIM}···" ;;
    esac
    printf "    %s%s%s %s[%s]%s %s%s%s\n" \
        "$C_MAGENTA" "$CH_DOWNLOAD" "$C_RESET" \
        "$C_DIM" "$icon$C_DIM" "$C_RESET" \
        "$C_BRIGHT_WHITE" "$file" "$C_RESET"
}

# ── Spinner ──────────────────────────────────────────────────

_SPINNER_PID=""
_SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

ui_spinner_start() {
    local msg="$1"
    (
        local i=0
        while true; do
            printf "\r  %s%s%s %s" \
                "$C_ACCENT" "${_SPINNER_FRAMES[$((i % 10))]}" "$C_RESET" "$msg"
            i=$((i + 1))
            sleep 0.08
        done
    ) &
    _SPINNER_PID=$!
    disown "$_SPINNER_PID" 2>/dev/null
}

ui_spinner_stop() {
    if [ -n "$_SPINNER_PID" ]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
        _SPINNER_PID=""
        printf "\r\033[K"
    fi
}

# ── Progress bar ─────────────────────────────────────────────

ui_progress() {
    local current="$1"
    local total="$2"
    local label="${3:-}"
    local bar_width=30
    local filled=$(( current * bar_width / total ))
    local empty=$(( bar_width - filled ))
    local pct=$(( current * 100 / total ))

    local bar=""
    [ "$filled" -gt 0 ] && bar="$(_repeat_char "█" "$filled")"
    [ "$empty" -gt 0 ] && bar="${bar}$(_repeat_char "░" "$empty")"

    if [ -n "$label" ]; then
        printf "\r  %s%s%s %s%3d%%%s %s%s%s" \
            "$C_ACCENT" "$bar" "$C_RESET" \
            "$C_BRIGHT_WHITE" "$pct" "$C_RESET" \
            "$C_DIM" "$label" "$C_RESET"
    else
        printf "\r  %s%s%s %s%3d%%%s" \
            "$C_ACCENT" "$bar" "$C_RESET" \
            "$C_BRIGHT_WHITE" "$pct" "$C_RESET"
    fi
}

ui_progress_done() {
    printf "\r\033[K"
}

# ── Gradient progress bar ───────────────────────────────────
# Each filled block gets a color from a blue→cyan→green→yellow gradient.
# Usage: ui_progress_gradient <current> <total> ["label"]

# Gradient palette (16 steps: blue → cyan → green → yellow)
_GRADIENT_COLORS=(
    $'\033[38;5;27m'   # blue
    $'\033[38;5;33m'
    $'\033[38;5;39m'
    $'\033[38;5;44m'   # cyan
    $'\033[38;5;43m'
    $'\033[38;5;49m'
    $'\033[38;5;48m'
    $'\033[38;5;42m'   # green
    $'\033[38;5;41m'
    $'\033[38;5;77m'
    $'\033[38;5;118m'
    $'\033[38;5;154m'  # lime
    $'\033[38;5;190m'
    $'\033[38;5;220m'
    $'\033[38;5;226m'  # yellow
    $'\033[38;5;228m'  # bright yellow
)

ui_progress_gradient() {
    local current="$1"
    local total="$2"
    local label="${3:-}"
    local bar_width=30
    [ "$total" -le 0 ] && total=1
    local filled=$(( current * bar_width / total ))
    [ "$filled" -gt "$bar_width" ] && filled=$bar_width
    local empty=$(( bar_width - filled ))
    local pct=$(( current * 100 / total ))
    [ "$pct" -gt 100 ] && pct=100

    local gradient_len=${#_GRADIENT_COLORS[@]}

    # Build the gradient bar character by character
    local bar=""
    for (( i=0; i<filled; i++ )); do
        local ci=$(( i * gradient_len / bar_width ))
        [ "$ci" -ge "$gradient_len" ] && ci=$((gradient_len - 1))
        bar="${bar}${_GRADIENT_COLORS[$ci]}█"
    done

    # Unfilled portion
    local empty_bar=""
    [ "$empty" -gt 0 ] && empty_bar="$(_repeat_char "░" "$empty")"

    if [ -n "$label" ]; then
        printf "\r  %s%s%s%s%s %s%s%3d%%%s %s%s%s" \
            "$C_BOLD" "$bar" "$C_RESET" \
            "$C_DIM" "$empty_bar" \
            "$C_RESET" "$C_BRIGHT_WHITE" "$pct" "$C_RESET" \
            "$C_DIM" "$label" "$C_RESET"
    else
        printf "\r  %s%s%s%s%s %s%s%3d%%%s" \
            "$C_BOLD" "$bar" "$C_RESET" \
            "$C_DIM" "$empty_bar" \
            "$C_RESET" "$C_BRIGHT_WHITE" "$pct" "$C_RESET"
    fi
}

ui_progress_gradient_done() {
    printf "\r\033[K"
}

# ── Timestamp ────────────────────────────────────────────────

ui_timestamp() {
    printf "%s%s%s" "$C_DIM" "$(date '+%H:%M:%S')" "$C_RESET"
}

# ── Badge ────────────────────────────────────────────────────

ui_badge() {
    local text="$1"
    local color="${2:-$C_ACCENT}"
    printf "%s%s %s %s" "$color" "$C_BOLD" "$text" "$C_RESET"
}

ui_badge_ok() {
    printf "%s%s %s %s" "$C_BG_GREEN" "$C_BOLD" "$1" "$C_RESET"
}

ui_badge_err() {
    printf "%s%s %s %s" "$C_BG_RED" "$C_BOLD" "$1" "$C_RESET"
}

ui_badge_warn() {
    printf "%s%s %s %s" "$C_BG_YELLOW" "$C_BOLD" "$1" "$C_RESET"
}

# ── Status line (Claude Code style) ─────────────────────────

ui_status() {
    local status="$1"   # ok, error, warn, sync, watch
    local msg="$2"
    local ts
    ts=$(date '+%H:%M:%S')

    case "$status" in
        ok)
            printf "  %s%s%s %s%s%s %s\n" \
                "$C_GREEN" "$C_BOLD$CH_CHECK" "$C_RESET" \
                "$C_DIM" "$ts" "$C_RESET" \
                "$msg"
            ;;
        error)
            printf "  %s%s%s %s%s%s %s%s%s\n" \
                "$C_RED" "$C_BOLD$CH_CROSS" "$C_RESET" \
                "$C_DIM" "$ts" "$C_RESET" \
                "$C_RED" "$msg" "$C_RESET"
            ;;
        warn)
            printf "  %s%s%s %s%s%s %s%s%s\n" \
                "$C_YELLOW" "$C_BOLD$CH_WARN" "$C_RESET" \
                "$C_DIM" "$ts" "$C_RESET" \
                "$C_YELLOW" "$msg" "$C_RESET"
            ;;
        sync)
            printf "  %s%s%s %s%s%s %s\n" \
                "$C_ACCENT" "$C_BOLD$CH_SYNC" "$C_RESET" \
                "$C_DIM" "$ts" "$C_RESET" \
                "$msg"
            ;;
        watch)
            printf "  %s%s%s %s%s%s %s\n" \
                "$C_BRIGHT_GREEN" "$C_BOLD$CH_BULLET" "$C_RESET" \
                "$C_DIM" "$ts" "$C_RESET" \
                "$msg"
            ;;
        upload)
            printf "  %s%s%s %s%s%s %s\n" \
                "$C_CYAN" "$C_BOLD$CH_ARROW_UP" "$C_RESET" \
                "$C_DIM" "$ts" "$C_RESET" \
                "$msg"
            ;;
        download)
            printf "  %s%s%s %s%s%s %s\n" \
                "$C_MAGENTA" "$C_BOLD$CH_ARROW_DOWN" "$C_RESET" \
                "$C_DIM" "$ts" "$C_RESET" \
                "$msg"
            ;;
    esac
}

# ── Interactive select ──────────────────────────────────────

# Arrow-key selector. Sets UI_SELECT_RESULT to the chosen index (0-based).
# Usage: ui_select "Prompt text" "Option 1" "Option 2" "Option 3"
ui_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local selected=0

    # Print prompt
    printf "\n  %s%s?%s  %s%s%s\n\n" \
        "$C_ACCENT_BRIGHT" "$C_BOLD" "$C_RESET" \
        "$C_BRIGHT_WHITE" "$C_BOLD$prompt" "$C_RESET"

    # Hide cursor
    printf "\033[?25l"

    # Draw options
    _ui_select_draw() {
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                printf "  %s%s%s  %s%s%s\n" \
                    "$C_ACCENT_BRIGHT" "$C_BOLD$CH_ARROW_R" "$C_RESET" \
                    "$C_BRIGHT_WHITE$C_BOLD" "${options[$i]}" "$C_RESET"
            else
                printf "     %s%s%s\n" \
                    "$C_DIM" "${options[$i]}" "$C_RESET"
            fi
        done
    }

    _ui_select_draw

    # Read input
    while true; do
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 seq
            case "$seq" in
                '[A') # Up
                    selected=$(( (selected - 1 + count) % count ))
                    ;;
                '[B') # Down
                    selected=$(( (selected + 1) % count ))
                    ;;
            esac
            # Redraw: move cursor up by $count lines and overwrite
            printf "\033[%dA" "$count"
            _ui_select_draw
        elif [[ "$key" == "" ]]; then
            # Enter pressed
            break
        fi
    done

    # Show cursor
    printf "\033[?25h"

    # Clear the options and reprint the selected one
    printf "\033[%dA" "$count"
    for (( i=0; i<count; i++ )); do
        printf "\033[2K\n"
    done
    printf "\033[%dA" "$count"
    printf "  %s%s%s  %s%s%s\n" \
        "$C_GREEN" "$C_BOLD$CH_CHECK" "$C_RESET" \
        "$C_BRIGHT_WHITE" "${options[$selected]}" "$C_RESET"

    UI_SELECT_RESULT=$selected
}

# ── OS Detection ─────────────────────────────────────────────

detect_os_label() {
    case "$OSTYPE" in
        darwin*)          printf "%s%smacOS%s" "$C_BRIGHT_WHITE" "$C_BOLD" "$C_RESET" ;;
        linux-gnu*)       printf "%s%sLinux%s" "$C_YELLOW" "$C_BOLD" "$C_RESET" ;;
        msys*|cygwin*)    printf "%s%sWindows%s" "$C_CYAN" "$C_BOLD" "$C_RESET" ;;
        *)                printf "%s%s%s" "$C_DIM" "$OSTYPE" "$C_RESET" ;;
    esac
}

# ── Table ────────────────────────────────────────────────────

ui_table_row() {
    local label="$1"
    local value="$2"
    local status="${3:-}"  # ok, warn, error, or empty

    local status_icon=""
    case "$status" in
        ok)    status_icon="${C_GREEN}${CH_CHECK}${C_RESET} " ;;
        warn)  status_icon="${C_YELLOW}${CH_WARN}${C_RESET} " ;;
        error) status_icon="${C_RED}${CH_CROSS}${C_RESET} " ;;
    esac

    printf "  %s%-16s%s %s%s%s%s\n" \
        "$C_DIM" "$label" "$C_RESET" \
        "$status_icon" \
        "$C_BRIGHT_WHITE" "$value" "$C_RESET"
}
