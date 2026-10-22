# shellcheck shell=bash
# Only services for an approved PHP source branch are considered. No handler parser.
add_fix_service() {
    local service=$1 info key value active='' loaded=''
    [[ " ${scope_service_states[*]} " != *" $service|"* ]] || return 0
    info=$(systemctl show "$service" --property=LoadState,ActiveState --no-pager 2>/dev/null) || { block_reason="Cannot read $service state; automatic repair requires systemd service evidence."; return 1; }
    while IFS='=' read -r key value; do
        case $key in LoadState) loaded=$value;; ActiveState) active=$value;; esac
    done <<< "$info"
    [[ $loaded == loaded ]] || { block_reason="$service unit is unavailable; review process management manually."; return 1; }
    scope_service_states+=("$service|$active")
    case $active in
        active) fix_services+=("$service");;
        inactive) :;;
        *) block_reason="$service is failed or changing state. Resolve it before automatic repair."; return 1;;
    esac
}
validate_services() {
    local service branch row expected state
    service_error=''
    for row in "${scope_service_states[@]}"; do
        IFS='|' read -r service expected <<< "$row"
        state=$(systemctl show "$service" --property=ActiveState --value 2>/dev/null) || { service_error="Cannot recheck $service state."; return 1; }
        [[ $state == "$expected" ]] || { service_error="$service state changed outside the approved scope; repair stopped."; return 1; }
    done
    for service in "${fix_services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then service_error="$service is no longer active. No inactive service will be started."; return 1; fi
        if [[ $service == apache2 ]]; then
            if ! run_root apache2ctl configtest >/dev/null 2>&1; then service_error='Apache configuration validation failed. Fix its configuration before restarting.'; return 1; fi
        else
            branch=${service#php}; branch=${branch%-fpm}
            if ! run_root "/usr/sbin/php-fpm$branch" -t >/dev/null 2>&1; then service_error="$service configuration validation failed. Review its pool configuration."; return 1; fi
        fi
    done
}
service_identity() {
    local info key value pid='' started=''
    info=$(systemctl show "$1" --property=MainPID,ExecMainStartTimestampMonotonic --no-pager 2>/dev/null) || return 1
    while IFS='=' read -r key value; do
        case $key in MainPID) pid=$value;; ExecMainStartTimestampMonotonic) started=$value;; esac
    done <<< "$info"
    [[ $pid =~ ^[1-9][0-9]*$ && $started =~ ^[1-9][0-9]*$ ]] || return 1
    printf '%s %s\n' "$pid" "$started"
}
restart_services() {
    local service before after old_pid old_time new_pid new_time
    for service in "${fix_services[@]}"; do
        before=$(service_identity "$service") || { service_error="Cannot verify $service process identity; restart not attempted."; return 1; }
        if ! run_root systemctl restart "$service" >/dev/null 2>&1; then service_error="$service restart failed. Check systemctl status/journal locally."; return 1; fi
        after=$(service_identity "$service") || { service_error="$service restarted but its new process identity is unverified."; return 1; }
        read -r old_pid old_time <<< "$before"
        read -r new_pid new_time <<< "$after"
        if [[ $new_pid == "$old_pid" ]] || ((new_time<=old_time)) || ! systemctl is-active --quiet "$service" 2>/dev/null; then
            service_error="$service restart could not be verified as a new active main process."; return 1
        fi
    done
}
