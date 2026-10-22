#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$BASE/lib/common.sh"
for module in detect advisories audit report; do
    # shellcheck source=/dev/null
    source "$BASE/lib/$module.sh"
done
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
count=0
assert() { "$@" || { printf 'FAIL: %s\n' "$*" >&2; exit 1; }; }
ok() { count=$((count+1)); printf 'ok %d - %s\n' "$count" "$1"; }
# Real Debian comparisons on Linux; limited fixture comparator on macOS.
if ! command -v dpkg >/dev/null; then
    dpkg() {
        if [[ $1 == --print-architecture ]]; then printf 'amd64\n'; return; fi
        [[ $1 == --compare-versions ]] || return 1
        [[ $(printf '%s\n%s\n' "$2" "$4" | sort -V | tail -1) == "$2" ]]
    }
fi
os_version=24.04
for cve in CVE-2026-109618 CVE-2026-109619; do
    assess php8.3-fpm 8.3.6-0ubuntu0.24.04.13 Ubuntu "$cve"
    assert test "$assessment" = PASS
    assess php8.3-fpm 8.3.6-0ubuntu0.24.04.12 Ubuntu "$cve"
    assert test "$assessment" = FAIL
done
ok 'verified Ubuntu backports and vulnerable revisions'
for entry in '8.2 8.2.35' '8.3 8.3.36' '8.4 8.4.27' '8.5 8.5.12'; do
    read -r branch version <<< "$entry"
    assess "php$branch-cli" "1:$version-1+deb.sury.org+1" Ondrej-PPA CVE-2026-109618
    assert test "$assessment" = PASS
done
ok 'supported upstream baselines and PPA epochs'
assess php8.4-fpm 8.4.26-1+deb.sury.org+1 Ondrej-PPA CVE-2026-109618
assert test "$assessment" = UNKNOWN
assess php8.4-fpm 8.4.27 unknown CVE-2026-109618
assert test "$assessment" = UNKNOWN
assess php8.1-cli 8.1.34 unknown CVE-2026-109618
assert test "$assessment" = UNKNOWN
ok 'unknown origins, backports and unsupported versions cannot pass'
assess php8.3-cli 9:8.3.6-0ubuntu0.24.04.13 Ubuntu CVE-2026-109618
assert test "$assessment" = UNKNOWN
ok 'foreign vendor epoch cannot pass a mapping'
# Read-only detection fixtures. Any old service/remediation probe fails this suite.
read_os() { os_id=ubuntu; os_version=24.04; os_name='Ubuntu 24.04.5 LTS'; }
# shellcheck disable=SC2329
dpkg-query() { [[ $1 == -W ]] || return 1; printf '%s\n' "$INVENTORY"; }
# shellcheck disable=SC2329
apt-cache() {
    printf '%s\n' ' Version table:' " *** $FIXTURE_VERSION 500" "   500 $FIXTURE_REPO noble/main amd64 Packages" '   100 /var/lib/dpkg/status'
}
# shellcheck disable=SC2329
systemctl() { : > "$TMP/forbidden"; return 1; }
# shellcheck disable=SC2329
apt-get() { : > "$TMP/forbidden"; return 1; }
# shellcheck disable=SC2329
apache2ctl() { : > "$TMP/forbidden"; return 1; }
reset() { warnings=(); runtimes=(); results=(); origins=(); overall=PASS; operation_error=0; }
FIXTURE_VERSION=8.4.27-1+ubuntu24.04.1+deb.sury.org+1
FIXTURE_REPO=https://ppa.launchpadcontent.net/ondrej/php/ubuntu
INVENTORY=$'php8.4-cli\t'"$FIXTURE_VERSION"$'\tinstalled\nphp8.4-fpm\t'"$FIXTURE_VERSION"$'\tinstalled'
reset; detect; audit
assert test "$overall" = PASS
assert test "${#warnings[@]}" = 0
assert test "${#runtimes[@]}" = 2
assert test ! -e "$TMP/forbidden"
report_human > "$TMP/patched.txt"
report_json > "$TMP/patched.json"
assert test "$(awk '/^CVE-/ {n++} END {print n}' "$TMP/patched.txt")" = 2
if rg 'WARNING|Services:|handler|freshness' "$TMP/patched.txt"; then exit 1; fi
ok 'reported Laravel-host PHP 8.4.27 fixture passes with a compact warning-free report'
FIXTURE_REPO=https://unverified.example/ubuntu
reset; detect; audit
assert test "$overall" = UNKNOWN
assert test "${#warnings[@]}" = 2
warn "${warnings[0]}"
assert test "${#warnings[@]}" = 2
ok 'unknown mapping notes are deduplicated per package, not repeated per CVE'
# An archive for another version must not authenticate the installed version.
# shellcheck disable=SC2329
apt-cache() {
    printf '%s\n' " *** $FIXTURE_VERSION 100" '  100 /var/lib/dpkg/status' ' 8.4.26-1 500' \
        '  500 https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble/main amd64 Packages'
}
reset; detect; audit
assert test "${origins[0]}" = unknown
assert test "$overall" = UNKNOWN
ok 'provenance stays within the installed version block'
INVENTORY=''; reset; detect; audit
assert test "$overall" = UNKNOWN
advisory_status CVE-2026-109618
assert test "$advisory_result" = UNKNOWN
ok 'no packaged PHP is UNKNOWN'
reset
runtimes=('php8.3-cli|8.3.6-0ubuntu0.24.04.12|CLI' 'php8.4-fpm|8.4.27|FPM'); origins=(Ubuntu unknown)
audit
advisory_status CVE-2026-109618
assert test "$overall" = FAIL
assert test "$advisory_result" = FAIL
ok 'known vulnerable package takes precedence over unknown package'
if command -v ruby >/dev/null; then
    ruby -rjson -e 'r=JSON.parse(File.read(ARGV[0])); abort unless r["overall"]=="PASS" && r["warnings"].empty? && r["cves"].length==4; abort if r.key?("services"); abort unless r["scope"].include?("not checked")' "$TMP/patched.json"
fi
ok 'JSON preserves per-package evidence and explicit package-only scope'
json_string $'quote" slash\\ tab\t newline\n\001' > "$TMP/escape.json"
if command -v ruby >/dev/null; then ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' "$TMP/escape.json"; fi
ok 'JSON escaping'
for option in --fix --restart --yes --invalid --output; do
    set +e
    bash "$BASE/bin/php-security-check" "$option" > /dev/null 2>&1
    status=$?
    set -e
    assert test "$status" = 3
done
ok 'modification and invalid options are rejected'
set +e
bash "$BASE/bin/php-security-check" --json --output "$TMP/cli.json"
status=$?
set -e
if command -v ruby >/dev/null; then
    ruby -rjson -e 'r=JSON.parse(File.read(ARGV[0])); abort unless {"PASS"=>0,"FAIL"=>1,"UNKNOWN"=>2,"ERROR"=>3}[r["overall"]]==ARGV[1].to_i' "$TMP/cli.json" "$status"
fi
set +e
bash "$BASE/bin/php-security-check" --output "$TMP/cli.json" > /dev/null 2>&1
status=$?
set -e
assert test "$status" = 3
ok 'entry-point JSON/exit agreement and no-clobber output'
printf '%d checks passed\n' "$count"
printf '\nPatched-host fixture report (not a live server audit):\n'
cat "$TMP/patched.txt"
