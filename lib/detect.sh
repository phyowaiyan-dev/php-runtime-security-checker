# shellcheck shell=bash
read_os() {
    [[ -r /etc/os-release ]] || return 1
    local key value
    os_id=unknown; os_version=unknown; os_name=unknown
    while IFS='=' read -r key value; do
        value=${value#\"}; value=${value%\"}
        case $key in ID) os_id=$value;; VERSION_ID) os_version=$value;; PRETTY_NAME) os_name=$value;; esac
    done < /etc/os-release
}
# Match the requested version's block, for either an installed or candidate version.
# Repository URLs are consumed locally and never printed.
policy_origin() {
    local policy=$1 version=$2
    origin=unknown
    if awk -v ver="$version" '
        $1=="***" {selected=($2==ver); next}
        NF==2 && $2 ~ /^[0-9]+$/ {selected=($1==ver); next}
        selected && /https?:\/\/([a-z][a-z]\.)?(archive\.ubuntu\.com|security\.ubuntu\.com|ports\.ubuntu\.com)\// {found=1}
        END {exit !found}' <<< "$policy"; then origin=Ubuntu
    elif [[ $version == *+deb.sury.org+* ]] && awk -v ver="$version" '
        $1=="***" {selected=($2==ver); next}
        NF==2 && $2 ~ /^[0-9]+$/ {selected=($1==ver); next}
        selected && /https?:\/\/ppa\.launchpad(content)?\.net\/ondrej\/php\// {found=1}
        END {exit !found}' <<< "$policy"; then origin=Ondrej-PPA
    fi
}
detect() {
    read_os || { unknown 'Ubuntu OS information unavailable.'; return; }
    arch=$(dpkg --print-architecture 2>/dev/null) || arch=unknown
    case $os_id:$os_version:$arch in
        ubuntu:22.04:amd64|ubuntu:22.04:arm64|ubuntu:24.04:amd64|ubuntu:24.04:arm64|ubuntu:26.04:amd64|ubuntu:26.04:arm64) supported=1;;
        *) unknown 'Unsupported OS/architecture. Automatic repair is disabled.';;
    esac
    local p v state source policy kind
    inventory=$(dpkg-query -W '-f=${binary:Package}\t${Version}\t${db:Status-Status}\t${source:Package}\n' 2>/dev/null) || { error 'Cannot read the installed package database.'; return; }
    while IFS=$'\t' read -r p v state source; do
        p=${p%%:*}
        [[ $p =~ ^(php[0-9]+\.[0-9]+(-[a-z0-9-]+)?|libapache2-mod-php[0-9]+\.[0-9]+)$ ]] || continue
        if [[ $state != installed ]]; then
            case $state in config-files|not-installed) :;; *) unknown "$p: incomplete package state; repair dpkg manually first.";; esac
            continue
        fi
        case $p in *-cli) kind=CLI;; *-fpm) kind=FPM;; *-cgi) kind=CGI;; libapache2-mod-*) kind=mod_php;; *) continue;; esac
        policy=$(apt-cache policy "$p" 2>/dev/null) || policy=''
        policy_origin "$policy" "$v"
        runtimes+=("$p|$v|$kind"); origins+=("$origin")
    done <<< "$inventory"
    ((${#runtimes[@]})) || unknown 'No packaged PHP runtime found. Install a supported Ubuntu PHP runtime or inspect your custom/container deployment.'
}
