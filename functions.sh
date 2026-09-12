# COLORS
BLUE='\033[1;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[93m'
RESET_COLOR='\033[0m'

SCRIPTNAME=$(basename "$0")

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

        printf '%-8s %s\n' "$package" "${!variable_name}"
    done

    if [[ -n "$missing_packages" ]]; then
        log_banner "Unavailable:$missing_packages | Install missing packages and reload your shell"
    else
        log_banner "All required packages are available"
    fi
}

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
        echo "$*" | boxes_design -d success
    else
        banner_border "$*"
        banner_mid "$*"
        banner_border "$*"
    fi
}

banner_border() {
    banner_mid "$*" | sed 's/./*/g'
}

banner_mid() {
    echo "* $* *"
}

center_text() {
    COLS=$(tput cols)  # use the current width of the terminal.
    printf "%*s\n" "$(((${#1}+${COLS})/2))" "$1"
}

boxes_design() {
    boxes -a hcvcjc -f "$HOME/.local/share/bash-styling/success-box" "$@"
}

# Center a box created with `boxes`.
center_box() {
  local data="$(</dev/stdin)"  # Read from standard input
  # Banner Width
  BW=$(cat <<< ${data} | awk '{print length}' | sort -nr | head -1)

  while IFS= read -r line; do
    line=$(echo "${line}" | sed -n -e 's/^  / /g;p')
    line=$(printf "%-${BW}s" "${line}")
    center_text "${line}"  # our center command from earlier.
  done <<< "${data}"
}

# On each startup, check the required packages
detect_installed_packages

# aliases
alias ..='cd ..'
alias ls='eza -lh --no-quotes --group-directories-first'
alias clear="clear; figlet Let\'s go! | lolcat"
alias cl='clear; echo; ls'
alias lsa='ls -a'

# randomcow-fortune on shell startup
fortune -nsa | cowsay -f `cowsay -l | sort -R | head -1` -n | lolcat