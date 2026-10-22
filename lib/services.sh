# shellcheck shell=bash
# All evidence probes are read-only. Missing permissions/evidence fail closed.
service_unknown() {
    service_status=UNKNOWN
    unknown "$*"
}
file_change_time() {
    local times modified changed link_changed
    times=$(stat -Lc '%Y %Z' -- "$1" 2>/dev/null) || return 1
    read -r modified changed <<< "$times"
    [[ $modified =~ ^[0-9]+$ && $changed =~ ^[0-9]+$ ]] || return 1
    if [[ -L $1 ]]; then
        link_changed=$(stat -c %Z -- "$1" 2>/dev/null) || return 1
        [[ $link_changed =~ ^[0-9]+$ ]] || return 1
        ((link_changed>changed)) && changed=$link_changed
    fi
    ((changed>modified)) && modified=$changed
    printf '%s\n' "$modified"
}
package_change_time() {
    local service=$1 p branch='' path stamp latest=0 found=0 inventory state version
    [[ $service != php*-fpm ]] || branch=${service%-fpm}
    inventory=$(dpkg-query -W '-f=${binary:Package}\t${Version}\t${db:Status-Status}\n' 2>/dev/null) || return 1
    while IFS=$'\t' read -r p version state; do
        [[ $state == installed ]] || continue
        p=${p%%:*}
        if [[ $service == apache2 ]]; then
            [[ $p == apache2 || $p == apache2-bin || $p == libapache2-mod-php* || $p == php[0-9]* ]] || continue
        else
            [[ $p == "$branch" || $p == "$branch"-* ]] || continue
        fi
        found=1
        # .list ctime bounds local unpack/install; file ctime also catches preserved mtimes.
        stamp=$(file_change_time "/var/lib/dpkg/info/$p.list") || return 1
        ((stamp>latest)) && latest=$stamp
        local files
        files=$(dpkg-query -L "$p" 2>/dev/null) || return 1
        while IFS= read -r path; do
            [[ $path == /* ]] || return 1
            # Directories change for unrelated installs; only existing package files matter.
            [[ ! -f $path ]] || {
                stamp=$(file_change_time "$path") || return 1
                ((stamp>latest)) && latest=$stamp
            }
        done <<< "$files"
    done <<< "$inventory"
    ((found && latest>0)) || return 1
    printf '%s\n' "$latest"
}
service_snapshot() {
    systemctl show "$1" --property=MainPID,ExecMainStartTimestamp,ExecMainStartTimestampMonotonic,ControlGroup --no-pager 2>/dev/null
}
service_pids() {
    local group=$1 files file
    [[ $group == /* && $group != / && $group != *..* ]] || return 1
    [[ -r /sys/fs/cgroup/cgroup.controllers ]] || return 1 # cgroup v2 only
    files=$(find "/sys/fs/cgroup$group" -name cgroup.procs -type f 2>/dev/null) || return 1
    [[ -n $files ]] || return 1
    while IFS= read -r file; do cat -- "$file" || return 1; done <<< "$files"
}
process_start() {
    local line tail ticks hz boot
    IFS= read -r line < "/proc/$1/stat" || return 1
    tail=${line##*) } # comm can contain spaces and parentheses
    ticks=$(awk '{print $20}' <<< "$tail")
    hz=$(getconf CLK_TCK) || return 1
    boot=$(awk '$1=="btime" {print $2}' /proc/stat) || return 1
    [[ $ticks =~ ^[0-9]+$ && $hz =~ ^[0-9]+$ && $boot =~ ^[0-9]+$ ]] && ((hz>0)) || return 1
    printf '%s %s\n' "$((boot+ticks/hz))" "$((ticks*1000000/hz))"
}
process_runtime() {
    local pid=$1 service=$2 exe maps
    exe=$(readlink "/proc/$pid/exe" 2>/dev/null) || return 1
    maps=$(cat "/proc/$pid/maps" 2>/dev/null) || return 1
    runtime_matches "$service" "$exe" "$maps"
}
runtime_matches() {
    local service=$1 exe=$2 maps=$3 module owner branch
[[ $exe != *' (deleted)' ]] || return 1
    # OPcache/Apache may legitimately map anonymous /dev/zero or memfd regions.
    # Deleted shared libraries are stale code; anonymous shared memory is not.
    if awk '$6 ~ /\.so(\.[0-9]+)*$/ && / \(deleted\)$/ {found=1} END {exit !found}' <<< "$maps"; then return 1; fi
    if [[ $service == php*-fpm ]]; then
        branch=${service#php}; branch=${branch%-fpm}
        [[ $exe == "/usr/sbin/php-fpm$branch" ]] || return 1
    else
        [[ $exe == /usr/sbin/apache2 ]] || return 1
    fi
    # Check executable ownership against the installed package inventory.
    owner=$(dpkg-query -S "$exe" 2>/dev/null) || return 1
    if [[ $service == apache2 ]]; then
        [[ $owner == apache2-bin:* || $owner == apache2-bin:amd64:* || $owner == apache2-bin:arm64:* ]] || return 1
        for module in "${apache_php_modules[@]}"; do
            [[ $maps == *" $module"$'\n'* || $maps == *" $module" ]] || return 1
        done
        # A PHP module loaded by the old process but absent from current config is unresolved.
        while IFS= read -r module; do
            [[ " ${apache_php_modules[*]} " == *" $module "* ]] || return 1
        done < <(awk '$6 ~ /\/libphp.*\.so$/ {print $6}' <<< "$maps" | sort -u)
    else
        [[ $owner == "$service:"* ]] || return 1
    fi
}
verify_freshness() {
    local s=$1 before after pid='' started='' monotonic='' group='' key value changed pids proc epoch mono main_seen=0 now
    freshness_reason='restart freshness unverified: package/config or process evidence is unavailable; check local dpkg metadata, standard service configuration and /proc read permissions, then retry the read-only audit.'
    before=$(service_snapshot "$s") || return 1
    while IFS='=' read -r key value; do
        case $key in MainPID) pid=$value;; ExecMainStartTimestamp) started=$value;; ExecMainStartTimestampMonotonic) monotonic=$value;; ControlGroup) group=$value;; esac
    done <<< "$before"
    [[ $pid =~ ^[1-9][0-9]*$ && $monotonic =~ ^[1-9][0-9]*$ ]] || return 1
    [[ -n $started && $started != n/a ]] || return 1
    started=$(date -d "$started" +%s 2>/dev/null) || return 1
    service_launch_matches "$s" "$pid" || return 1
    changed=$(service_change_time "$s") || return 1
    [[ $changed =~ ^[1-9][0-9]*$ ]] || return 1
    now=$(date +%s) || return 1
    ((started>changed && started<=now && changed<=now)) || {
        freshness_reason='restart freshness unverified: service start does not postdate package/config changes; review and restart this service if needed.'
        return 1
    }
    freshness_reason='restart freshness unverified: process identity/start times or cgroup membership could not be verified; inspect /proc permissions and retry if workers changed during inspection.'
    pids=$(service_pids "$group") || return 1
    [[ -n $pids ]] || return 1
    while IFS= read -r proc; do
        [[ $proc =~ ^[1-9][0-9]*$ ]] || return 1
        read -r epoch mono < <(process_start "$proc") || return 1
        [[ $epoch =~ ^[0-9]+$ && $mono =~ ^[0-9]+$ ]] || return 1
        ((epoch>changed && epoch<=now)) || return 1
        if [[ $proc == "$pid" ]]; then
            main_seen=1
            # Cross-check systemd's wall/monotonic start against the kernel's PID start.
            ((epoch>=started-2 && epoch<=started+2 && mono>=monotonic-2000000 && mono<=monotonic+2000000)) || return 1
        fi
        process_runtime "$proc" "$s" || return 1
    done <<< "$pids"
    ((main_seen)) || return 1
    after=$(service_snapshot "$s") || return 1
    [[ $before == "$after" && $(service_change_time "$s") == "$changed" ]] || return 1
    # A new worker during inspection is safe only after it too has been inspected.
    [[ $(service_pids "$group") == "$pids" ]] || return 1
}
inspect_services() {
    local s
    service_status=PASS; freshness_status=PASS; handler_status=PASS
    service_evidence=(); apache_php_modules=(); apache_config_files=()
    inspect_web_handlers
    for s in "${services[@]}"; do
        if ! systemctl is-active --quiet "$s" 2>/dev/null; then
            freshness_status=UNKNOWN
            service_evidence+=("$s|UNKNOWN|inactive or unreadable")
            service_unknown "$s: restart freshness unverified: service is inactive or its state cannot be read."
        elif verify_freshness "$s"; then
            service_evidence+=("$s|PASS|processes postdate package/config changes")
        else
            freshness_status=UNKNOWN
            service_evidence+=("$s|UNKNOWN|restart freshness unverified")
            service_unknown "$s: $freshness_reason"
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
    # The following re-audit must prove freshness. Restart success/activity is insufficient.
}

service_change_time() {
    local s=$1 latest stamp file configs line value branch
    latest=$(package_change_time "$s") || return 1
    if [[ $s == apache2 ]]; then
        for file in "${apache_config_files[@]}"; do
            stamp=$(file_change_time "$file") || return 1
            ((stamp>latest)) && latest=$stamp
        done
    else
        branch=${s#php}; branch=${branch%-fpm}
        # Only standard pool includes are supported. External includes need manual review.
        configs=$(find -L "/etc/php/$branch/fpm" \( -type f -o -type d \) 2>/dev/null) || return 1
        [[ -n $configs ]] || return 1
        while IFS= read -r file; do
            [[ -r $file ]] || return 1
            stamp=$(file_change_time "$file") || return 1
            ((stamp>latest)) && latest=$stamp
            [[ -f $file ]] || continue
            while IFS= read -r line || [[ -n $line ]]; do
                line=${line%%;*}; line=${line%%#*}
                if [[ $line =~ ^[[:space:]]*include[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                    value=${BASH_REMATCH[1]}
                    [[ $value == "/etc/php/$branch/fpm/pool.d/*.conf" ]] || return 1
                fi
            done < "$file"
        done <<< "$configs"
    fi
    printf '%s\n' "$latest"
}

service_launch_matches() {
    local service=$1 pid=$2 cmd env process_env exec
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || return 1
    env=$(systemctl show "$service" --property=Environment --value 2>/dev/null) || return 1
    process_env=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null) || return 1
    if [[ $service == php*-fpm ]]; then
        exec=$(systemctl show "$service" --property=ExecStart --value 2>/dev/null) || return 1
        fpm_exec_matches "$service" "$exec" || return 1
    fi
    launch_matches "$service" "$cmd" "$env" "$process_env"
}
launch_matches() {
    local service=$1 cmd=$2 env=$3 process_env=$4 branch key value
    [[ $env != *PHPRC=* && $env != *PHP_INI_SCAN_DIR=* && $env != *APACHE_ARGUMENTS=* && $env != *APACHE_CONFDIR=* && $env != *APACHE_ENVVARS=* ]] || return 1
    while IFS='=' read -r key value; do
        case $key in
            PHPRC|PHP_INI_SCAN_DIR) return 1;;
            APACHE_CONFDIR) [[ $value == /etc/apache2 ]] || return 1;;
            APACHE_ENVVARS) [[ $value == /etc/apache2/envvars ]] || return 1;;
            APACHE_ARGUMENTS) [[ -z $value ]] || return 1;;
        esac
    done <<< "$process_env"
    if [[ $service == apache2 ]]; then
        # apache2ctl probes use the standard config; do not equate it with a custom -f/-d/-D launch.
        [[ $cmd == '/usr/sbin/apache2 -k start ' || $cmd == '/usr/sbin/apache2 -DFOREGROUND ' ]] || return 1
    else
        branch=${service#php}; branch=${branch%-fpm}
        # FPM exposes the actual master config in its process title. Custom paths fail closed.
        [[ $cmd =~ ^php-fpm:\ master\ process\ \(/etc/php/$branch/fpm/php-fpm.conf\)[[:space:]]*$ ]] || return 1
    fi
}

fpm_exec_matches() {
    local service=$1 raw=$2 pattern='argv\[\]=([^;]+);' branch argv executable argument config='' foreground=0
    branch=${service#php}; branch=${branch%-fpm}
    [[ $raw =~ $pattern ]] || return 1
    argv=${BASH_REMATCH[1]}
    local -a args=()
    read -r -a args <<< "$argv"
    ((${#args[@]})) || return 1
    executable=${args[0]}
    [[ $executable == "/usr/sbin/php-fpm$branch" ]] || return 1
    local i
    for ((i=1; i<${#args[@]}; i++)); do
        argument=${args[i]}
        case $argument in
            --nodaemonize|-F) foreground=1;;
            --force-stderr|-O) :;;
            --fpm-config|-y)
                i=$((i+1)); ((i<${#args[@]})) || return 1
                config=${args[i]};;
            *) return 1;; # Includes custom -c/-d PHP ini options and wrappers.
        esac
    done
    [[ $foreground == 1 && $config == "/etc/php/$branch/fpm/php-fpm.conf" ]]
}
