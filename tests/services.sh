#!/usr/bin/env bash
# Evidence/handler regressions: only fixture files and mocked read-only probes.
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$BASE/lib/common.sh"
# shellcheck source=../lib/handlers.sh
source "$BASE/lib/handlers.sh"
# shellcheck source=../lib/services.sh
source "$BASE/lib/services.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
count=0
assert() { "$@" || { printf 'FAIL service test: %s\n' "$*" >&2; exit 1; }; }
ok() { count=$((count+1)); printf 'ok service %d - %s\n' "$count" "$1"; }
reset() {
    warnings=(); overall=PASS; services=(php8.4-fpm); apache_php_modules=(); apache_config_files=()
    MOCK_CHANGED=100; MOCK_START=200; MOCK_MONO=200000000; MOCK_WORKER=210
    MOCK_ACTIVE=1; MOCK_RUNTIME=1; MOCK_APACHE=0; MOCK_NGINX=0; MOCK_SOCKET=1
    MOCK_METADATA=1; MOCK_PID=10; MOCK_PIDS=$'10\n11'; MOCK_MODULES=' proxy_fcgi_module (shared)'; MOCK_CONFIGS="$TMP/main.conf"
    printf 'SetHandler "proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost/"\nAllowOverride None\n' > "$TMP/main.conf"
}
# shellcheck disable=SC2329
systemctl() {
    [[ $1 == is-active ]] || return 1
    case ${*: -1} in apache2) [[ $MOCK_APACHE == 1 ]];; nginx) [[ $MOCK_NGINX == 1 ]];; *) [[ $MOCK_ACTIVE == 1 ]];; esac
}
# shellcheck disable=SC2329
web_service_state() {
    case $1 in apache2) if [[ $MOCK_APACHE == 1 ]]; then printf 'active\n'; else printf 'inactive\n'; fi;;
        nginx) if [[ $MOCK_NGINX == 1 ]]; then printf 'active\n'; else printf 'inactive\n'; fi;; esac
}
# shellcheck disable=SC2329
date() { if [[ $1 == -d ]]; then printf '%s\n' "$MOCK_START"; else printf '1000\n'; fi; }
# shellcheck disable=SC2329
service_launch_matches() { return 0; }
# shellcheck disable=SC2329
service_snapshot() {
    printf 'MainPID=%s\nExecMainStartTimestamp=fixture\nExecMainStartTimestampMonotonic=%s\nControlGroup=/system.slice/%s.service\n' "$MOCK_PID" "$MOCK_MONO" "$1"
}
# shellcheck disable=SC2329
service_change_time() { [[ $MOCK_METADATA == 1 ]] || return 1; printf '%s\n' "$MOCK_CHANGED"; }
# shellcheck disable=SC2329
service_pids() { printf '%s\n' "$MOCK_PIDS"; }
# shellcheck disable=SC2329
process_start() { if [[ $1 == 10 ]]; then printf '%s %s\n' "$MOCK_START" "$MOCK_MONO"; else printf '%s %s\n' "$MOCK_WORKER" "$((MOCK_WORKER*1000000))"; fi; }
# shellcheck disable=SC2329
process_runtime() { [[ $MOCK_RUNTIME == 1 ]]; }
# shellcheck disable=SC2329
apache_includes() { printf '%s\n' "$MOCK_CONFIGS"; }
# shellcheck disable=SC2329
apache2ctl() { printf '%s\n' "$MOCK_MODULES"; }
# shellcheck disable=SC2329
socket_service() { [[ $MOCK_SOCKET == 1 ]]; }
# shellcheck disable=SC2329
dpkg-query() { printf 'libapache2-mod-php8.4: /usr/lib/apache2/modules/libphp8.4.so\n'; }
reset
inspect_services
assert test "$service_status" = PASS
assert test "$freshness_status" = PASS
assert test "${#warnings[@]}" = 0
ok 'external restart verified without a current-invocation flag'
reset; MOCK_CHANGED=250
inspect_services
assert test "$service_status" = UNKNOWN
assert test "$freshness_status" = UNKNOWN
assert test "${warnings[0]#*restart freshness unverified}" != "${warnings[0]}"
ok 'active service predating package changes cannot pass'
reset; MOCK_METADATA=0; restarted=1
inspect_services
assert test "$service_status" = UNKNOWN
ok 'restart command flag cannot bypass missing metadata'
reset; MOCK_WORKER=90
inspect_services
assert test "$service_status" = UNKNOWN
ok 'old surviving worker fails freshness despite new master'
reset; MOCK_RUNTIME=0
inspect_services
assert test "$service_status" = UNKNOWN
ok 'deleted/unowned runtime probe failure fails closed'
reset; MOCK_PID=12
inspect_services
assert test "$service_status" = UNKNOWN
ok 'systemd main PID must be in inspected cgroup'
reset; MOCK_APACHE=1
inspect_services
assert test "$service_status" = PASS
assert test "$handler_status" = PASS
assert test "${#services[@]}" = 2
ok 'Apache FPM handler and externally restarted FPM pass with evidence'
reset; MOCK_APACHE=1
packages=(php8.4-fpm libapache2-mod-php8.4)
MOCK_MODULES=$' php_module (shared)\n proxy_fcgi_module (shared)'
printf 'LoadModule php_module /usr/lib/apache2/modules/libphp8.4.so\nSetHandler application/x-httpd-php\n' >> "$TMP/main.conf"
inspect_services
assert test "$service_status" = PASS
assert test "${#apache_php_modules[@]}" = 1
ok 'mixed mod_php and FPM mappings both verified'
reset; MOCK_APACHE=1
MOCK_CONFIGS+=$'\n'"$TMP/vhost.conf"
printf '<VirtualHost *:443>\nSetHandler "proxy:fcgi://remote.example:9000"\n</VirtualHost>\n' > "$TMP/vhost.conf"
inspect_services
assert test "$freshness_status" = PASS
assert test "$handler_status" = UNKNOWN
assert test "$service_status" = UNKNOWN
assert test "$overall" = UNKNOWN
assert test "${warnings[*]}" = "${warnings[*]//restart freshness unverified/}"
ok 'enabled VirtualHost override unresolved independently of verified restart'
reset; MOCK_APACHE=1; MOCK_SOCKET=0
inspect_services
assert test "$handler_status" = UNKNOWN
assert test "$freshness_status" = PASS
ok 'socket name alone cannot prove local FPM ownership'
reset; MOCK_APACHE=1
printf 'AllowOverride FileInfo\n' >> "$TMP/main.conf"
inspect_services
assert test "$handler_status" = UNKNOWN
ok '.htaccess handler overrides remain unknown'
reset; MOCK_NGINX=1
inspect_services
assert test "$handler_status" = UNKNOWN
assert test "$freshness_status" = PASS
ok 'unsupported Nginx handler coverage stays unknown without restart advice'
reset; MOCK_APACHE=1
# Literal Apache backreference.
# shellcheck disable=SC2016
printf 'RewriteRule ^(.*)$ $1 [P,L]\n' >> "$TMP/main.conf"
inspect_services
assert test "$handler_status" = UNKNOWN
ok 'rewrite proxy override cannot bypass handler review'
reset; MOCK_ACTIVE=0
inspect_services
assert test "$service_status" = UNKNOWN
ok 'inactive service remains unknown'
# Real audit + report, with patched advisory fixture. No host package/service calls.
# shellcheck source=../lib/advisories.sh
source "$BASE/lib/advisories.sh"
# shellcheck source=../lib/audit.sh
source "$BASE/lib/audit.sh"
# shellcheck source=../lib/report.sh
source "$BASE/lib/report.sh"
# shellcheck disable=SC2329
remaining_updates() { :; }
# These equal version fixtures need no platform-specific dpkg comparator.
# shellcheck disable=SC2329
dpkg() { [[ $2 == "$4" ]]; }
reset; MOCK_APACHE=1
runtimes=('php8.4-fpm|8.4.27-1+deb.sury.org+1|FPM'); origins=(Ondrej-PPA); activities=(active)
os_version=24.04; os_name='Ubuntu 24.04.5'; arch=amd64
audit
assert test "$overall" = PASS
assert test "${results[0]}" = 'php8.4-fpm|CVE-2026-109618|PASS'
report_json > "$TMP/report.json"
if command -v ruby >/dev/null; then
    ruby -rjson -e 'r=JSON.parse(File.read(ARGV[0])); abort unless r["services"].values_at("status","freshness","handler_coverage")==%w[PASS PASS PASS]; abort unless r["overall"]=="PASS"' "$TMP/report.json"
fi
ok 'patched PHP 8.4.27 plus verified serving evidence produces PASS report'
# Validate executable/module checks themselves, rather than replacing that probe.
# shellcheck disable=SC2329
dpkg-query() {
    case $2 in
        /usr/sbin/php-fpm8.4) printf 'php8.4-fpm: %s\n' "$2";;
        /usr/sbin/apache2) printf 'apache2-bin: %s\n' "$2";;
        *) return 1;;
    esac
}
assert runtime_matches php8.4-fpm /usr/sbin/php-fpm8.4 '000-fff rw-s 000 00:00 0 /dev/zero (deleted)'
if runtime_matches php8.4-fpm '/usr/sbin/php-fpm8.4 (deleted)' ''; then exit 1; fi
if runtime_matches php8.4-fpm /usr/sbin/php-fpm8.3 ''; then exit 1; fi
if runtime_matches php8.4-fpm /usr/sbin/php-fpm8.4 '000-fff r-xp 000 00:00 1 /usr/lib/php/opcache.so (deleted)'; then exit 1; fi
ok 'correct Ubuntu FPM executable name; anonymous OPcache memory is safe, deleted code is not'
apache_php_modules=(/usr/lib/apache2/modules/libphp8.4.so)
assert runtime_matches apache2 /usr/sbin/apache2 '000-fff r-xp 000 00:00 1 /usr/lib/apache2/modules/libphp8.4.so'
if runtime_matches apache2 /usr/sbin/apache2 '000-fff r-xp 000 00:00 1 /usr/lib/apache2/modules/libphp8.3.so'; then exit 1; fi
ok 'Apache must map every configured PHP module and no unaccounted PHP module'
assert launch_matches php8.4-fpm 'php-fpm: master process (/etc/php/8.4/fpm/php-fpm.conf) ' '' ''
if launch_matches php8.4-fpm 'php-fpm: master process (/custom/php-fpm.conf) ' '' ''; then exit 1; fi
if launch_matches php8.4-fpm 'php-fpm: master process (/etc/php/8.4/fpm/php-fpm.conf) ' '' 'PHP_INI_SCAN_DIR=/custom'; then exit 1; fi
assert launch_matches apache2 '/usr/sbin/apache2 -k start ' '' 'APACHE_CONFDIR=/etc/apache2'
if launch_matches apache2 '/usr/sbin/apache2 -f /custom/apache.conf ' '' ''; then exit 1; fi
ok 'actual launch config and PHP environment must match inspected configuration'
assert fpm_exec_matches php8.4-fpm '{ path=/usr/sbin/php-fpm8.4 ; argv[]=/usr/sbin/php-fpm8.4 --nodaemonize --fpm-config /etc/php/8.4/fpm/php-fpm.conf ; ignore_errors=no ; }'
if fpm_exec_matches php8.4-fpm '{ argv[]=/usr/sbin/php-fpm8.4 --nodaemonize --fpm-config /etc/php/8.4/fpm/php-fpm.conf -c /custom/php.ini ; }'; then exit 1; fi
ok 'systemd FPM ExecStart rejects hidden custom ini launch options'
printf '%d total service checks passed\n' "$count"
