#!/bin/bash

# Combined Powerline + GSD Statusline for Claude Code
# Catppuccin Mocha theme with Nerd Font glyphs

# Read JSON input from stdin
input=$(cat)

# Extract all values in one jq call (avoids 5 separate spawns)
eval "$(echo "$input" | jq -r '@sh "
  cwd=\(.workspace.current_dir // "")
  model=\(.model.display_name // "Claude")
  session_id=\(.session_id // "")
  remaining_pct=\(.context_window.remaining_percentage // "")
  used_pct=\(.context_window.used_percentage // "")
"')"

# --- API Usage Cache (atomic writes) ---
usage_cache="/tmp/claude-usage-cache.json"
usage_cache_age=60

fetch_usage() {
    creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    [ -z "$creds" ] && return 1

    token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    [ -z "$token" ] && return 1

    tmp="${usage_cache}.tmp.$$"
    if curl -s -X GET "https://api.anthropic.com/api/oauth/usage" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        2>/dev/null > "$tmp"; then
        mv -f "$tmp" "$usage_cache"
    else
        rm -f "$tmp"
    fi
}

# Check cache age and refresh if needed (background)
if [ -f "$usage_cache" ]; then
    cache_mtime=$(stat -f %m "$usage_cache" 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$((now - cache_mtime))
    if [ "$age" -gt "$usage_cache_age" ]; then
        fetch_usage &
    fi
else
    fetch_usage &
fi

# Read usage data from cache (only if file exists and is non-empty)
if [ -s "$usage_cache" ]; then
    usage_data=$(cat "$usage_cache" 2>/dev/null)
    five_hour_util=$(echo "$usage_data" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    five_hour_reset=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
    seven_day_util=$(echo "$usage_data" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    seven_day_reset=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)
fi

# Change to the working directory for git commands
cd "$cwd" 2>/dev/null || true

# --- Catppuccin Mocha (256 color) ---
fg_crust="\033[38;5;234m"
bg_crust="\033[48;5;234m"
fg_mauve="\033[38;5;183m"
bg_mauve="\033[48;5;183m"
fg_peach="\033[38;5;216m"
bg_peach="\033[48;5;216m"
fg_yellow="\033[38;5;223m"
bg_yellow="\033[48;5;223m"
fg_green="\033[38;5;157m"
bg_green="\033[48;5;157m"
fg_sapphire="\033[38;5;117m"
bg_sapphire="\033[48;5;117m"
fg_lavender="\033[38;5;189m"
bg_lavender="\033[48;5;189m"
fg_red="\033[38;5;211m"
bg_red="\033[48;5;211m"
fg_white="\033[38;5;255m"
fg_gray="\033[38;5;245m"
reset="\033[0m"
blink="\033[5m"

# Nerd Font icons
git_branch_icon=$(printf '\xee\x82\xa0')   # U+E0A0
git_staged_icon=$(printf '\xef\x81\xa7')    # U+F067
git_modified_icon=$(printf '\xef\x81\x80')  # U+F040
git_deleted_icon=$(printf '\xef\x81\xa8')   # U+F068
git_untracked_icon=$(printf '\xef\x84\xa8') # U+F128

# Powerline separators
sep_right=$(printf '\xee\x82\xb0')  # U+E0B0
sep_left=$(printf '\xee\x82\xb2')   # U+E0B2

# Mac icon
mac_icon=$(printf '\xef\x8c\x82')   # U+F302

output=""

# --- GSD UPDATE: Yellow notification if update available ---
update_cache="$HOME/.claude/cache/gsd-update-check.json"
if [ -s "$update_cache" ]; then
    update_avail=$(jq -r '.update_available // false' "$update_cache" 2>/dev/null)
    if [ "$update_avail" = "true" ]; then
        output+="${fg_yellow}${sep_left}${reset}"
        output+="${bg_yellow}${fg_crust} ⬆ /gsd:update ${reset}"
        output+="${fg_yellow}${bg_mauve}${sep_right}"
    fi
fi

# --- MAC: Apple icon (mauve background) ---
if [ -z "$update_avail" ] || [ "$update_avail" != "true" ]; then
    output+="${fg_mauve}${sep_left}${reset}"
fi
output+="${bg_mauve}${fg_crust} ${mac_icon} ${reset}"
output+="${fg_mauve}${bg_peach}${sep_right}"
last_bg="mauve"

# --- DIR: Directory (peach background) ---
dir_display="${cwd/#$HOME/~}"
output+="${bg_peach}${fg_crust} 📁 ${dir_display} ${reset}"
last_bg="peach"

# --- GIT: Branch and status (yellow background) ---
git_section=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_section+=" ${git_branch_icon} ${branch}"

        porcelain=$(git -c core.useBuiltinFSMonitor=false status --porcelain 2>/dev/null)
        if [ -n "$porcelain" ]; then
            staged=$(echo "$porcelain" | grep -c "^[MARCD]" || true)
            modified=$(echo "$porcelain" | grep -c "^.M" || true)
            untracked=$(echo "$porcelain" | grep -c "^??" || true)
            deleted=$(echo "$porcelain" | grep -c "^.D" || true)

            [ "$staged" -gt 0 ] 2>/dev/null && git_section+=" ${git_staged_icon}${staged}"
            [ "$modified" -gt 0 ] 2>/dev/null && git_section+=" ${git_modified_icon}${modified}"
            [ "$deleted" -gt 0 ] 2>/dev/null && git_section+=" ${git_deleted_icon}${deleted}"
            [ "$untracked" -gt 0 ] 2>/dev/null && git_section+=" ${git_untracked_icon}${untracked}"
        fi
        git_section+=" "
    fi
fi

if [ -n "$git_section" ]; then
    output+="${fg_peach}${bg_yellow}${sep_right}"
    output+="${bg_yellow}${fg_crust}${git_section}${reset}"
    last_bg="yellow"
fi

# --- GSD TASK: Current task from todos (green background) ---
task_display=""
if [ -n "$session_id" ]; then
    todos_dir="$HOME/.claude/todos"
    if [ -d "$todos_dir" ]; then
        # Find most recent agent todo file for this session
        latest_todo=$(ls -t "$todos_dir"/${session_id}-agent-*.json 2>/dev/null | head -1)
        if [ -s "$latest_todo" ]; then
            task_display=$(jq -r '
                [.[] | select(.status == "in_progress")] | first |
                .activeForm // empty
            ' "$latest_todo" 2>/dev/null)
            # Truncate to 30 chars
            if [ ${#task_display} -gt 30 ]; then
                task_display="${task_display:0:27}..."
            fi
        fi
    fi
fi

if [ -n "$task_display" ]; then
    case "$last_bg" in
        yellow) output+="${fg_yellow}${bg_green}${sep_right}" ;;
        peach)  output+="${fg_peach}${bg_green}${sep_right}" ;;
        *)      output+="${bg_green}${sep_right}" ;;
    esac
    output+="${bg_green}${fg_crust} 📋 ${task_display} ${reset}"
    last_bg="green"
fi

# --- CTX: Context Window (mauve background, scaled to 80% limit) ---
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    # Scale: Claude Code enforces 80% limit, so 80% real = 100% displayed
    raw_used=$(printf "%.0f" "$used_pct")
    scaled_used=$(awk "BEGIN { v = ($raw_used / 80) * 100; if (v > 100) v = 100; printf \"%.0f\", v }")

    # Write context bridge file for gsd-context-monitor.js (atomic)
    if [ -n "$session_id" ]; then
        bridge_path="/tmp/claude-ctx-${session_id}.json"
        bridge_tmp="${bridge_path}.tmp.$$"
        now_ts=$(date +%s)
        if printf '{"session_id":"%s","remaining_percentage":%s,"used_pct":%s,"timestamp":%s}' \
            "$session_id" "$remaining_pct" "$scaled_used" "$now_ts" > "$bridge_tmp" 2>/dev/null; then
            mv -f "$bridge_tmp" "$bridge_path"
        else
            rm -f "$bridge_tmp"
        fi
    fi

    # Progress bar (10 segments)
    filled=$(( scaled_used / 10 ))
    [ "$filled" -gt 10 ] && filled=10
    [ "$filled" -lt 0 ] && filled=0
    empty=$((10 - filled))

    bar=""
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    for ((i=0; i<empty; i++)); do bar+="▱"; done

    # Brain or blinking skull at >=95% scaled
    if [ "$scaled_used" -ge 95 ]; then
        ctx_icon="${blink}💀${reset}"
    else
        ctx_icon="🧠"
    fi

    # Separator from previous section
    ctx_bg="${bg_mauve}"
    case "$last_bg" in
        green)  output+="${fg_green}${ctx_bg}${sep_right}" ;;
        yellow) output+="${fg_yellow}${ctx_bg}${sep_right}" ;;
        peach)  output+="${fg_peach}${ctx_bg}${sep_right}" ;;
        *)      output+="${fg_peach}${ctx_bg}${sep_right}" ;;
    esac
    output+="${ctx_bg}${fg_crust} ${ctx_icon} ${bar} ${scaled_used}% ${reset}"
    last_bg="mauve"
fi

# --- MODEL: Model name (sapphire background) ---
case "$last_bg" in
    green)    output+="${fg_green}${bg_sapphire}${sep_right}" ;;
    yellow)   output+="${fg_yellow}${bg_sapphire}${sep_right}" ;;
    lavender) output+="${fg_lavender}${bg_sapphire}${sep_right}" ;;
    peach)    output+="${fg_peach}${bg_sapphire}${sep_right}" ;;
    red)      output+="${fg_red}${bg_sapphire}${sep_right}" ;;
    mauve)    output+="${fg_mauve}${bg_sapphire}${sep_right}" ;;
    *)        output+="${fg_peach}${bg_sapphire}${sep_right}" ;;
esac
output+="${bg_sapphire}${fg_crust} ${model} ${reset}"
last_bg="sapphire"

# --- USAGE: 5-hour and 7-day API limits ---
if [ -n "$five_hour_util" ] && [ "$five_hour_util" != "null" ]; then
    five_remaining=$((100 - ${five_hour_util%.*}))
    if (( five_remaining > 50 )); then
        usage_fg="${fg_green}"; usage_bg="${bg_green}"; usage_bg_name="green"
    elif (( five_remaining > 25 )); then
        usage_fg="${fg_yellow}"; usage_bg="${bg_yellow}"; usage_bg_name="yellow"
    elif (( five_remaining > 10 )); then
        usage_fg="${fg_peach}"; usage_bg="${bg_peach}"; usage_bg_name="peach"
    else
        usage_fg="${fg_red}"; usage_bg="${bg_red}"; usage_bg_name="red"
    fi

    case "$last_bg" in
        lavender) output+="${fg_lavender}${usage_bg}${sep_right}" ;;
        sapphire) output+="${fg_sapphire}${usage_bg}${sep_right}" ;;
        *)        output+="${usage_bg}${sep_right}" ;;
    esac

    five_int=$(printf "%.0f" "$five_hour_util")

    # Format 5-hour reset time
    five_reset_display=""
    if [ -n "$five_hour_reset" ] && [ "$five_hour_reset" != "null" ]; then
        reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$five_hour_reset" | sed 's/\.[0-9]*+.*//')" "+%s" 2>/dev/null)
        if [ -n "$reset_epoch" ]; then
            five_reset_display=$(date -r "$reset_epoch" +"%-I%p" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        fi
    fi

    # Format 7-day reset time
    seven_reset_display=""
    if [ -n "$seven_day_reset" ] && [ "$seven_day_reset" != "null" ]; then
        reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$seven_day_reset" | sed 's/\.[0-9]*+.*//')" "+%s" 2>/dev/null)
        if [ -n "$reset_epoch" ]; then
            now_epoch=$(date +%s)
            days_diff=$(( (reset_epoch - now_epoch) / 86400 ))
            if [ "$days_diff" -le 6 ]; then
                seven_reset_display=$(date -r "$reset_epoch" +"%a %-I%p" 2>/dev/null | tr '[:upper:]' '[:lower:]')
            else
                seven_reset_display=$(date -r "$reset_epoch" +"%b %-d" 2>/dev/null)
            fi
        fi
    fi

    # "5h: 6% @12pm | 7d: 35% @Mon 5pm"
    usage_display=" 📊 5h: ${five_int}%"
    [ -n "$five_reset_display" ] && usage_display+=" @${five_reset_display}"

    if [ -n "$seven_day_util" ] && [ "$seven_day_util" != "null" ]; then
        seven_int=$(printf "%.0f" "$seven_day_util")
        usage_display+=" | 7d: ${seven_int}%"
        [ -n "$seven_reset_display" ] && usage_display+=" @${seven_reset_display}"
    fi

    output+="${usage_bg}${fg_crust}${usage_display} ${reset}"
    output+="${usage_fg}${sep_right}${reset}"
else
    output+="${fg_sapphire}${sep_right}${reset}"
fi

# --- TIME: 12-hour format ---
current_time=$(date +"%-I:%M %p")
output+=" ${fg_lavender}${current_time}${reset}"

printf "%b" "$output"
