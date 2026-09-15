# COLORS
BLUE='\033[1;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[93m'
RESET_COLOR='\033[0m'

SCRIPTNAME=$(basename "$0")

# =========================== Update packages ======================================

BASH_STYLING_REPO="${BASH_STYLING_REPO:-Lai-es/bash-styling}"
BASH_STYLING_INSTALL_DIR="${BASH_STYLING_INSTALL_DIR:-$HOME/.local/share/bash-styling}"
BASH_STYLING_VERSION_FILE="$BASH_STYLING_INSTALL_DIR/VERSION"
BASH_STYLING_STARTUP_COUNT_FILE="$BASH_STYLING_INSTALL_DIR/startup-count"

# pull latest github repo version
get_latest_version() {
    local url final_url version
    url="https://github.com/${BASH_STYLING_REPO}/releases/latest"

    if command -v curl >/dev/null 2>&1; then
        final_url="$(curl -sSfIL -o /dev/null -w '%{url_effective}' "$url" 2>/dev/null || true)"
    elif command -v wget >/dev/null 2>&1; then
        final_url="$(wget --max-redirect=0 --server-response -O /dev/null "$url" 2>&1 | grep -i 'location:' | head -1 || true)"
    else
        return 1
    fi

    version="$(printf '%s' "$final_url" | sed 's|.*/||' | cut -d' ' -f1 | tr -d '\r\n')"
    [[ -n "$version" ]] && printf '%s\n' "$version"
}

# scan for updates on the github repo
update_library() {
    local startup_count current_version latest_version update_command

    if [[ ${1:-} == '-q' || ${1:-} == '--quiet' ]]; then
        return 0
    fi

    mkdir -p "$BASH_STYLING_INSTALL_DIR" 2>/dev/null || return 0
    startup_count="$(cat "$BASH_STYLING_STARTUP_COUNT_FILE" 2>/dev/null || printf '0')"
    [[ "$startup_count" =~ ^[0-9]+$ ]] || startup_count=0
    startup_count=$((startup_count + 1))
    printf '%s\n' "$startup_count" > "$BASH_STYLING_STARTUP_COUNT_FILE" || return 0
    (( startup_count % 10 == 0 )) || return 0

    current_version="$(cat "$BASH_STYLING_VERSION_FILE" 2>/dev/null || true)"
    [[ -n "$current_version" ]] || return 0
    latest_version="$(get_latest_version 2>/dev/null || true)"
    [[ -n "$latest_version" && "$latest_version" != "$current_version" ]] || return 0

    update_command="curl -fsSL https://raw.githubusercontent.com/${BASH_STYLING_REPO}/main/install.sh | bash"
    
    log_banner "bash-styling update available: ${latest_version} (installed: ${current_version}). Run: ${update_command}\n"
}

# find available and not available packages
detect_installed_packages() {
    local package command_name variable_name missing_packages="" package_list answer

    if [[ ${1:-} == '-q' || ${1:-} == '--quiet' ]]; then
        return 0
    fi

    for package in lolcat figlet boxes fortune cowsay eza tput zoxide; do
        command_name="$package"
        variable_name="${package^^}_AVAILABLE"

        if command -v "$command_name" >/dev/null 2>&1; then
            printf -v "$variable_name" '%s' true
        else
            printf -v "$variable_name" '%s' false
            missing_packages+=" $package,"
        fi

    done

    if [[ -n "$missing_packages" ]]; then
        log_banner "Missing packages:${missing_packages} | Install them and reload your shell"
        read -r -p 'Would you like to install the missing packages? [y/N] ' answer
        if [[ ! "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            return 0
        fi

        package_list="${missing_packages%,}"
        package_list="${package_list//, / }"
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y $package_list
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y $package_list
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --needed --noconfirm $package_list
        elif command -v brew >/dev/null 2>&1; then
            brew install $package_list
        else
            printf 'No supported package manager found.\n' >&2
        fi
    fi
}

# ====================== Banners ==========================================

success_banner() {
    if [[ ${BOXES_AVAILABLE:-false} == true ]]; then
        printf '%s\n' "$*" | center_box | boxes_design -d success
    else
        printf '%b\n' "${GREEN}$(
            {
                banner_border "$*"
                banner_mid "$*"
                banner_border "$*"
            } | center_box
        )${RESET_COLOR}"
    fi
}

warning_banner() {
    if [[ ${BOXES_AVAILABLE:-false} == true ]]; then
        printf '%s\n' "$*" | center_box | boxes_design -d warning
    else
        printf '%b\n' "${RED}$(
            {
                banner_border "$*"
                banner_mid "$*"
                banner_border "$*"
            } | center_box
        )${RESET_COLOR}"
    fi
}

fail_banner() {
    warning_banner "$@"
}

log_banner() {
    if [[ ${BOXES_AVAILABLE:-false} == true ]]; then
        printf '%s\n' "$*" | center_box | boxes_design -d info
    else
        {
            banner_border "$*"
            banner_mid "$*"
            banner_border "$*"
        } | center_box
    fi
}

# -------------------- banner helpers ------------------------------

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

banner_border() {
    banner_mid "$*" | sed 's/./*/g'
}

banner_mid() {
    echo "* $* *"
}

boxes_design() {
    boxes -a hcvcjc -f "$BASH_STYLING_INSTALL_DIR/success-box" "$@"
}

center_text() {
    COLS=$(tput cols)  # use the current width of the terminal.
    printf "%*s\n" "$(((${#1}+${COLS})/2))" "$1"
}

# ========================== Timers =================================

SCRIPT_START=$(date +%s)
SCRIPT_STARTED=false
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
    SCRIPT_STARTED=true
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
    local script_time
    script_time="$(printf 'Script %s took %s' "$SCRIPTNAME" "$(print_elapsed_time "$SCRIPT_START")")"

    if [[ $SCRIPT_STARTED == true ]]; then
        log_banner "$script_time"
    else
        warning_banner "Warning: script_start was not called; timing began when the library was loaded. $script_time"
    fi
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
if [[ ${EZA_AVAILABLE:-false} == true]]; then
    alias ls='eza -lh --no-quotes --group-directories-first'
else
    alias ls='ls -lh --group-directories-first --color=auto'
fi
alias sl='ls'
if [[ ${FIGLET_AVAILABLE:-false} == true && ${LOLCAT_AVAILABLE:-false} == true ]]; then
    alias clear="clear; figlet Let\'s go! | lolcat"
fi
alias cl='clear; echo; ls'
alias lsa='ls -a'
alias lc='wc -l'

# ============================ colored Cow-fortune ===================

fortune_cow_colored() {
    local cow output bottom=-1 colored line left right
    local -a lines colored_lines

    cow="$(cowsay -l | sed '1d' | sort -R | head -1)"
    output="$(fortune -nsa | cowsay -n -f "$cow")"

  mapfile -t lines <<< "$output"

  for i in "${!lines[@]}"; do
    if [[ "${lines[$i]}" =~ ^[[:space:]]*-+[[:space:]]*$ ]]; then
      bottom=$i
      break
    fi
  done

    (( bottom > 1 )) || return 1

    # Color the message as one stream so lolcat does not restart its palette per line.
    mapfile -t colored_lines < <(
        for ((i = 1; i < bottom; i++)); do
            line=${lines[$i]}
            printf '%s\n' "${line:2:${#line}-4}"
        done | lolcat -f
    )

    printf '%s\n' "${lines[0]}"
    for ((i = 1; i < bottom; i++)); do
        line=${lines[$i]}
        left=${line:0:2}
        right=${line: -2}
        colored=${colored_lines[$((i - 1))]}
        printf '%s%s\033[0m%s\n' "$left" "$colored" "$right"
    done
  printf '%s\n' "${lines[$bottom]}"
  for ((i = bottom + 1; i < ${#lines[@]}; i++)); do
    printf '%s\n' "${lines[$i]}"
  done
}

# ========================= Shell startup ==========================

# On each startup, check the required packages
detect_installed_packages "$@"
update_library "$@"

if [[ ${FORTUNE_AVAILABLE:-false} == true && ${COWSAY_AVAILABLE:-false} == true ]]; then
    if [[ ${LOLCAT_AVAILABLE:-false} == true ]]; then
        fortune_cow_colored
    else 
        fortune -nsa | cowsay -f "$(cowsay -l | sort -R | head -1)" -n
    fi
fi