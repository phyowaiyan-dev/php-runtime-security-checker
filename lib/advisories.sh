# shellcheck shell=bash
assess() {
    local package=$1 version=$2 package_origin=$3 cve=$4 branch id b fixed release vendor verified upstream
    branch=${package#libapache2-mod-php}; branch=${branch#php}; branch=${branch%%-*}
    assessment=UNKNOWN
    assessment_reason='No verified fix mapping for this PHP branch; upgrade the branch manually or await a documented vendor patch.'
    while IFS=$'\t' read -r id b fixed release vendor verified; do
        [[ $id == "$cve" && $b == "$branch" ]] || continue
        assessment_reason='Package origin/backport is unverified; no vulnerability or fix is inferred from its version alone.'
        if [[ $package_origin == Ubuntu && $os_version == "$release" && $version == *ubuntu* ]]; then
            if [[ ${version%-*} == "${vendor%-*}" && $version != *:* ]]; then
                if dpkg --compare-versions "$version" ge "$vendor"; then assessment=PASS; else assessment=FAIL; fi
            fi
        elif [[ $package_origin == Ondrej-PPA && $fixed != '-' ]]; then
            upstream=${version#*:}; upstream=${upstream%%-*}
            if [[ $upstream =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && ${upstream%.*} == "$branch" ]]; then
                if dpkg --compare-versions "$upstream" ge "$fixed"; then assessment=PASS
                else assessment_reason='Below the upstream fix; vendor backport is unverified. A verified newer candidate can be offered.'
                fi
            fi
        elif [[ $fixed == '-' ]]; then
            assessment_reason='Upstream-EOL PHP branch without a verified vendor fix here; migrate PHP manually.'
        fi
        return
    done < "$BASE/data/advisories.tsv"
}
