#!/usr/bin/env bash
# Low-level evidence fixtures. No writes outside a disposable test directory.
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/services.sh
source "$BASE/lib/services.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
count=0
assert() { "$@" || { printf 'FAIL evidence test: %s\n' "$*" >&2; exit 1; }; }
ok() { count=$((count+1)); printf 'ok evidence %d - %s\n' "$count" "$1"; }
: > "$TMP/code"; ln -s "$TMP/code" "$TMP/link"
MOCK_MTIME=80; MOCK_CTIME=100; MOCK_LINK_TIME=120; MOCK_MISSING=0
# shellcheck disable=SC2329
stat() {
    if [[ ${*: -1} == /var/lib/dpkg/info/* && $MOCK_MISSING == 1 ]]; then return 1; fi
    if [[ $1 == -Lc ]]; then printf '%s %s\n' "$MOCK_MTIME" "$MOCK_CTIME"; else printf '%s\n' "$MOCK_LINK_TIME"; fi
}
assert test "$(file_change_time "$TMP/code")" = 100
assert test "$(file_change_time "$TMP/link")" = 120
MOCK_MTIME=130
assert test "$(file_change_time "$TMP/code")" = 130
ok 'timestamp bound uses mtime, inode ctime and configuration symlink ctime'
# shellcheck disable=SC2329
dpkg-query() {
    case $1 in
        -W) printf 'php8.4-fpm\t8.4.27-1\tinstalled\nphp8.4-common\t8.4.27-1\tinstalled\n';;
        -L) printf '%s\n' "$TMP/code";;
        *) return 1;;
    esac
}
assert test "$(package_change_time php8.4-fpm)" = 130
MOCK_MISSING=1
if package_change_time php8.4-fpm >/dev/null; then exit 1; fi
MOCK_MISSING=0
ok 'package installation metadata is mandatory alongside code timestamps'
# Restore/find fixtures for standard FPM configuration and external includes.
# shellcheck disable=SC2329
find() { printf '%s\n' "$TMP" "$TMP/php-fpm.conf"; }
printf 'include=/etc/php/8.4/fpm/pool.d/*.conf\n' > "$TMP/php-fpm.conf"
assert test "$(service_change_time php8.4-fpm)" = 130
printf 'include=/custom/pools/*.conf\n' > "$TMP/php-fpm.conf"
if service_change_time php8.4-fpm >/dev/null; then exit 1; fi
ok 'standard config accepted; external pool includes cannot bypass freshness bounds'
# Validate the actual kernel start-time parser where /proc is available (Linux CI).
if [[ -r /proc/$$/stat ]]; then
    read -r epoch monotonic < <(process_start "$$")
    [[ $epoch =~ ^[1-9][0-9]*$ && $monotonic =~ ^[1-9][0-9]*$ ]]
    ok 'kernel start-time fields parsed from a real unprivileged Linux process'
else
    printf 'SKIP - real /proc start-time probe (Linux required)\n'
fi
if service_pids / >/dev/null; then exit 1; fi
if service_pids /system.slice/../ >/dev/null; then exit 1; fi
ok 'cgroup evidence refuses root scope and traversal'
printf '%d evidence checks passed\n' "$count"
