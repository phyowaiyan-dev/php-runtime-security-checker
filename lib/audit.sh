# shellcheck shell=bash
audit() {
    local i p v kind cve
    results=()
    for ((i=0;i<${#runtimes[@]};i++)); do
        IFS='|' read -r p v kind <<< "${runtimes[i]}"
        for cve in CVE-2026-109618 CVE-2026-109619; do
            assess "$p" "$v" "${origins[i]}" "$cve"
            results+=("$p|$cve|$assessment")
            case $assessment in FAIL) fail;; UNKNOWN) unknown "$p: advisory/backport mapping unverified ($cve).";; esac
        done
    done
    remaining_updates
    inspect_services
}
