# shellcheck shell=bash
assess() {
    local package=$1 version=$2 origin=$3 cve=$4 branch id b fixed release vendor date upstream
    branch=${package#libapache2-mod-php}; branch=${branch#php}; branch=${branch%%-*}
    assessment=UNKNOWN
    while IFS=$'\t' read -r id b fixed release vendor date; do
        [[ $id == "$cve" && $b == "$branch" ]] || continue
        if [[ $origin == Ubuntu && $os_version == "$release" && $version == *ubuntu* ]]; then
            # Same source revision series only. A foreign epoch or source base is not a verified mapping.
            if [[ ${version%-*} == "${vendor%-*}" && $version != *:* ]]; then
                if dpkg --compare-versions "$version" ge "$vendor"; then assessment=PASS; else assessment=FAIL; fi
            fi
        elif [[ $origin == Ondrej-PPA && $fixed != '-' ]]; then
            upstream=${version#*:}; upstream=${upstream%%-*}
            if [[ $upstream =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                if dpkg --compare-versions "$upstream" ge "$fixed"; then assessment=PASS; else assessment=UNKNOWN; fi
                # Older distribution builds may contain unknown backports: never infer vulnerability.
            fi
        fi
        return
    done < "$BASE/data/advisories.tsv"
}
