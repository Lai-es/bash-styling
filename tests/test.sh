#!/usr/bin/env bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT_DIR/install.sh"
LIBRARY="$ROOT_DIR/lib/functions.sh"
PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$1" >&2
}

section() {
    printf '\n== %s ==\n' "$1"
}

assert_file() {
    local description=$1 path=$2
    if [[ -f "$path" ]]; then
        pass "$description"
    else
        fail "$description: missing $path"
    fi
}

assert_contains() {
    local description=$1 expected=$2 file=$3
    if grep -Fq "$expected" "$file"; then
        pass "$description"
    else
        fail "$description: did not find '$expected' in $file"
    fi
}

assert_equal() {
    local description=$1 expected=$2 actual=$3
    if [[ "$expected" == "$actual" ]]; then
        pass "$description"
    else
        fail "$description: expected '$expected', got '$actual'"
    fi
}

TMP_DIR=$(mktemp -d)
MOCK_BIN="$TMP_DIR/bin"
MOCK_HOME="$TMP_DIR/home"
MOCK_LOG="$TMP_DIR/mock.log"
mkdir -p "$MOCK_BIN" "$MOCK_HOME"
trap 'rm -rf "$TMP_DIR"' EXIT

make_mock_command() {
    local name=$1 output=${2-}
    cat > "$MOCK_BIN/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\\n' '$name' "\$*" >> "$MOCK_LOG"
${output:+printf '%s\\n' '$output'}
EOF
    chmod +x "$MOCK_BIN/$name"
}

make_passthrough_command() {
    local name=$1
    cat > "$MOCK_BIN/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\\n' '$name' "\$*" >> "$MOCK_LOG"
cat
EOF
    chmod +x "$MOCK_BIN/$name"
}

# The installer mock returns a release tag and copies the local release files.
cat > "$MOCK_BIN/curl" <<EOF
#!/usr/bin/env bash
set -u
printf 'curl %s\\n' "\$*" >> "$MOCK_LOG"
if [[ "\$*" == *"releases/latest"* ]]; then
    printf 'v-test'
    exit 0
fi
output=''
previous=''
for argument in "\$@"; do
    if [[ "\$previous" == '-o' ]]; then
        output="\$argument"
        break
    fi
    previous="\$argument"
done
case "\$*" in
    *lib/functions.sh*) cp "$LIBRARY" "\$output" ;;
    *lib/success-box*) cp "$ROOT_DIR/lib/success-box" "\$output" ;;
    *) printf 'unexpected mock curl request: %s\\n' "\$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$MOCK_BIN/curl"

# Stub startup dependencies so sourcing the library is deterministic and quiet.
make_passthrough_command lolcat
make_passthrough_command figlet
make_passthrough_command boxes
make_mock_command fortune 'printf test-fortune'
make_passthrough_command cowsay
make_mock_command eza 'printf test-eza'
cat > "$MOCK_BIN/tput" <<EOF
#!/usr/bin/env bash
printf 'tput %s\\n' "\$*" >> "$MOCK_LOG"
printf '80'
EOF
chmod +x "$MOCK_BIN/tput"

section 'Static validation'
if bash -n "$INSTALLER" "$LIBRARY" "$0"; then
    pass 'installer, library, and test script parse successfully'
else
    fail 'shell syntax validation'
fi

section 'Installer install'
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash "$INSTALLER" install > "$TMP_DIR/install.out"
assert_file 'installer downloads functions library' "$MOCK_HOME/.local/share/bash-styling/functions.sh"
assert_file 'installer downloads success box design' "$MOCK_HOME/.local/share/bash-styling/success-box"
assert_contains 'installer adds managed source block' '# >>> bash-styling >>>' "$MOCK_HOME/.bashrc"
assert_contains 'installer uses the release version' 'version: v-test' "$MOCK_HOME/.bashrc"
assert_contains 'installer points to downloaded library' 'source "/' "$MOCK_HOME/.bashrc"

section 'Installer update'
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash "$INSTALLER" install > "$TMP_DIR/update.out"
block_count=$(grep -cF '# >>> bash-styling >>>' "$MOCK_HOME/.bashrc")
assert_equal 'reinstall keeps one managed source block' '1' "$block_count"
backup_count=$(find "$MOCK_HOME" -maxdepth 1 -name '.bashrc.bak.*' | wc -l)
if (( backup_count >= 1 )); then
    pass 'reinstall creates a bashrc backup'
else
    fail 'reinstall creates a bashrc backup'
fi

section 'Installer uninstall'
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash "$INSTALLER" uninstall > "$TMP_DIR/uninstall.out"
if [[ ! -e "$MOCK_HOME/.local/share/bash-styling" ]]; then
    pass 'uninstall removes installed files'
else
    fail 'uninstall removes installed files'
fi
if ! grep -qF '# >>> bash-styling >>>' "$MOCK_HOME/.bashrc"; then
    pass 'uninstall removes the managed bashrc block'
else
    fail 'uninstall removes the managed bashrc block'
fi

section 'Library startup and package detection'
LIB_OUTPUT="$TMP_DIR/library.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c 'source "$1"' bash "$LIBRARY" > "$LIB_OUTPUT" 2>&1
if ! grep -qE 'Missing packages:|All required packages are available|lolcat   true' "$LIB_OUTPUT"; then
    pass 'startup is silent when all required packages are available'
else
    fail 'startup is silent when all required packages are available'
fi

MISSING_OUTPUT="$TMP_DIR/missing-packages.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    command() {
        [[ "$2" == lolcat || "$2" == boxes || "$2" == tput ]]
    }
    log_banner() { printf "banner:%s\\n" "$*"; }
    detect_installed_packages
' bash "$LIBRARY" > "$MISSING_OUTPUT"
assert_contains 'missing package banner is displayed' 'banner:Missing packages: figlet fortune cowsay eza' "$MISSING_OUTPUT"
if ! grep -qE 'lolcat|boxes|tput' "$MISSING_OUTPUT"; then
    pass 'missing package banner excludes available packages'
else
    fail 'missing package banner excludes available packages'
fi

section 'Banner functions'
BANNER_OUTPUT="$TMP_DIR/banners.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    BOXES_AVAILABLE=false
    success_banner success-message
    fail_banner failure-message
    log_banner log-message
' bash "$LIBRARY" > "$BANNER_OUTPUT"
assert_contains 'success banner fallback renders text' '* success-message *' "$BANNER_OUTPUT"
assert_contains 'failure banner fallback renders text' '* failure-message *' "$BANNER_OUTPUT"
assert_contains 'log banner fallback renders text' '* log-message *' "$BANNER_OUTPUT"

section 'Banner helpers and boxes path'
BOX_OUTPUT="$TMP_DIR/boxes.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    boxes_design() { printf "style=%s input=%s\\n" "$2" "$(cat)"; }
    BOXES_AVAILABLE=true
    success_banner success-message
    fail_banner failure-message
    log_banner log-message
' bash "$LIBRARY" > "$BOX_OUTPUT"
assert_contains 'success banner passes success style' 'style=success input=success-message' "$BOX_OUTPUT"
assert_contains 'failure banner passes warning style' 'style=warning input=failure-message' "$BOX_OUTPUT"
assert_contains 'log banner uses boxes path' 'style=info input=log-message' "$BOX_OUTPUT"

section 'Timer functions'
TIMER_OUTPUT="$TMP_DIR/timers.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    printf "duration_seconds="; print_duration 5; printf "\\n"
    printf "duration_minutes="; print_duration 65; printf "\\n"
    printf "duration_hours="; print_duration 3665; printf "\\n"
    STEP_COUNT=0
    STEP_START=$(date +%s)
    step_start
    print_step_time
    STEP_START=$(( $(date +%s) - 65 ))
    step_start
    print_step_time
' bash "$LIBRARY" > "$TIMER_OUTPUT"
assert_contains 'duration formatter handles seconds' 'duration_seconds=5s' "$TIMER_OUTPUT"
assert_contains 'duration formatter handles minutes' 'duration_minutes=1m 5s' "$TIMER_OUTPUT"
assert_contains 'duration formatter handles hours' 'duration_hours=1h 1m 5s' "$TIMER_OUTPUT"
assert_contains 'first step has no previous duration' '[Step 1]' "$TIMER_OUTPUT"
assert_contains 'later step reports previous duration' '[Step 1 took 1m 5s' "$TIMER_OUTPUT"

SCRIPT_TIMER_OUTPUT="$TMP_DIR/script-timer.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    script_start
    print_script_time
    printf "\\n"
' bash "$LIBRARY" > "$SCRIPT_TIMER_OUTPUT"
if grep -Eq '^[[:space:]]*Script bash took [0-9]+s$|^[[:space:]]*Script bash took [0-9]+m [0-9]+s$|^[[:space:]]*Script bash took [0-9]+h [0-9]+m [0-9]+s$' "$SCRIPT_TIMER_OUTPUT"; then
    pass 'script timer prints formatted elapsed time'
else
    fail 'script timer prints formatted elapsed time'
fi

section 'Aliases and text helpers'
HELPER_OUTPUT="$TMP_DIR/helpers.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    banner_mid hello
    banner_border hello
    center_text hello
' bash "$LIBRARY" > "$HELPER_OUTPUT"
assert_contains 'banner_mid formats text' '* hello *' "$HELPER_OUTPUT"
assert_contains 'banner_border formats text' '*********' "$HELPER_OUTPUT"
assert_contains 'center_text emits text' 'hello' "$HELPER_OUTPUT"

ALIAS_OUTPUT="$TMP_DIR/aliases.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    shopt -s expand_aliases
    source "$1" >/dev/null 2>&1
    alias .. ... ls sl clear cl lsa
' bash "$LIBRARY" > "$ALIAS_OUTPUT"
assert_contains 'navigation aliases are defined' "alias ..='cd ..'" "$ALIAS_OUTPUT"
assert_contains 'ls alias is defined' "alias ls='eza -lh --no-quotes --group-directories-first'" "$ALIAS_OUTPUT"
assert_contains 'clear alias is defined' "alias clear=" "$ALIAS_OUTPUT"

CENTER_BOX_OUTPUT="$TMP_DIR/center-box.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    center_box <<EOF
one
two
EOF
' bash "$LIBRARY" > "$CENTER_BOX_OUTPUT"
assert_contains 'center_box preserves input lines' 'one' "$CENTER_BOX_OUTPUT"
assert_contains 'center_box preserves multiple input lines' 'two' "$CENTER_BOX_OUTPUT"

BOXES_DESIGN_OUTPUT="$TMP_DIR/boxes-design.out"
HOME="$MOCK_HOME" PATH="$MOCK_BIN:$PATH" bash -c '
    source "$1" >/dev/null 2>&1
    boxes_design -d success <<EOF
boxed
EOF
' bash "$LIBRARY" > "$BOXES_DESIGN_OUTPUT"
assert_contains 'boxes_design forwards the requested style' 'boxed' "$BOXES_DESIGN_OUTPUT"

printf '\nTest summary: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
    exit 1
fi
