# COLORS
BLUE='\033[1;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[93m'
RESET_COLOR='\033[0m'

SCRIPTNAME=$(basename "$0")

# find available and not available packages
detect_installed_packages() {
    local package command_name variable_name missing_packages=""

    for package in lolcat figlet boxes fortune cowsay eza tput; do
        command_name="$package"
        variable_name="${package^^}_AVAILABLE"

        if command -v "$command_name" >/dev/null 2>&1; then
            printf -v "$variable_name" '%s' true
        else
            printf -v "$variable_name" '%s' false
            missing_packages+=" $package"
        fi

    done

    if [[ -n "$missing_packages" ]]; then
        log_banner "Missing packages:${missing_packages} | Install them and reload your shell"
    fi
}

# ====================== Banners ==========================================

success_banner() {
    if [[ ${BOXES_AVAILABLE:-false} == true ]]; then
        echo "$*" | boxes_design -d success
    else
        printf '%b\n' "${GREEN}$(banner_border "$*")${RESET_COLOR}"
        printf '%b\n' "${GREEN}$(banner_mid    "$*")${RESET_COLOR}"
        printf '%b\n' "${GREEN}$(banner_border "$*")${RESET_COLOR}"
    fi
}

fail_banner() {
    if [[ ${BOXES_AVAILABLE:-false} == true ]]; then
        echo "$*" | boxes_design -d warning
    else
        printf '%b\n' "${RED}$(banner_border "$*")${RESET_COLOR}"
        printf '%b\n' "${RED}$(banner_mid    "$*")${RESET_COLOR}"
        printf '%b\n' "${RED}$(banner_border "$*")${RESET_COLOR}"
    fi
}

log_banner() {
    if [[ ${BOXES_AVAILABLE:-false} == true ]]; then
        echo "$*" | boxes_design -d info
    else
        banner_border "$*"
        banner_mid "$*"
        banner_border "$*"
    fi
}

center_box() {
  local data="$(</dev/stdin)"  # Read from standard input
  # Banner Width
  BW=$(cat <<< ${data} | awk '{print length}' | sort -nr | head -1)

  while IFS= read -r line; do
    line=$(echo "${line}" | sed -n -e 's/^  / /g;p')
    line=$(printf "%-${BW}s" "${line}")
    center_text "${line}"
  done <<< "${data}"
}

# -------------------- banner helpers ------------------------------

banner_border() {
    banner_mid "$*" | sed 's/./*/g'
}

banner_mid() {
    echo "* $* *"
}

boxes_design() {
    boxes -a hcvcjc -f "$HOME/.local/share/bash-styling/success-box" "$@"
}
center_text() {
    COLS=$(tput cols)  # use the current width of the terminal.
    printf "%*s\n" "$(((${#1}+${COLS})/2))" "$1"
}

# ========================== Timers =================================

SCRIPT_START=$(date +%s)
STEP_START=$SCRIPT_START
STEP_COUNT=0
PREVIOUS_STEP_DURATION=""

print_duration() {
    local delta=$1 h m s
    h=$(( delta / 3600 ))
    m=$(( (delta % 3600) / 60 ))
    s=$(( delta % 60 ))
    if   (( h > 0 )); then printf "%dh %dm %ds" "$h" "$m" "$s"
    elif (( m > 0 )); then printf "%dm %ds"      "$m" "$s"
    else                   printf "%ds"           "$s"
    fi
}

print_elapsed_time() {
    local start_time=$1
    print_duration "$(( $(date +%s) - start_time ))"
}

script_start() {
    SCRIPT_START=$(date +%s)
}

step_start() {
    local now
    now=$(date +%s)
    if (( STEP_COUNT > 0 )); then
        PREVIOUS_STEP_DURATION="$(print_duration "$(( now - STEP_START ))")"
    fi
    STEP_START=$now
    STEP_COUNT=$(( STEP_COUNT + 1 ))
}

print_script_time() { #wrapper for time since script start
    center_text "$(printf 'Script %s took %s' "$SCRIPTNAME" "$(print_elapsed_time "$SCRIPT_START")")"
}

print_step_time() { #wrapper for time since last step
    if (( STEP_COUNT <= 1 )); then
        printf "[Step 1]\n"
        return
    fi

    printf "[Step %d took %s]\n" "$(( STEP_COUNT - 1 ))" "$PREVIOUS_STEP_DURATION"
    printf "[Step %d]" "$STEP_COUNT"
}

# ========================== Aliases ================================

alias ..='cd ..'
alias ...='cd ../..'
alias ls='eza -lh --no-quotes --group-directories-first'
alias sl='ls'
alias clear="clear; figlet Let\'s go! | lolcat"
alias cl='clear; echo; ls'
alias lsa='ls -a'

# ========================= Shell startup ==========================

# On each startup, check the required packages
detect_installed_packages

# randomcow-fortune on shell startup
fortune -nsa | cowsay -f `cowsay -l | sort -R | head -1` -n | lolcat