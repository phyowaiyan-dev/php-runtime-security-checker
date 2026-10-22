#!/usr/bin/env bash
# Private root transaction used by the guided CLI after consent. No user-facing mode.
set -euo pipefail
export LC_ALL=C
((EUID==0)) || exit 70
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=common.sh
source "$BASE/lib/common.sh"
# shellcheck source=detect.sh
source "$BASE/lib/detect.sh"
read_os
[[ $os_id == ubuntu ]] || exit 70
# shellcheck source=update.sh
source "$BASE/lib/update.sh"
(($#)) || exit 70
pins=("$@"); scope_rows=()
pending=$(dpkg --audit)
[[ -z $pending ]] || exit 70
for pin in "${pins[@]}"; do
    [[ $pin =~ ^(php[0-9]+\.[0-9]+(-[a-z0-9-]+)?|libapache2-mod-php[0-9]+\.[0-9]+)=([0-9][A-Za-z0-9.+:~_-]*)$ ]] || exit 70
    package=${pin%%=*}; candidate=${pin#*=}
    evidence=$(dpkg-query -W '-f=${db:Status-Status}\t${Version}\t${source:Package}' "$package")
    IFS=$'\t' read -r state installed source <<< "$evidence"
    package_branch "$package"
    [[ $state == installed && $source == "php$branch" && ${candidate#*:} == "$branch."* ]] || exit 70
    release_matches_host "$candidate" || exit 70
    dpkg --compare-versions "$candidate" gt "$installed" || exit 70
    scope_rows+=("$package|$installed|verified")
done
holds=$(apt-mark showhold)
check_holds "$holds" || exit 70
simulate_plan || exit 70
[[ ! -e /usr/sbin/policy-rc.d && ! -L /usr/sbin/policy-rc.d ]] || exit 70
# Ordinary maintainer scripts must defer service restarts until configuration validation.
# Existing administrator policy is never replaced. A SIGKILL/power loss needs manual cleanup.
(umask 022; set -o noclobber; printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d) || exit 70
trap 'rm -f -- /usr/sbin/policy-rc.d' EXIT
trap 'exit 70' HUP INT TERM
chmod 755 /usr/sbin/policy-rc.d
DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l apt-get --no-remove --only-upgrade \
    --no-install-recommends -y -o APT::Get::AutomaticRemove=false -o APT::Get::AllowUnauthenticated=false \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
    install "${pins[@]}"
# A successful transaction must not silently leave the temporary policy behind.
rm -f -- /usr/sbin/policy-rc.d
trap - EXIT HUP INT TERM
