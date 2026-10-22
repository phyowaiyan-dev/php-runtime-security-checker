# shellcheck shell=bash
report_json() {
    local i p v kind cve status entry sep=''
    printf '{"tool_version":'; json_string "$VERSION"
    printf ',"timestamp":'; json_string "$(date -u +%FT%TZ)"
    printf ',"os":'; json_string "$os_name"; printf ',"architecture":'; json_string "$arch"
    printf ',"runtimes":['
    for ((i=0;i<${#runtimes[@]};i++)); do
        IFS='|' read -r p v kind <<< "${runtimes[i]}"
        printf '%s{"package":' "$sep"; json_string "$p"; printf ',"version":'; json_string "$v"
        printf ',"type":'; json_string "$kind"; printf ',"origin":'; json_string "${origins[i]}"
        printf '}'; sep=,
    done
    printf '],"cves":['; sep=''
    for entry in "${results[@]}"; do
        IFS='|' read -r p cve status <<< "$entry"
        printf '%s{"package":' "$sep"; json_string "$p"
        printf ',"id":'; json_string "$cve"; printf ',"status":'; json_string "$status"
        printf '}'; sep=,
    done
    printf ']'
    printf ',"scope":'; json_string "$scope"
    printf ',"overall":'; json_string "$overall"
    printf ',"warnings":'; json_array "${warnings[@]}"; printf '}\n'
}
report_human() {
    local entry p v kind cve
    printf 'PHP Runtime Security Checker v%s\nOS: %s (%s)\n' "$VERSION" "$os_name" "$arch"
    for entry in "${runtimes[@]}"; do
        IFS='|' read -r p v kind <<< "$entry"
        printf 'PHP %s: %s\n' "$kind" "$v"
    done
    for cve in CVE-2026-109618 CVE-2026-109619; do
        advisory_status "$cve"
        printf '%s: %s\n' "$cve" "$advisory_result"
    done
    printf 'Overall: %s (PHP package checks)\n' "$overall"
    for entry in "${warnings[@]}"; do printf 'Note: %s\n' "$entry"; done
    printf 'Scope: %s\n' "$scope"
}
