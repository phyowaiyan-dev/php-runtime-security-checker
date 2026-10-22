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
    case $os_id:$os_version:$arch in ubuntu:22.04:amd64|ubuntu:22.04:arm64|ubuntu:24.04:amd64|ubuntu:24.04:arm64|ubuntu:26.04:amd64|ubuntu:26.04:arm64) supported=1;; *) supported=0; unknown 'Unsupported OS or architecture.';; esac
    local inventory p v state policy kind active path owner
    inventory=$(dpkg-query -W '-f=${binary:Package}\t${Version}\t${db:Status-Status}\n' 2>/dev/null) || { error 'Cannot enumerate packages.'; return; }
    holds=$(apt-mark showhold 2>/dev/null) || { holds=''; unknown 'Cannot inspect package holds.'; }
    while IFS=$'\t' read -r p v state; do
        [[ $state == installed ]] || continue
        p=${p%%:*}
        [[ $p =~ ^(php[0-9]+\.[0-9]+(-[a-z0-9-]+)?|libapache2-mod-php[0-9]+\.[0-9]+)$ ]] || continue
        packages+=("$p")
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
        active=unknown
        case $kind in
            FPM) active=$(systemctl is-active "$p" 2>/dev/null) || active=inactive; services+=("$p");;
            mod_php) active=installed; services+=(apache2);;
            CLI) active=installed;; CGI) active=unknown; unknown 'CGI handler and process lifecycle require manual review.';;
        esac
        runtimes+=("$p|$v|$kind"); origins+=("$origin"); activities+=("$active")
    done <<< "$inventory"
    if ((${#runtimes[@]}==0)); then unknown 'No packaged PHP runtime found.'; fi
    for path in /usr/local/bin/php /usr/local/sbin/php-fpm /opt/php/bin/php; do
        [[ ! -e $path ]] || unknown 'Custom PHP executable detected; outside package audit scope.'
    done
    path=$(command -v php || true)
    if [[ -n $path ]]; then
        owner=$(dpkg-query -S "$(readlink -f "$path")" 2>/dev/null) || owner=''
        [[ -n $owner ]] || unknown 'Default PHP command is not owned by a Debian package.'
    fi
    if [[ -e /.dockerenv ]] || systemctl is-active --quiet docker 2>/dev/null; then unknown 'Docker/container runtime detected; container PHP is outside scope.'; fi
    detect_reboot /var/run/reboot-required
    for p in apache2 nginx; do
        if systemctl is-active --quiet "$p" 2>/dev/null; then
            warn "$p is active; virtual hosts, remote upstreams and custom handlers need manual inspection."
            unknown 'Web handler coverage cannot be proven automatically.'
        fi
    done
    # Inspect names/counts only; never print configuration contents.
    local files
    files=$(find /etc/apache2/mods-enabled /etc/nginx/sites-enabled /etc/php -type f -o -type l 2>/dev/null) || true
    [[ -z $files ]] || warn 'Web/PHP configuration exists; confirm enabled handlers and FPM socket routing manually.'
}
remaining_updates() {
    local p policy candidate installed
    for p in "${packages[@]}"; do
        policy=$(apt-cache policy "$p" 2>/dev/null) || { unknown 'Cannot inspect PHP update candidates.'; continue; }
        installed=$(printf '%s\n' "$policy" | awk '$1=="Installed:" {print $2}')
        candidate=$(printf '%s\n' "$policy" | awk '$1=="Candidate:" {print $2}')
        if [[ -n $candidate && $candidate != '(none)' && -n $installed ]]; then
            if dpkg --compare-versions "$candidate" gt "$installed"; then warn "PHP package update remains available: $p"; fi
        else warn "PHP package candidate unavailable: $p"; fi
    done
}

detect_reboot() {
    reboot=NO
    [[ ! -e $1 ]] || reboot=REQUIRED
    return 0
}
