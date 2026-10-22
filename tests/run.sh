#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export BASE
# shellcheck source=../lib/common.sh
source "$BASE/lib/common.sh"
for module in detect advisories audit update handlers services report; do
    # shellcheck source=/dev/null
    source "$BASE/lib/$module.sh"
done
count=0
ok() { count=$((count+1)); printf 'ok %d - %s\n' "$count" "$1"; }
assert() { "$@" || { printf 'FAIL: %s\n' "$*" >&2; exit 1; }; }
# Pure Debian version comparison mock for these fixtures; actual dpkg is used on Linux.
if ! command -v dpkg >/dev/null; then
    dpkg() {
        if [[ $1 == --print-architecture ]]; then printf "amd64\n"; return; fi
        [[ $1 == --compare-versions ]] || return 1
        local greatest
        greatest=$(printf '%s\n%s\n' "$2" "$4" | sort -V | tail -1)
        [[ $greatest == "$2" ]]
    }
fi
os_version=24.04
assess php8.3-cli 8.3.6-0ubuntu0.24.04.13 Ubuntu CVE-2026-109618
assert test "$assessment" = PASS; ok 'Ubuntu backport'
assess php8.3-fpm 8.3.6-0ubuntu0.24.04.12 Ubuntu CVE-2026-109619
assert test "$assessment" = FAIL; ok 'known vulnerable Ubuntu revision'
for entry in '8.3 8.3.36' '8.4 8.4.27' '8.2 8.2.35' '8.5 8.5.12'; do
    read -r b v <<< "$entry"
    assess "php$b-cli" "1:$v-1+deb.sury.org+1" Ondrej-PPA CVE-2026-109618
    assert test "$assessment" = PASS; ok "PPA $b with epoch"
done
assess php8.3-cli 8.3.35-1+deb.sury.org+1 Ondrej-PPA CVE-2026-109618
assert test "$assessment" = UNKNOWN; ok 'unknown PPA backport is not labeled vulnerable'
assess php8.1-cli 8.1.34 unknown CVE-2026-109618
assert test "$assessment" = UNKNOWN; ok 'EOL custom runtime'
assess php8.3-cli 9:8.3.6-0ubuntu0.24.04.13 Ubuntu CVE-2026-109618
assert test "$assessment" = UNKNOWN; ok 'foreign epoch fails closed'
assess php8.4-cli 8.4.27 unknown CVE-2026-109618
assert test "$assessment" = UNKNOWN; ok 'unknown origin cannot pass'
# Invoked through sourced service functions.
# shellcheck disable=SC2329
systemctl() { [[ ${MOCK_INACTIVE:-0} == 0 ]]; }
# Probe stubs isolate summary behavior; detailed evidence tests run in services.sh.
# shellcheck disable=SC2329
inspect_web_handlers() { return 0; }
# shellcheck disable=SC2329
verify_freshness() { freshness_reason='restart freshness unverified: fixture'; [[ ${MOCK_FRESH:-0} == 1 ]]; }
services=(php8.3-fpm apache2); overall=PASS; MOCK_FRESH=0
inspect_services
assert test "$overall" = UNKNOWN; ok 'mixed serving runtimes require restart evidence'
MOCK_FRESH=1; overall=PASS; service_status=PASS
inspect_services
assert test "$overall" = PASS; ok 'verified restart state'
MOCK_INACTIVE=1; overall=PASS
inspect_services
assert test "$overall" = UNKNOWN; ok 'inactive service'
unset MOCK_INACTIVE
apache2ctl() { return 1; }
operation_error=0
restart_services
assert test "$operation_error" = 1; ok 'Apache configuration failure blocks restart'
services=(php8.3-fpm)
# shellcheck disable=SC2329
systemctl() { [[ $1 != restart ]]; }
operation_error=0
restart_services
assert test "$operation_error" = 1; ok 'restart failure'
# Remediation must reject unsafe plans before any real mutation/root check.
apt_get_calls=0
apt-get() { printf '%s\n' "$PLAN"; }
mode=fix; supported=1; packages=(php8.3-cli); holds=''; yes=1
for PLAN in 'Remv php8.3-cli [8.3.6]' 'Inst unrelated [1] (2)' 'Inst php8.4-cli (8.4.27)' 'Inst php8.3-cli (8.3.36)'; do
    operation_error=0
    modify
    assert test "$operation_error" = 1
done
ok 'APT removal, unrelated package, branch switch and new install rejected'
holds=php8.3-cli; operation_error=0
modify
assert test "$operation_error" = 1; ok 'held package rejected'
# Exercise entry point and parse its real JSON with Ruby (test dependency only).
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
set +e
bash "$BASE/bin/php-security-check" --json > "$TMP/report.json"
status=$?
set -e
assert test "$status" -ge 0; assert test "$status" -le 3
if command -v ruby >/dev/null; then
    ruby -rjson -e 'r=JSON.parse(File.read(ARGV[0])); abort unless %w[PASS FAIL UNKNOWN ERROR].include?(r["overall"]); abort unless r["limitations"].is_a?(Array)' "$TMP/report.json"
fi
ok 'real entry point JSON'
for args in --invalid '--check --fix' '--yes' '--output'; do
    set +e
    # Intentional word splitting: fixed option fixtures.
    # shellcheck disable=SC2086
    bash "$BASE/bin/php-security-check" $args >/dev/null 2>&1
    status=$?
    set -e
    assert test "$status" = 3
done
ok 'invalid arguments'
json_string $'quote" slash\\ tab\t newline\n\001' > "$TMP/string.json"
if command -v ruby >/dev/null; then ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' "$TMP/string.json"; fi
ok 'JSON escaping control characters'
# Successful and failed fix orchestration: every privileged entry point is replaced.
# shellcheck disable=SC2329
is_root() { return 0; }
# shellcheck disable=SC2329
install_packages() { [[ ${MOCK_APT_FAIL:-0} == 0 ]]; }
# shellcheck disable=SC2329
restart_services() { restarted=1; }
# shellcheck disable=SC2329
detect() { runtimes=('php8.3-cli|8.3.6-0ubuntu0.24.04.13|CLI'); origins=(Ubuntu); activities=(installed); packages=(); services=(); }
holds=''; PLAN='Inst php8.3-cli [8.3.6-0ubuntu0.24.04.12] (8.3.6-0ubuntu0.24.04.13 Ubuntu:24.04 [amd64])'
warnings+=('superseded restart warning'); packages=(php8.3-cli); operation_error=0; overall=FAIL; os_version=24.04
modify
assert test "$operation_error" = 0
assert test "$overall" = PASS
assert test "${warnings[*]}" = "${warnings[*]//superseded restart warning/}"
ok 'mocked fix re-audits patched packages and clears superseded warnings'
packages=(php8.3-cli); operation_error=0; MOCK_APT_FAIL=1
modify
assert test "$operation_error" = 1
ok 'mocked upgrade failure fails closed'
unset MOCK_APT_FAIL
# Restore real read-only functions for detection tests.
# shellcheck source=../lib/detect.sh
source "$BASE/lib/detect.sh"
# Full detection fixtures: no system mutations, no config content emitted.
read_os() { os_id=ubuntu; os_version=24.04; os_name='Ubuntu 24.04 LTS'; }
# shellcheck disable=SC2329
dpkg-query() {
    if [[ $1 == -W ]]; then printf '%s\n' "$INVENTORY"; else return 1; fi
}
# shellcheck disable=SC2329
apt-mark() { return 0; }
# shellcheck disable=SC2329
apt-cache() {
    printf '%s\n' "$2:" '  Installed: 8.3.6-0ubuntu0.24.04.13' '  Candidate: 8.3.6-0ubuntu0.24.04.13' \
        '  Version table:' ' *** 8.3.6-0ubuntu0.24.04.13 500' \
        '        500 http://security.ubuntu.com/ubuntu noble-security/main amd64 Packages' \
        '        100 /var/lib/dpkg/status'
}
# shellcheck disable=SC2329
systemctl() { return 1; }
INVENTORY=$'php8.3-cli\t8.3.6-0ubuntu0.24.04.13\tinstalled\nphp8.3-fpm\t8.3.6-0ubuntu0.24.04.13\tinstalled\nlibapache2-mod-php8.3\t8.3.6-0ubuntu0.24.04.13\tinstalled'
runtimes=(); services=(); packages=(); origins=(); activities=(); overall=PASS
operation_error=0; detect; audit
assert test "${#runtimes[@]}" = 3
assert test "${origins[0]}" = Ubuntu
assert test "${activities[1]}" = inactive
assert test "$overall" = UNKNOWN
ok 'full mixed CLI/FPM/mod_php detection and origin fixture'
# A trusted archive for a different version must not authenticate the installed one.
# shellcheck disable=SC2329
apt-cache() {
    printf '%s\n' '  Version table:' ' *** 8.3.6-0ubuntu0.24.04.13 100' \
        '        100 /var/lib/dpkg/status' '     8.3.6-0ubuntu0.24.04.12 500' \
        '        500 http://security.ubuntu.com/ubuntu noble-security/main amd64 Packages'
}
runtimes=(); services=(); packages=(); origins=(); activities=(); overall=PASS
detect
assert test "${origins[0]}" = unknown
ok 'installed origin does not inherit a different version archive'
INVENTORY=''; runtimes=(); origins=(); activities=(); services=(); packages=(); overall=PASS
detect; audit
assert test "${#runtimes[@]}" = 0
assert test "$overall" = UNKNOWN
ok 'no PHP cannot produce false green'
# Check final CLI exit/report agreement and no-clobber semantics.
for format in --json --check; do
    set +e
    bash "$BASE/bin/php-security-check" "$format" --output "$TMP/output-${format#--}" >/dev/null
    status=$?
    set -e
    if [[ $format == --json ]] && command -v ruby >/dev/null; then
        ruby -rjson -e 'r=JSON.parse(File.read(ARGV[0])); expected={"PASS"=>0,"FAIL"=>1,"UNKNOWN"=>2,"ERROR"=>3}; abort unless expected[r["overall"]]==ARGV[1].to_i' "$TMP/output-json" "$status"
    fi
    set +e
    bash "$BASE/bin/php-security-check" "$format" --output "$TMP/output-${format#--}" >/dev/null 2>&1
    status=$?
    set -e
    assert test "$status" = 3
done
ok 'CLI exit status matches JSON and existing output is preserved'
: > "$TMP/reboot-required"
detect_reboot "$TMP/reboot-required"
assert test "$reboot" = REQUIRED
detect_reboot "$TMP/absent"
assert test "$reboot" = NO
ok 'reboot-required state is separate'
printf '%d base checks passed\n' "$count"
bash "$BASE/tests/services.sh"
bash "$BASE/tests/evidence.sh"
