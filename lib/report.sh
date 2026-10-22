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
        printf ',"activity":'; json_string "${activities[i]}"; printf '}'; sep=,
    done
printf '],"cves":['; sep=''
    for entry in "${results[@]}"; do
        IFS='|' read -r p cve status <<< "$entry"
        printf '%s{"package":' "$sep"; json_string "$p"
        printf ',"id":'; json_string "$cve"; printf ',"status":'; json_string "$status"
        printf '}'; sep=,
    done
    printf ']'
    printf ',"services":{"names":'; json_array "${services[@]}"; printf ',"status":'; json_string "$service_status"; printf '}'
    printf ',"reboot":'; json_string "$reboot"; printf ',"overall":'; json_string "$overall"
    printf ',"warnings":'; json_array "${warnings[@]}"; printf ',"limitations":'; json_array "${limitations[@]}"; printf '}\n'
}
report_human() {
    local r
    printf 'PHP Runtime Security Checker v%s\nOS: %s\nArchitecture: %s\n' "$VERSION" "$os_name" "$arch"
    for r in "${runtimes[@]}"; do printf 'Runtime: %s\n' "$r"; done
    for r in "${results[@]}"; do printf 'Advisory: %s\n' "$r"; done
    printf 'Services: %s\nReboot: %s\nOverall: %s\n' "$service_status" "$reboot" "$overall"
    for r in "${warnings[@]}"; do printf 'WARNING: %s\n' "$r"; done
    for r in "${limitations[@]}"; do printf 'Limitation: %s\n' "$r"; done
}
