# shellcheck shell=bash
add_service() {
    [[ " ${services[*]} " == *" $1 "* ]] || services+=("$1")
}
handler_unknown() {
    handler_status=UNKNOWN
    service_unknown "Web handler coverage unverified: $*"
}
apache_includes() {
    local dump
    dump=$(apache2ctl -t -D DUMP_INCLUDES 2>/dev/null) || return 1
    printf '%s\n' "$dump" | sed -nE 's/^[[:space:]]*\([^)]*\)[[:space:]]+(\/.*)$/\1/p'
}
socket_service() {
    local socket=$1 s pid inode fd link resolved
    [[ $socket == /run/php/*.sock || $socket == /var/run/php/*.sock ]] || return 1
    resolved=$(readlink -f "$socket" 2>/dev/null) || return 1
    [[ -S $resolved ]] || return 1
    inode=$(awk -v path="$resolved" '$8==path {print $7}' /proc/net/unix) || return 1
    [[ $inode =~ ^[0-9]+$ ]] || return 1
    for s in "${services[@]}"; do
        [[ $s == php*-fpm ]] || continue
        pid=$(systemctl show "$s" --property=MainPID --value 2>/dev/null) || continue
        [[ $pid =~ ^[1-9][0-9]*$ ]] || continue
        for fd in /proc/"$pid"/fd/*; do
            link=$(readlink "$fd" 2>/dev/null) || continue
            if [[ $link == "socket:[$inode]" ]]; then printf '%s\n' "$s"; return 0; fi
        done
    done
    return 1
}
inspect_apache_handlers() {
    local includes modules file line directive value module owner target directory count=0
    includes=$(apache_includes) || { handler_unknown 'Apache include/config inspection failed; check configtest and read permissions.'; return; }
    [[ -n $includes ]] || { handler_unknown 'Apache did not expose its enabled include tree.'; return; }
    modules=$(apache2ctl -M 2>/dev/null) || { handler_unknown 'Apache module inspection failed.'; return; }
    while IFS= read -r file; do
        [[ $file == /* && -f $file && -r $file ]] || { handler_unknown 'An enabled Apache configuration is unreadable.'; continue; }
        apache_config_files+=("$file")
        while IFS= read -r line || [[ -n $line ]]; do
            line=${line%%#*}
            read -r directive value <<< "$line"
            directive=${directive,,}
            [[ -n $directive ]] || continue
            value=${value%$'\r'}
            case $directive in
                include|includeoptional)
                    target=${value#\"}; target=${target%\"}
                    [[ $target == /* ]] || target="/etc/apache2/$target"
                    directory=${target%/*}
                    if [[ $directory == *[\$%\*\?\[\]]* || $target == *[\$%]* || -d $target || ! -d $directory || ! -r $directory ]]; then
                        handler_unknown 'Dynamic/unreadable include directory requires manual review.'
                    else apache_config_files+=("$directory"); fi;;
                loadmodule)
                    read -r module target <<< "$value"
                    if [[ $module == php*_module ]]; then
                        [[ $modules == *" $module "* ]] || { handler_unknown 'Configured PHP module is not enabled.'; continue; }
                        target=${target#\"}; target=${target%\"}
                        owner=$(dpkg-query -S "$target" 2>/dev/null) || owner=''
                        if [[ $target =~ ^/usr/lib/apache2/modules/libphp[0-9]+\.[0-9]+\.so$ && $owner == libapache2-mod-php*:* ]]; then
                            local package=${owner%%:*}
                            if [[ " ${packages[*]} " == *" $package "* ]]; then apache_php_modules+=("$target")
                            else handler_unknown 'Loaded PHP module has no audited installed runtime.'; fi
                        else handler_unknown 'Custom or unowned PHP module requires manual mapping.'; fi
                    fi;;
                sethandler|addhandler|addtype)
                    value=${value#\"}; value=${value%\"}
                    case $value in
                        application/x-httpd-php|application/x-httpd-php\ *|application/x-httpd-php-source|application/x-httpd-php-source\ *)
                            count=$((count+1))
                            [[ $modules == *' php_module '* || $modules == *' php7_module '* || $modules == *' php8_module '* ]] || handler_unknown 'mod_php handler has no enabled PHP module.';;
                        proxy:unix:*)
                            count=$((count+1))
                            if [[ $directive == sethandler && $value =~ ^proxy:unix:(/[^\|\ \$%\"\']+)\|fcgi://localhost/?$ && $modules == *' proxy_fcgi_module '* ]]; then
                                if ! socket_service "${BASH_REMATCH[1]}" >/dev/null; then
                                    handler_unknown 'A configured FPM socket cannot be matched to an audited local FPM master; check enabled VirtualHosts and socket ownership/read permissions.'
                                fi
                            else handler_unknown 'Dynamic or unsupported FPM handler; review enabled VirtualHost overrides.'; fi;;
                        none|default-handler|text/*) :;;
                        *) handler_unknown 'An enabled handler/type directive is unsupported; review enabled VirtualHost overrides.';;
                    esac;;
                allowoverride|allowoverridelist)
                    [[ ${value,,} == none ]] || handler_unknown '.htaccess overrides are permitted; handler overrides require manual review.';;
                proxypass*|action|scriptalias*|fcgi*|fastcgi*|lua*|perl*|python*|passenger*|phpinidir|define|undefine|use|macro|'<macro'|'<if'|'<elseif'|'<else')
                    handler_unknown 'Dynamic/CGI/proxy configuration prevents complete handler mapping.';;
                rewriterule)
                    [[ ! ${value,,} =~ \[[^]]*(h=|handler=|p[\],]|proxy[\],]) ]] || handler_unknown 'Rewrite-based handler/proxy requires manual review.';;
            esac
            [[ $line != *\\ ]] || handler_unknown 'Multiline configuration requires manual handler review.'
        done < "$file"
    done <<< "$includes"
    ((count>0)) || handler_unknown 'No supported PHP handler found in the enabled Apache include tree.'
    if [[ $modules == *' php_module '* || $modules == *' php7_module '* || $modules == *' php8_module '* ]]; then
        ((${#apache_php_modules[@]})) || handler_unknown 'Enabled PHP module has no verified package path.'
    fi
}
web_service_state() {
    local info key value loaded='' active=''
    info=$(systemctl show "$1" --property=LoadState,ActiveState --no-pager 2>/dev/null) || return 1
    while IFS='=' read -r key value; do
        case $key in LoadState) loaded=$value;; ActiveState) active=$value;; esac
    done <<< "$info"
    case $loaded:$active in
        loaded:active|loaded:reloading) printf 'active\n';;
        loaded:inactive|loaded:failed|not-found:inactive) printf 'inactive\n';;
        *) return 1;;
    esac
}
inspect_web_handlers() {
    local state
    if state=$(web_service_state apache2); then
        if [[ $state == active ]]; then
            add_service apache2
            inspect_apache_handlers
        fi
    else handler_unknown 'Cannot establish Apache service state; inspect systemd access/state.'; fi
    if state=$(web_service_state nginx); then
        if [[ $state == active ]]; then
            handler_unknown 'Nginx upstream mapping is not supported; inspect enabled PHP locations/upstreams manually.'
        fi
    else handler_unknown 'Cannot establish Nginx service state; inspect systemd access/state.'; fi
}
