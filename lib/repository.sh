# shellcheck shell=bash
PPA_URI=https://ppa.launchpadcontent.net/ondrej/php/ubuntu
PPA_FINGERPRINT=B8DC7E53946656EFBCE4C1DD71DAEAAB4AD4CAB6
ubuntu_suite() {
    case $os_version in 22.04) suite=jammy;; 24.04) suite=noble;; 26.04) suite=resolute;; *) return 1;; esac
}
# Supported input: one dedicated PPA stanza with an existing file-based Signed-By.
# Reject ambiguous sources and trust-bypass options rather than rewriting them.
read_ppa_source() {
    local file=$1 line key value body='' count=0 options item
    ppa_suite=''; ppa_key=''; ppa_enabled=yes; ppa_arch=''
    [[ -f $file && ! -L $file && -r $file ]] || return 1
    case $file in
        *.list)
            while IFS= read -r line || [[ -n $line ]]; do
                line=${line#"${line%%[![:space:]]*}"}
                if [[ $line == '#'* ]]; then
                    line=${line#\#}; line=${line#"${line%%[![:space:]]*}"}
                    [[ $line == deb\ * ]] || continue
                    ppa_enabled=no
                fi
                [[ -n $line ]] || continue
                count=$((count+1)); ((count==1)) || return 1
                local pattern='^deb[[:space:]]+\[([^]]+)\][[:space:]]+https?://ppa\.launchpad(content)?\.net/ondrej/php/ubuntu/?[[:space:]]+([a-z]+)[[:space:]]+main[[:space:]]*$'
                [[ $line =~ $pattern ]] || return 1
                options=${BASH_REMATCH[1]}; ppa_suite=${BASH_REMATCH[3]}
                for item in $options; do
                    case $item in signed-by=*) ppa_key=${item#*=};; arch=*) ppa_arch=${item#*=};; *) return 1;; esac
                done
            done < "$file";;
        *.sources)
            local ended=0 started=0 seen=' '
            while IFS= read -r line || [[ -n $line ]]; do
                [[ $line != '#'* ]] || continue
                if [[ -z $line ]]; then ((started==0)) || ended=1; continue; fi
                ((ended==0)) || return 1
                [[ $line != [[:space:]]* && $line == *:* ]] || return 1
                key=${line%%:*}; value=${line#*:}; value=${value#"${value%%[![:space:]]*}"}
                [[ $seen != *" $key "* ]] || return 1
                seen+="$key "; started=1
                case $key in
                    Types) [[ $value == deb ]] || return 1;;
                    URIs) [[ $value =~ ^https?://ppa\.launchpad(content)?\.net/ondrej/php/ubuntu/?$ ]] || return 1;;
                    Suites) ppa_suite=$value;; Components) [[ $value == main ]] || return 1;;
                    Signed-By) ppa_key=$value;; Enabled) [[ $value == yes || $value == no ]] || return 1; ppa_enabled=$value;;
                    Architectures) ppa_arch=${value// /,};;
                    *) return 1;;
                esac
            done < "$file"
            for key in Types URIs Suites Components Signed-By; do [[ $seen == *" $key "* ]] || return 1; done;;
        *) return 1;;
    esac
    [[ $ppa_suite =~ ^[a-z]+$ && $ppa_key =~ ^/(etc/apt/keyrings|usr/share/keyrings)/[A-Za-z0-9_.-]+\.gpg$ ]] || return 1
    [[ -z $ppa_arch || $ppa_arch =~ ^(amd64|arm64)(,(amd64|arm64))*$ ]] || return 1
}
repository_source_files() {
    local file
    for file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [[ ! -f $file ]] || printf '%s\n' "$file"
    done
}
repository_digest() { sha256sum -- "$1" | awk '{print $1}'; }
discover_repository_repair() {
    repo_file=''; repo_digest=''; repo_old_suite=''; repo_key=''; repo_suite=''
    local files file selected='' key old
    ubuntu_suite || return 0
    files=$(repository_source_files) || return 0
    # Multiple PPA definitions cannot safely be normalized by this bounded repair.
    local matches=0
    while IFS= read -r file; do
        [[ -n $file ]] || continue
        grep -Eq 'ppa\.launchpad(content)?\.net/ondrej/php/ubuntu' "$file" 2>/dev/null || continue
        matches=$((matches+1))
        read_ppa_source "$file" || return 0
        if [[ $ppa_suite != "$suite" || $ppa_enabled == no ]]; then
            selected=$file; key=$ppa_key; old=$ppa_suite
        fi
    done <<< "$files"
    [[ $matches == 1 && -n $selected ]] || return 0
    repo_digest=$(repository_digest "$selected" 2>/dev/null) || return 0
    [[ $repo_digest =~ ^[0-9a-f]{64}$ ]] || { repo_digest=''; return 0; }
    repo_file=$selected; repo_key=$key; repo_old_suite=$old; repo_suite=$suite
}
write_ppa_source() {
    local format=$1 target=$2 key=$3 architecture=$4
    if [[ $format == *.list ]]; then
        printf 'deb ['
        [[ -z $architecture ]] || printf 'arch=%s ' "$architecture"
        printf 'signed-by=%s] %s %s main\n' "$key" "$PPA_URI" "$target"
    else
        printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: main\n' "$PPA_URI" "$target"
        [[ -z $architecture ]] || printf 'Architectures: %s\n' "${architecture//,/ }"
        printf 'Signed-By: %s\nEnabled: yes\n' "$key"
    fi
}
# Called only after the same confirmation that authorizes package repair.
restore_repository() {
    local package version kind i code
    local -a affected=()
    for ((i=0;i<${#runtimes[@]};i++)); do
        IFS='|' read -r package version kind <<< "${runtimes[i]}"
        package_branch "$package"
        [[ " ${fix_branches[*]} " != *" $branch "* ]] || affected+=("$package")
    done
    message "Verifying and restoring the existing PHP repository for $repo_suite..."
    code=0
    run_root bash "$BASE/lib/repository-transaction.sh" "$repo_file" "$repo_digest" "${affected[@]}" >/dev/null 2>&1 || code=$?
    case $code in
        0) workflow_note="Existing PHP repository restored for $repo_suite; its backup is beside the original source file."; return 0;;
        71) workflow_note="The publisher provides no retrievable signed PHP repository for $repo_suite (or the network is unavailable). Repository and packages were not changed. APT cannot patch these branches on this release.";;
        72) workflow_note='Repository signature, release, architecture or fixed candidate verification failed. Repository and packages were not changed.';;
        73) workflow_note='Existing repository configuration/key changed, is ambiguous or is not securely owned. No repository repair performed.';;
        74) workflow_note='APT refresh failed after repository restoration; the previous source was restored. No packages installed.';;
        75) workflow_note='Repository rollback failed. Inspect the source file and its checker backup before any package operation.';;
        *) workflow_note='Repository repair failed; no PHP package install attempted. Inspect the source and checker backup locally.';;
    esac
    action_error=1
    return 1
}

verify_ppa_release() {
    local release=$1 key=$2 target=$3 architecture=$4 signature available
    signature=$(gpgv --status-fd 1 --keyring "$key" "$release" 2>/dev/null) || return 1
    awk -v fp="$PPA_FINGERPRINT" '$2=="VALIDSIG" && ($3==fp || $NF==fp) {ok=1} END {exit !ok}' <<< "$signature" || return 1
    [[ $(awk '/^Origin:/ {print $2}' "$release") == LP-PPA-ondrej-php ]] || return 1
    [[ $(awk '/^Codename:/ {print $2}' "$release") == "$target" ]] || return 1
    available=$(awk '/^Architectures:/ {$1=""; print}' "$release")
    [[ " $available " == *" $architecture "* ]]
}
source_permissions() { chmod --reference="$1" "$2"; }
replace_ppa_source() {
    local file=$1 target=$2 key=$3 architecture=$4
    backup=$(mktemp "$file.php-security-checker.XXXXXXXX.bak") || return 1
    cp -p -- "$file" "$backup" || return 1
    replacement=$(mktemp "$file.php-security-checker.XXXXXXXX.tmp") || return 1
    write_ppa_source "$file" "$target" "$key" "$architecture" > "$replacement" || return 1
    source_permissions "$file" "$replacement" || return 1
    changed=1
    mv -f -- "$replacement" "$file"
}
rollback_ppa_source() {
    local file=$1
    ((changed && !committed)) || return 0
    cp -p -- "$backup" "$replacement" && mv -f -- "$replacement" "$file"
}
