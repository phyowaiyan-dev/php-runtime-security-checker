# shellcheck shell=bash
VERSION=1.0.0
warnings=()
limitations=('Only the two documented CVEs are assessed; this is not a complete server security audit.' 'Containers, custom builds, remote FPM, application dependencies and long-running CLI workers require manual review.' 'APT metadata is local and may be stale; refresh it separately before remediation.')
runtimes=(); services=(); packages=(); results=(); origins=(); activities=()
overall=PASS; service_status=PASS; reboot=NO; operation_error=0
warn() { warnings+=("$*"); }
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
