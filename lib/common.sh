# shellcheck shell=bash
VERSION=1.2.0
scope='Two PHP CVEs only; Laravel dependencies, custom/container PHP and existing workers are outside this package check.'
warnings=(); runtimes=(); results=(); origins=(); inventory=''
overall=PASS; operation_error=0; supported=0
workflow_note=''; restart_note=''; action_error=0
warn() {
    local message
    for message in "${warnings[@]}"; do [[ $message != "$*" ]] || return 0; done
    warnings+=("$*")
}
unknown() { [[ $overall == FAIL ]] || overall=UNKNOWN; warn "$*"; }
fail() { overall=FAIL; }
error() { operation_error=1; warn "$*"; }
status_code() {
    case $overall in PASS) return 0;; FAIL) return 1;; UNKNOWN) return 2;; *) return 3;; esac
}
snapshot() {
    warnings=(); runtimes=(); results=(); origins=(); inventory=''
    overall=PASS; operation_error=0; supported=0; os_name=unknown; arch=unknown
    local required
    for required in dpkg dpkg-query apt-cache; do
        command -v "$required" >/dev/null || { error "Required utility unavailable: $required"; overall=ERROR; return; }
    done
    detect
    ((operation_error)) || audit
    ((operation_error==0)) || overall=ERROR
}
# No automatic escalation: this is called only after an explicit workflow confirmation.
run_root() {
    if ((EUID==0)); then "$@"
    elif command -v sudo >/dev/null; then sudo -n -- "$@"
    else return 1
    fi
}

authorize_root() {
    ((EUID==0)) && return 0
    command -v sudo >/dev/null && sudo -v
}
