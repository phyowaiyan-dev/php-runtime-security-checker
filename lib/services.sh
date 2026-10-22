# shellcheck shell=bash
inspect_services() {
    local s
    for s in "${services[@]}"; do
        if ! systemctl is-active --quiet "$s" 2>/dev/null; then
            service_status=UNKNOWN; unknown "$s is inactive or its state cannot be read."
        elif [[ ${restarted:-0} != 1 ]]; then
            service_status=UNKNOWN; unknown "$s: loaded PHP freshness is unverified; explicit restart needed."
        fi
    done
}
restart_services() {
    local s
    for s in "${services[@]}"; do
        if [[ $s == apache2 ]]; then
            apache2ctl configtest >&2 || { error 'Apache configuration validation failed.'; return; }
        fi
        systemctl is-active --quiet "$s" || { error "Refusing to start inactive service $s."; return; }
    done
    for s in "${services[@]}"; do
        if ! systemctl restart "$s" >&2 || ! systemctl is-active --quiet "$s"; then error "Restart verification failed: $s"; return; fi
    done
    restarted=1
}
