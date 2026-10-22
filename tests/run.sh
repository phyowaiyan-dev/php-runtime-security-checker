#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$BASE/lib/common.sh"
for module in detect advisories audit report services repository update; do
    # shellcheck source=/dev/null
    source "$BASE/lib/$module.sh"
done
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
count=0
assert() { "$@" || { printf 'FAIL: %s\n' "$*" >&2; exit 1; }; }
ok() { count=$((count+1)); printf 'ok %d - %s\n' "$count" "$1"; }
REAL_DPKG=$(command -v dpkg || true)
# shellcheck disable=SC2329
dpkg() {
    case $1 in
        --print-architecture) printf 'amd64\n';;
        --audit) printf '%s' "${MOCK_PENDING:-}";;
        --compare-versions)
            if [[ -n $REAL_DPKG ]]; then "$REAL_DPKG" "$@"
            else
                # Fixture fallback on macOS; Linux CI uses real Debian semantics.
                local greatest
                greatest=$(printf '%s\n%s\n' "$2" "$4" | sort -V | tail -1)
                [[ $greatest == "$2" ]] && { [[ $3 == ge ]] || [[ $3 == gt && $2 != "$4" ]]; }
            fi;;
        *) return 1;;
    esac
}
# shellcheck disable=SC2329
read_os() { os_id=${MOCK_OS:-ubuntu}; os_version=${MOCK_RELEASE:-24.04}; os_name="Ubuntu $os_version LTS"; }
# shellcheck disable=SC2329
dpkg-query() {
    [[ $1 == -W ]] || return 1
    [[ ${MOCK_QUERY_FAIL:-0} == 0 ]] || return 1
    [[ ${MOCK_EMPTY:-0} == 0 ]] || return 0
    local installed
    installed=$(cat "$TMP/version")
    printf 'php%s-cli\t%s\tinstalled\tphp%s\n' "$MOCK_BRANCH" "$installed" "$MOCK_BRANCH"
    printf 'php%s-fpm\t%s\tinstalled\tphp%s\n' "$MOCK_BRANCH" "$installed" "$MOCK_BRANCH"
    printf 'php%s-common\t%s\tinstalled\tphp%s\n' "$MOCK_BRANCH" "$installed" "$MOCK_BRANCH"
    if [[ $MOCK_MODPHP == 1 ]]; then printf 'libapache2-mod-php%s\t%s\tinstalled\tphp%s\n' "$MOCK_BRANCH" "$installed" "$MOCK_BRANCH"; fi
    if [[ $MOCK_MIXED == 1 ]]; then
        printf 'php8.3-cli\t8.3.35-1+ubuntu24.04.1+deb.sury.org+1\tinstalled\tphp8.3\n'
        printf 'php8.3-common\t8.3.35-1+ubuntu24.04.1+deb.sury.org+1\tinstalled\tphp8.3\n'
        printf 'php8.5-cli\t8.5.4-0ubuntu1.5\tinstalled\tphp8.5\n'
        printf 'libapache2-mod-php8.5\t8.5.4-0ubuntu1.5\tinstalled\tphp8.5\n'
    fi
    # A third-party extension must not enter the core PHP repair scope.
    printf 'php%s-redis\t6.0.0\tinstalled\tphp-redis\n' "$MOCK_BRANCH"
}
# shellcheck disable=SC2329
apt-cache() {
    local installed
    installed=$(cat "$TMP/version")
    if [[ $MOCK_MIXED == 1 ]]; then
        case $2 in
            *8.5*) printf ' Installed: 8.5.4-0ubuntu1.5\n Candidate: 8.5.4-0ubuntu1.5\n *** 8.5.4-0ubuntu1.5 500\n  500 http://security.ubuntu.com/ubuntu resolute-security/main amd64 Packages\n'; return;;
            *8.3*) installed=8.3.35-1+ubuntu24.04.1+deb.sury.org+1;;
        esac
        printf ' Installed: %s\n Candidate: %s\n *** %s 100\n  100 /var/lib/dpkg/status\n' "$installed" "$installed" "$installed"
        return
    fi
    printf ' Installed: %s\n Candidate: %s\n Version table:\n' "$installed" "$MOCK_CANDIDATE"
    if [[ $installed != "$MOCK_CANDIDATE" && $MOCK_CANDIDATE != '(none)' ]]; then
        printf '  %s 500\n    500 %s noble/main amd64 Packages\n' "$MOCK_CANDIDATE" "${MOCK_NEW_REPO:-$MOCK_REPO}"
    fi
    printf ' *** %s 100\n' "$installed"
    if [[ $MOCK_OLD_ORIGIN == 1 || $installed == "$MOCK_CANDIDATE" ]]; then
        printf '    500 %s noble/main amd64 Packages\n' "$MOCK_REPO"
    fi
    printf '    100 /var/lib/dpkg/status\n'
}
# shellcheck disable=SC2329
apt-mark() { printf '%s' "$MOCK_HOLD"; }
# shellcheck disable=SC2329
apt-get() {
    [[ $1 == -s ]] || { printf 'FORBIDDEN direct APT call\n' >> "$TMP/calls"; return 1; }
    local arg p old
    old=$(cat "$TMP/version")
    for arg in "$@"; do
        [[ $arg == php*'='* || $arg == libapache2-mod-php*'='* ]] || continue
        p=${arg%%=*}
        printf 'Inst %s [%s] (%s mock [amd64])\nConf %s (%s mock [amd64])\n' "$p" "$old" "${arg#*=}" "$p" "${arg#*=}"
    done
    printf '%s\n' "$MOCK_UNSAFE"
}
# shellcheck disable=SC2329
systemctl() {
    local service=${2:-} generation
    case $1 in
        is-active) [[ $MOCK_ACTIVE == 1 ]];;
        show)
            if [[ $* == *--property=ActiveState* ]]; then
                printf '%s\n' "${MOCK_STATE:-active}"
            elif [[ $* == *LoadState* ]]; then
                printf 'LoadState=loaded\nActiveState=%s\n' "${MOCK_STATE:-active}"
            else
                generation=$(cat "$TMP/generation")
                printf 'MainPID=%s\nExecMainStartTimestampMonotonic=%s\n' "$((100+generation))" "$((1000000+generation*1000000))"
            fi;;
        *) printf 'FORBIDDEN direct service mutation: %s\n' "$service" >> "$TMP/calls"; return 1;;
    esac
}
# Every privileged entry point is mocked. Never execute the root transaction in development.
# shellcheck disable=SC2329
authorize_root() { printf 'authorize\n' >> "$TMP/calls"; [[ $MOCK_AUTH_FAIL == 0 ]]; }
# shellcheck disable=SC2329
run_root() {
    local generation
    printf '%s\n' "$*" >> "$TMP/calls"
    case $1 in
        apt-get) [[ $MOCK_STATE_CHANGE == 0 ]] || MOCK_STATE=inactive; [[ $MOCK_REFRESH_FAIL == 0 ]];;
        bash)
            if [[ $2 == "$BASE/lib/repository-transaction.sh" ]]; then return "$MOCK_REPO_CODE"; fi
            if [[ $MOCK_PARTIAL == 1 || $MOCK_INSTALL_FAIL == 0 ]]; then printf '%s\n' "$MOCK_CANDIDATE" > "$TMP/version"; fi
            [[ $MOCK_INSTALL_FAIL == 0 ]];;
        /usr/sbin/php-fpm*|apache2ctl) [[ $MOCK_CONFIG_FAIL == 0 ]];;
        systemctl)
            [[ $MOCK_RESTART_FAIL == 0 ]] || return 1
            generation=$(cat "$TMP/generation")
            [[ $MOCK_SAME_PID == 1 ]] || printf '%s\n' "$((generation+1))" > "$TMP/generation";;
        *) return 1;;
    esac
}
# shellcheck disable=SC2329
is_interactive() { [[ $MOCK_TTY == 1 ]]; }
# shellcheck disable=SC2329
repository_source_files() { [[ -z $MOCK_SOURCE ]] || printf '%s\n' "$MOCK_SOURCE"; return 0; }
# shellcheck disable=SC2329
repository_digest() {
    if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'
}
# shellcheck disable=SC2329
transaction_policy_available() { [[ $MOCK_POLICY == 0 ]]; }
reset() {
    MOCK_SOURCE=''; MOCK_REPO_CODE=0; MOCK_RELEASE=24.04; MOCK_MIXED=0; MOCK_MODPHP=0; MOCK_BRANCH=8.4; MOCK_CANDIDATE=8.4.27-1+ubuntu24.04.1+deb.sury.org+1
    MOCK_REPO=https://ppa.launchpadcontent.net/ondrej/php/ubuntu
    MOCK_STATE_CHANGE=0; MOCK_NEW_REPO=''; MOCK_OLD_ORIGIN=1; MOCK_HOLD=''; MOCK_UNSAFE=''; MOCK_ACTIVE=1; MOCK_STATE=active
    MOCK_AUTH_FAIL=0; MOCK_REFRESH_FAIL=0; MOCK_INSTALL_FAIL=0; MOCK_PARTIAL=0
    MOCK_CONFIG_FAIL=0; MOCK_RESTART_FAIL=0; MOCK_SAME_PID=0; MOCK_TTY=1; MOCK_POLICY=0
    MOCK_OS=ubuntu; MOCK_PENDING=''; MOCK_EMPTY=0; MOCK_QUERY_FAIL=0
    printf '8.4.26-1+ubuntu24.04.1+deb.sury.org+1\n' > "$TMP/version"
    printf '0\n' > "$TMP/generation"; : > "$TMP/calls"
    printf '1\n' > "$TMP/answer"
    mode=guided; no_color=1; workflow_note=''; restart_note=''; action_error=0
    ui_init
}
reset
os_version=24.04
for cve in CVE-2026-109618 CVE-2026-109619; do
    assess php8.3-fpm 8.3.6-0ubuntu0.24.04.13 Ubuntu "$cve"; assert test "$assessment" = PASS
    assess php8.3-fpm 8.3.6-0ubuntu0.24.04.12 Ubuntu "$cve"; assert test "$assessment" = FAIL
done
ok 'verified Ubuntu backports and vulnerable revisions'
for entry in '8.2 8.2.35' '8.3 8.3.36' '8.4 8.4.27' '8.5 8.5.12'; do
    read -r branch version <<< "$entry"
    assess "php$branch-cli" "1:$version-1+deb.sury.org+1" Ondrej-PPA CVE-2026-109618
    assert test "$assessment" = PASS
done
assess php8.4-cli 8.5.12-1+deb.sury.org+1 Ondrej-PPA CVE-2026-109618
assert test "$assessment" = UNKNOWN
ok 'upstream baselines, epochs and branch mismatch guard'
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
assert test "$(awk '/Choice \[0\]/ {n++} END {print n+0}' "$TMP/output")" = 1
assert test "$(awk '/^authorize$/ {n++} END {print n+0}' "$TMP/calls")" = 1
assert test "$(awk '/systemctl restart/ {n++} END {print n+0}' "$TMP/calls")" = 1
if grep -q 'redis\|FORBIDDEN' "$TMP/calls"; then exit 1; fi
ok 'one confirmation refreshes, patches only core PHP, restarts and re-audits'
reset; MOCK_MODPHP=1
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
assert test "$(awk '/systemctl restart/ {n++} END {print n+0}' "$TMP/calls")" = 2
ok 'mixed FPM/mod_php validates and restarts both managed services'
reset; MOCK_BRANCH=8.3; MOCK_CANDIDATE=8.3.6-0ubuntu0.24.04.13
MOCK_REPO=http://security.ubuntu.com/ubuntu
printf '8.3.6-0ubuntu0.24.04.12\n' > "$TMP/version"
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
ok 'verified Ubuntu vendor-backported repair works below upstream fixed version'
reset; MOCK_CANDIDATE=8.4.26-2+ubuntu24.04.1+deb.sury.org+1
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = UNKNOWN
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'a newer candidate below the verified baseline is not called a fix'
reset; printf '%s\n' "$MOCK_CANDIDATE" > "$TMP/version"
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS; assert test ! -s "$TMP/calls"
ok 'already patched systems need no root, refresh or restart'
for answer in 0 no ''; do
    reset; printf '%s\n' "$answer" > "$TMP/answer"
    workflow < "$TMP/answer" > "$TMP/output"
    assert test "$overall" = UNKNOWN; assert test ! -s "$TMP/calls"
done
reset; : > "$TMP/answer"
workflow < "$TMP/answer" > "$TMP/output"
assert test ! -s "$TMP/calls"
ok '0, no, blank and EOF decline without changes'
reset; printf 'bad\n1\n' > "$TMP/answer"
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
ok 'invalid menu input can be corrected to 1'
reset; MOCK_TTY=0
workflow < "$TMP/answer" > "$TMP/output"
assert test ! -s "$TMP/calls"
ok 'piped/noninteractive input cannot authorize mutation'
reset; mode=check
workflow > "$TMP/output"
assert test ! -s "$TMP/calls"
ok '--check remains read-only'
reset; MOCK_BRANCH=7.4; MOCK_CANDIDATE=7.4.99-1+deb.sury.org+1
printf '7.4.33-1+deb.sury.org+1\n' > "$TMP/version"
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = UNKNOWN; assert test ! -s "$TMP/calls"
ok 'unsupported/EOL branch without verified backport requires manual migration'
reset; MOCK_OS=debian
workflow < "$TMP/answer" > "$TMP/output"
assert test ! -s "$TMP/calls"
ok 'unsupported platform never triggers repair'
reset; MOCK_CANDIDATE='(none)'
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = UNKNOWN
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'no fixed candidate produces an actionable result without installation'
reset; MOCK_OLD_ORIGIN=0
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
ok 'an unindexed installed version can be replaced by a verified fixed candidate'
reset; MOCK_REPO=https://unverified.example/ubuntu
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = UNKNOWN
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'unverified candidate provenance blocks installation'
reset; MOCK_REPO=http://security.ubuntu.com/ubuntu
MOCK_NEW_REPO=https://ppa.launchpadcontent.net/ondrej/php/ubuntu
workflow < "$TMP/answer" > "$TMP/output"
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'a known installed vendor cannot silently switch to the PPA'
reset; MOCK_STATE_CHANGE=1
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = ERROR
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'service state changes outside the approved scope block installation'
reset; MOCK_HOLD=php8.4-common
workflow < "$TMP/answer" > "$TMP/output"
assert test ! -s "$TMP/calls"
ok 'held PHP package blocks repair without removing holds'
for unsafe in 'Remv php8.4-cli [8.4.26]' 'Inst unrelated [1] (2 mock)' 'Inst php8.5-cli (8.5.12 mock)' 'Conf unrelated (1 mock)'; do
    reset; MOCK_UNSAFE=$unsafe
    workflow < "$TMP/answer" > "$TMP/output"
    if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
done
ok 'APT removal, new branch, new dependency and unrelated configuration are refused'
for failure in MOCK_AUTH_FAIL MOCK_REFRESH_FAIL MOCK_INSTALL_FAIL MOCK_CONFIG_FAIL MOCK_RESTART_FAIL MOCK_SAME_PID; do
    reset; printf -v "$failure" '%s' 1
    workflow < "$TMP/answer" > "$TMP/output"
    assert test "$overall" = ERROR
done
ok 'authorization, APT, validation and restart failures cannot yield green PASS'
reset; MOCK_INSTALL_FAIL=1; MOCK_PARTIAL=1
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = ERROR
if grep -q 'systemctl restart' "$TMP/calls"; then exit 1; fi
ok 'partially successful package update is re-audited but remains ERROR'
reset; MOCK_POLICY=1
workflow < "$TMP/answer" > "$TMP/output"
assert test ! -s "$TMP/calls"
ok 'existing administrator restart policy is preserved'
reset; MOCK_STATE=inactive; MOCK_ACTIVE=0
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
if grep -q 'systemctl restart' "$TMP/calls"; then exit 1; fi
ok 'inactive services are never started or restarted'
reset; MOCK_PENDING='incomplete package'
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = ERROR
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'incomplete dpkg transactions block installation'
reset; MOCK_EMPTY=1
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = UNKNOWN; assert test ! -s "$TMP/calls"
reset; MOCK_QUERY_FAIL=1
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = ERROR; assert test ! -s "$TMP/calls"
ok 'missing PHP and failed inventory never report PASS'
for option in --json --output --yes --invalid; do
    set +e
    bash "$BASE/bin/php-security-check" "$option" >/dev/null 2>&1
    code=$?
    set -e
    assert test "$code" = 3
done
ok 'JSON/export and unconfirmed noninteractive fix options are removed'
reset; mode=check
workflow > "$TMP/sample"
if grep -q $'\033' "$TMP/sample"; then exit 1; fi
ok 'plain terminal report contains no ANSI escapes when color is disabled'
reset; MOCK_RELEASE=26.04; MOCK_MIXED=1; MOCK_CANDIDATE=$(cat "$TMP/version")
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = UNKNOWN
runtime_status php8.5-cli; assert test "$runtime_result" = PASS
runtime_status php8.3-cli; assert test "$runtime_result" = UNKNOWN
assert test "${#warnings[@]}" = 4
assert grep -Fq 'targets Ubuntu 24.04; host is 26.04' "$TMP/output"
assert grep -q 'APT candidate' "$TMP/output"
assert grep -q 'apt-cache policy' "$TMP/output"
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'Ubuntu 26.04 mixed 24.04 PPA builds/8.5 vendor fix reproduce the supplied log safely'
reset; MOCK_RELEASE=26.04
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = UNKNOWN
assert grep -q 'candidate targets Ubuntu 24.04' "$TMP/output"
if grep -q '/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'newer fixed but foreign-release PPA candidates are blocked'
reset; MOCK_RELEASE=26.04; MOCK_CANDIDATE=8.4.27-1+ubuntu26.04.1+deb.sury.org+1
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
ok 'a verified same-branch candidate built for the host release can repair old foreign builds'
reset
cat > "$TMP/ondrej.sources" <<'SOURCE'
Types: deb
URIs: https://ppa.launchpadcontent.net/ondrej/php/ubuntu
Suites: jammy
Components: main
Signed-By: /etc/apt/keyrings/ondrej.gpg
Enabled: no
SOURCE
MOCK_SOURCE="$TMP/ondrej.sources"
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = PASS
assert test "$(awk '/Choice \[0\]/ {n++} END {print n+0}' "$TMP/output")" = 1
assert grep -q 'Repository repair:' "$TMP/output"
assert grep -q '/repository-transaction.sh' "$TMP/calls"
assert grep -q '/transaction.sh' "$TMP/calls"
ok 'existing repository restoration is previewed and covered by the same single confirmation'
reset; MOCK_SOURCE="$TMP/ondrej.sources"; MOCK_REPO_CODE=71
workflow < "$TMP/answer" > "$TMP/output"
assert test "$overall" = ERROR
assert grep -q 'no retrievable signed PHP repository' "$TMP/output"
if grep -q '/lib/transaction.sh' "$TMP/calls"; then exit 1; fi
ok 'missing publisher suite (HTTP 404) prevents package installation and reports unchanged sources'
reset; MOCK_SOURCE="$TMP/ondrej.sources"; printf '0\n' > "$TMP/answer"
workflow < "$TMP/answer" > "$TMP/output"
assert test ! -s "$TMP/calls"
ok 'declining the combined repair never invokes repository modification'
printf '\n%d checks passed; all privileged operations were mocked.\n' "$count"
printf '\nSample patched-host report (fixture):\n'
reset; printf '%s\n' "$MOCK_CANDIDATE" > "$TMP/version"; snapshot; report_human
bash "$BASE/tests/repository.sh"
