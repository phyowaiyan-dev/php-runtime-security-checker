# shellcheck shell=bash
audit() {
    [[ -r $BASE/data/advisories.tsv ]] || { error 'Advisory data unavailable.'; return; }
    local i p v kind cve
    results=()
    for ((i=0;i<${#runtimes[@]};i++)); do
        IFS='|' read -r p v kind <<< "${runtimes[i]}"
        for cve in CVE-2026-109618 CVE-2026-109619; do
            assess "$p" "$v" "${origins[i]}" "$cve"
            results+=("$p|$cve|$assessment")
            case $assessment in FAIL) fail;; UNKNOWN) unknown "$p: $assessment_reason";; esac
        done
    done
}

advisory_status() {
    local wanted=$1 entry package cve status found=0
    advisory_result=PASS
    for entry in "${results[@]}"; do
        IFS='|' read -r package cve status <<< "$entry"
        [[ $cve == "$wanted" ]] || continue
        found=1
        case $status in FAIL) advisory_result=FAIL; return;; UNKNOWN) advisory_result=UNKNOWN;; esac
    done
    ((found)) || advisory_result=UNKNOWN
    return 0
}
