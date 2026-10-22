# shellcheck shell=bash
read_os() {
    local key value
    os_id=unknown; os_version=unknown; os_name=unknown
    while IFS='=' read -r key value; do
        value=${value#\"}; value=${value%\"}
        case $key in ID) os_id=$value;; VERSION_ID) os_version=$value;; PRETTY_NAME) os_name=$value;; esac
    done < /etc/os-release
}
detect() {
    read_os
    arch=$(dpkg --print-architecture 2>/dev/null) || arch=unknown
    case $os_id:$os_version:$arch in ubuntu:22.04:amd64|ubuntu:22.04:arm64|ubuntu:24.04:amd64|ubuntu:24.04:arm64|ubuntu:26.04:amd64|ubuntu:26.04:arm64) :;; *) unknown 'Unsupported OS or architecture.';; esac
    local inventory p v state policy kind
    inventory=$(dpkg-query -W '-f=${binary:Package}\t${Version}\t${db:Status-Status}\n' 2>/dev/null) || { error 'Cannot enumerate packages.'; return; }
    while IFS=$'\t' read -r p v state; do
        [[ $state == installed ]] || continue
        p=${p%%:*}
        [[ $p =~ ^(php[0-9]+\.[0-9]+(-[a-z0-9-]+)?|libapache2-mod-php[0-9]+\.[0-9]+)$ ]] || continue
        case $p in *-cli) kind=CLI;; *-fpm) kind=FPM;; *-cgi) kind=CGI;; libapache2-mod-*) kind=mod_php;; *) continue;; esac
        policy=$(apt-cache policy "$p" 2>/dev/null) || policy=''
        # Attribute only the installed version's version-table block. Never expose repository URLs.
        local origin=unknown
        if printf '%s\n' "$policy" | awk -v ver="$v" '
            $1=="***" {inblock=($2==ver); next}
            NF==2 && $1 ~ /^[0-9]/ && $2 ~ /^[0-9]+$/ {inblock=0}
            inblock && /https?:\/\/([a-z][a-z]\.)?(archive\.ubuntu\.com|security\.ubuntu\.com|ports\.ubuntu\.com)\// {found=1}
            END {exit !found}'; then origin=Ubuntu
        elif [[ $v == *+deb.sury.org+* ]] && printf '%s\n' "$policy" | awk -v ver="$v" '
            $1=="***" {b=($2==ver); next}
            NF==2 && $1 ~ /^[0-9]/ && $2 ~ /^[0-9]+$/ {b=0}
            b && /https?:\/\/ppa\.launchpad(content)?\.net\/ondrej\/php\// {ok=1}
            END {exit !ok}'; then origin=Ondrej-PPA
        fi
        runtimes+=("$p|$v|$kind"); origins+=("$origin")
    done <<< "$inventory"
    if ((${#runtimes[@]}==0)); then unknown 'No packaged PHP runtime found.'; fi
}
