#!/usr/bin/env bash
# Private, consented repair of one existing dedicated PPA source. No package installation.
set -euo pipefail
export LC_ALL=C
((EUID==0 && $#>=3)) || exit 73
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=common.sh
source "$BASE/lib/common.sh"
# shellcheck source=detect.sh
source "$BASE/lib/detect.sh"
# shellcheck source=repository.sh
source "$BASE/lib/repository.sh"
# shellcheck source=advisories.sh
source "$BASE/lib/advisories.sh"
read_os; ubuntu_suite || exit 73
[[ $os_id == ubuntu ]] || exit 73
file=$1; expected=$2; shift 2
[[ $file =~ ^/etc/apt/sources\.list\.d/[A-Za-z0-9_.-]+\.(list|sources)$ && $expected =~ ^[0-9a-f]{64}$ ]] || exit 73
secure_file() {
    local mode owner info
    [[ ! -L $1 && -e $1 ]] || return 1
    info=$(stat -c '%u %a' -- "$1") || return 1
    read -r owner mode <<< "$info"
    [[ $owner == 0 && $mode =~ ^[0-7]{3,4}$ ]] && (( (8#$mode & 0022)==0 ))
}
secure_file /etc/apt/sources.list.d && secure_file "$file" || exit 73
[[ $(repository_digest "$file") == "$expected" ]] || exit 73
read_ppa_source "$file" || exit 73
secure_file "$(dirname -- "$ppa_key")" && secure_file "$ppa_key" || exit 73
[[ $ppa_suite != "$suite" || $ppa_enabled == no ]] || exit 73
# Ensure no other active/disabled definition was added after the preview.
discover_repository_repair
[[ $repo_file == "$file" && $repo_digest == "$expected" ]] || exit 73
arch=$(dpkg --print-architecture)
[[ $arch == amd64 || $arch == arm64 ]] || exit 73
[[ -z $ppa_arch || ,$ppa_arch, == *,$arch,* ]] || exit 73
command -v gpgv >/dev/null || exit 72
[[ -x /usr/lib/apt/apt-helper ]] || exit 72
work=$(mktemp -d /tmp/php-security-repository.XXXXXXXX)
backup=''; replacement=''; changed=0; committed=0
cleanup() {
    local result=$?
    trap - EXIT HUP INT TERM
    if ((changed && !committed)); then
        if ! rollback_ppa_source "$file"; then result=75; fi
    fi
    [[ -z $replacement ]] || rm -f -- "$replacement"
    rm -rf -- "$work"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 74' HUP INT TERM
# Download before changing APT sources. A missing suite (404) never modifies the host source.
/usr/lib/apt/apt-helper -o Acquire::Retries=0 -o Acquire::https::Timeout=20 download-file \
    "$PPA_URI/dists/$suite/InRelease" "$work/InRelease" >/dev/null 2>&1 || exit 71
verify_ppa_release "$work/InRelease" "$ppa_key" "$suite" "$arch" || exit 72
write_ppa_source "$file" "$suite" "$ppa_key" "$arch" > "$work/ppa.${file##*.}"
mkdir "$work/lists" "$work/lists/partial"
# Isolated lists/cache/source file; do not run host update hooks during preflight.
cat > "$work/preflight.conf" <<'CONFIG'
#clear APT::Update::Pre-Invoke;
#clear APT::Update::Post-Invoke;
#clear APT::Update::Post-Invoke-Success;
CONFIG
options=(-c "$work/preflight.conf" -o "Dir::Etc::sourcelist=$work/ppa.${file##*.}" -o Dir::Etc::sourceparts=-
    -o "Dir::State::lists=$work/lists" -o Dir::Cache::pkgcache= -o Dir::Cache::srcpkgcache=
    -o Acquire::AllowInsecureRepositories=false -o Acquire::AllowDowngradeToInsecureRepositories=false
    -o APT::Get::AllowUnauthenticated=false -o APT::Update::Error-Mode=any)
apt-get "${options[@]}" update >/dev/null 2>&1 || exit 72
for package in "$@"; do
    [[ $package =~ ^(php[0-9]+\.[0-9]+-(cli|fpm)|libapache2-mod-php[0-9]+\.[0-9]+)$ ]] || exit 73
    evidence=$(dpkg-query -W '-f=${db:Status-Status}\t${Version}\t${source:Package}' "$package")
    IFS=$'\t' read -r state installed source <<< "$evidence"
    package_branch "$package"
    [[ $state == installed && $source == "php$branch" ]] || exit 73
    policy=$(apt-cache "${options[@]}" policy "$package")
    candidate=$(awk '$1=="Candidate:" {print $2}' <<< "$policy")
    release_matches_host "$candidate" || exit 72
    policy_origin "$policy" "$candidate"
    [[ $origin == Ondrej-PPA ]] || exit 72
    dpkg --compare-versions "$candidate" ge "$installed" || exit 72
    for cve in CVE-2026-109618 CVE-2026-109619; do
        assess "$package" "$candidate" Ondrej-PPA "$cve"
        [[ $assessment == PASS ]] || exit 72
    done
done
# Only now is the existing source eligible for an atomic replacement.
[[ $(repository_digest "$file") == "$expected" ]] || exit 73
replace_ppa_source "$file" "$suite" "$ppa_key" "$ppa_arch"
apt-get -o APT::Update::Error-Mode=any -o Acquire::AllowInsecureRepositories=false \
    -o Acquire::AllowDowngradeToInsecureRepositories=false update >/dev/null 2>&1 || exit 74
committed=1
