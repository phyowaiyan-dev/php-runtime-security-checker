# shellcheck shell=bash
VERSION=1.1.0
scope='Installed PHP packages only; Laravel dependencies and running workers are not checked.'
warnings=(); runtimes=(); results=(); origins=()
overall=PASS; operation_error=0
warn() {
    local message
    for message in "${warnings[@]}"; do [[ $message != "$*" ]] || return 0; done
    warnings+=("$*")
}
unknown() { [[ $overall == FAIL ]] || overall=UNKNOWN; warn "$*"; }
fail() { overall=FAIL; }
error() { operation_error=1; warn "$*"; }
json_string() {
    local s=$1 i c
    printf '"'
    for ((i=0; i<${#s}; i++)); do
        c=${s:i:1}
        # Literal JSON escape sequences.
        # shellcheck disable=SC1003
        case $c in
            '"') printf '\\"';; \\) printf '\\\\';;
            $'\n') printf '\\n';; $'\r') printf '\\r';; $'\t') printf '\\t';;
            *) if [[ $c < ' ' ]]; then printf '\\u%04x' "'$c"; else printf '%s' "$c"; fi;;
        esac
    done
    printf '"'
}
json_array() { local sep='' v; printf '['; for v in "$@"; do printf '%s' "$sep"; json_string "$v"; sep=,; done; printf ']'; }
