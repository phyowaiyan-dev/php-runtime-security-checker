# shellcheck shell=bash
confirm() {
    [[ $yes == 1 ]] && return 0
    [[ -t 0 ]] || { error 'Confirmation requires a terminal; use --yes after reviewing the preview.'; return 1; }
    local answer
    printf 'Proceed with PHP package updates/service restarts? [y/N] ' >&2
    read -r answer
    [[ $answer == y || $answer == Y ]]
}
modify() {
    [[ $supported == 1 ]] || { error 'Modifications require a supported Ubuntu host.'; return; }
    local p simulation action name old new rest
    local -a pinned=()
    local -a targets=()
    if [[ $mode == fix ]]; then
        ((${#packages[@]})) || { error 'No PHP packages to update.'; return; }
        for p in "${packages[@]}"; do
            if [[ $'\n'$holds$'\n' == *$'\n'"$p"$'\n'* ]]; then error "Held package: $p"; return; fi
            targets+=("$p")
        done
        simulation=$(apt-get -s --no-remove --only-upgrade install "${targets[@]}" 2>/dev/null) || { error 'APT simulation failed.'; return; }
        # Only permit upgrades of already selected installed PHP packages. No dependency additions.
        while read -r action name old new rest; do
            case $action in
                Remv) error 'APT proposed package removal.'; return;;
                Inst)
                    [[ " ${targets[*]} " == *" $name "* && $old == \[*\] ]] || { error 'APT proposed an unscoped change or new package.'; return; }
                    new=${new#(}
                    [[ $new =~ ^[0-9A-Za-z.+:~_-]+$ ]] || { error "Invalid candidate version."; return; }
                    pinned+=("$name=$new")
                    ;;
            esac
        done <<< "$simulation"
        printf 'Preview: only installed PHP packages may be upgraded:\n' >&2
        printf '  %s\n' "${targets[@]}" >&2
        printf '%s\n' "$simulation" | awk '$1=="Inst" {print $1, $2, $3, $4}' >&2
    fi
    printf 'Services to restart: %s\n' "${services[*]:-none}" >&2
    confirm || { unknown 'Modification cancelled.'; return; }
    is_root || { error 'Run the reviewed modification command as root (sudo); audit needs no root.'; return; }
    if [[ $mode == fix ]]; then
        install_packages "${pinned[@]}" || { error "APT update failed; partial changes may have occurred."; return; }
    fi
    restart_services
    ((operation_error==0)) || return
    runtimes=(); origins=(); activities=(); packages=(); services=(); results=()
    warnings=() # The final report describes the new snapshot, not superseded pre-fix findings.
    overall=PASS; service_status=PASS
    detect; audit
}

is_root() { [[ $EUID == 0 ]]; }
install_packages() {
        [[ ! -e /usr/sbin/policy-rc.d && ! -L /usr/sbin/policy-rc.d ]] || { error 'Existing policy-rc.d requires administrator-managed updates.'; return; }
        if (($#)); then
            # Keep the reviewed package set/version fixed and prevent resolver additions.
            # A temporary policy delays ordinary maintainer-script service restarts.
            if ! (
                umask 022
                set -o noclobber
                printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d || exit 1
                trap 'rm -f /usr/sbin/policy-rc.d' EXIT
                trap 'exit 1' HUP INT TERM
                chmod 755 /usr/sbin/policy-rc.d || exit 1
                DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l apt-get --no-remove --no-install-recommends --only-upgrade -y \
                    -o APT::Get::AutomaticRemove=false -o APT::Get::Upgrade-Allow-New=false \
                    install "$@" >&2
            ); then error 'APT update failed; partial changes may have occurred.'; return; fi
        fi

    ((operation_error==0))
}
