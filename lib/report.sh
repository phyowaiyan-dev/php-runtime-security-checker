# shellcheck shell=bash
ui_init() {
    bold=''; dim=''; reset=''; green=''; yellow=''; red=''; cyan=''
    if [[ -t 1 && ${NO_COLOR+x} != x && ${TERM:-dumb} != dumb && ${no_color:-0} == 0 ]]; then
        bold=$'\033[1m'; dim=$'\033[2m'; reset=$'\033[0m'
        green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; cyan=$'\033[36m'
    fi
}
heading() { printf '\n%s%s%s\n' "$bold" "$*" "$reset"; }
message() { printf '  %s\n' "$*"; }
status_line() {
    local color=$yellow
    case $2 in PASS|COMPLETE) color=$green;; FAIL|ERROR) color=$red;; esac
    printf '  %-25s %s%s%s\n' "$1" "$color" "$2" "$reset"
}
report_human() {
    local entry p v kind cve
    heading "PHP Runtime Security Checker  $VERSION"
    printf '  %s%s  |  %s%s\n' "$dim" "$os_name" "$arch" "$reset"
    printf '  ------------------------------------------------------------\n'
    for entry in "${runtimes[@]}"; do
        IFS='|' read -r p v kind <<< "$entry"
        printf '  %-25s %s\n' "$p" "$v"
    done
    printf '\n'
    for cve in CVE-2026-109618 CVE-2026-109619; do
        advisory_status "$cve"
        status_line "$cve" "$advisory_result"
    done
    status_line 'Package result' "$overall"
    case $overall in
        PASS) message 'No package fix needed for these two CVEs.';;
        FAIL) message 'A verified PHP package fix is required.';;
        UNKNOWN) message 'Patch status is unverified; only a verified repair can be offered.';;
        ERROR) message 'The check/repair did not complete successfully.';;
    esac
    [[ -z $restart_note ]] || message "Services: $restart_note"
    [[ -z $workflow_note ]] || message "$workflow_note"
    for entry in "${warnings[@]}"; do message "$entry"; done
    printf '\n  %sScope: %s%s\n' "$dim" "$scope" "$reset"
}
# Blank/EOF/0/n/no always decline. Never read piped answers as authorization.
is_interactive() { [[ -t 0 && -t 1 ]]; }
confirm() {
    is_interactive || return 1
    local answer
    heading "$1"
    message '[1] Continue    [0] No / exit'
    while true; do
        printf '  Choice [0]: '
        IFS= read -r answer || return 1
        case ${answer,,} in 1|y|yes) return 0;; ''|0|n|no) return 1;; *) message 'Enter 1 to continue or 0 to exit.';; esac
    done
}
