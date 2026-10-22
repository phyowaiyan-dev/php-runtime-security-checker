# shellcheck shell=bash
branch_has_fix() {
    local wanted=$1 id b fixed release vendor verified
    while IFS=$'\t' read -r id b fixed release vendor verified; do
        [[ $id == CVE-2026-109618 && $b == "$wanted" ]] || continue
        [[ $fixed != '-' || $release == "$os_version" ]] && return 0
    done < "$BASE/data/advisories.tsv"
    return 1
}
runtime_passes() {
    local cve
    for cve in CVE-2026-109618 CVE-2026-109619; do
        assess "$1" "$2" "$3" "$cve"
        [[ $assessment == PASS ]] || return 1
    done
}
prepare_scope() {
    scope_rows=(); fix_services=(); scope_service_states=(); fix_branches=(); plan_rows=(); pins=(); block_reason=''
    local i p v kind branch source state policy core_origin holds
    ((supported)) || { block_reason='Automatic repair is unavailable on this OS/architecture.'; return 1; }
    for ((i=0;i<${#runtimes[@]};i++)); do
        IFS='|' read -r p v kind <<< "${runtimes[i]}"
        runtime_passes "$p" "$v" "${origins[i]}" && continue
        package_branch "$p"
        branch_has_fix "$branch" || { block_reason="PHP $branch has no verified supported fix here. Migrate the PHP branch manually; no branch switch will be attempted."; return 1; }
        [[ " ${fix_branches[*]} " == *" $branch "* ]] || fix_branches+=("$branch")
    done
    ((${#fix_branches[@]})) || { block_reason='No eligible PHP branch needs automatic repair.'; return 1; }
    # Only installed core packages from the affected PHP source are in the approved scope.
    while IFS=$'\t' read -r p v state source; do
        p=${p%%:*}
        [[ $state == installed ]] || continue
        [[ $source =~ ^php([0-9]+\.[0-9]+)$ ]] || continue
        branch=${BASH_REMATCH[1]}
        [[ " ${fix_branches[*]} " == *" $branch "* ]] || continue
        [[ $p =~ ^(php[0-9]+\.[0-9]+(-[a-z0-9-]+)?|libapache2-mod-php[0-9]+\.[0-9]+)$ ]] || { block_reason='Unexpected PHP source package name; manual review required.'; return 1; }
        policy=$(apt-cache policy "$p" 2>/dev/null) || { block_reason='Cannot read PHP package policies.'; return 1; }
        policy_origin "$policy" "$v"; core_origin=$origin
        scope_rows+=("$p|$v|$core_origin")
    done <<< "$inventory"
    ((${#scope_rows[@]})) || { block_reason='PHP source-package metadata is unavailable; no automatic repair planned.'; return 1; }
    # All runtime packages on the changed branch must be represented; CGI has no managed lifecycle here.
    for ((i=0;i<${#runtimes[@]};i++)); do
        IFS='|' read -r p v kind <<< "${runtimes[i]}"
        package_branch "$p"
        [[ " ${fix_branches[*]} " == *" $branch "* ]] || continue
        [[ $kind != CGI ]] || { block_reason='CGI process management is outside automatic repair; update and recycle it manually.'; return 1; }
        [[ " ${scope_rows[*]} " == *" $p|$v|"* ]] || { block_reason="$p is outside the verified PHP source scope."; return 1; }
        case $kind in FPM) add_fix_service "$p" || return 1;; mod_php) add_fix_service apache2 || return 1;; esac
    done
    holds=$(apt-mark showhold 2>/dev/null) || { block_reason='Cannot inspect held packages.'; return 1; }
    check_holds "$holds" || return 1
    if ! transaction_policy_available; then
        block_reason='An existing policy-rc.d requires administrator-managed repair; it will not be replaced.'; return 1
    fi
    discover_repository_repair
    approved_inventory=$inventory
}
check_holds() {
    local row p v o held
    for row in "${scope_rows[@]}"; do
        IFS='|' read -r p v o <<< "$row"
        while IFS= read -r held; do
            [[ ${held%%:*} != "$p" ]] || { block_reason="Held package $p blocks repair; no hold will be removed."; return 1; }
        done <<< "$1"
    done
}
# Candidates must be newer and verified; known installed origins cannot silently change.
build_plan() {
    pins=(); plan_rows=()
    local row p installed old_origin policy candidate candidate_origin i v kind chosen chosen_origin extra
    for row in "${scope_rows[@]}"; do
        IFS='|' read -r p installed old_origin <<< "$row"
        policy=$(apt-cache policy "$p" 2>/dev/null) || { block_reason="Cannot read candidate for $p."; return 1; }
        candidate=$(awk '$1=="Candidate:" {print $2}' <<< "$policy")
        [[ $candidate =~ ^[0-9][A-Za-z0-9.+:~_-]*$ ]] || { block_reason="No installable candidate for $p in configured repositories."; return 1; }
        dpkg --compare-versions "$candidate" gt "$installed" || continue
        if ! release_matches_host "$candidate"; then
            block_reason="$p candidate targets Ubuntu $build_release, but this host is $os_version. Configure a compatible repository or migrate manually; no cross-release package will be installed."; return 1
        fi
        policy_origin "$policy" "$candidate"; candidate_origin=$origin
        [[ $candidate_origin != unknown && ( $old_origin == unknown || $candidate_origin == "$old_origin" ) ]] || { block_reason="$p candidate changes or lacks verified provenance; automatic origin changes are blocked."; return 1; }
        pins+=("$p=$candidate"); plan_rows+=("$p|$installed|$candidate|$candidate_origin")
    done
    ((${#pins[@]})) || { explain_no_candidates; return 1; }
    for ((i=0;i<${#runtimes[@]};i++)); do
        IFS='|' read -r p v kind <<< "${runtimes[i]}"
        package_branch "$p"
        [[ " ${fix_branches[*]} " == *" $branch "* ]] || continue
        chosen=$v; chosen_origin=${origins[i]}
        for row in "${scope_rows[@]}"; do
            [[ $row != "$p|"* ]] || IFS='|' read -r extra extra chosen_origin <<< "$row"
        done
        for row in "${plan_rows[@]}"; do
            [[ $row != "$p|"* ]] || IFS='|' read -r extra extra chosen chosen_origin <<< "$row"
        done
        runtime_passes "$p" "$chosen" "$chosen_origin" || { block_reason="No verified fixed candidate for $p yet. No packages changed."; return 1; }
    done
}
validate_simulation() {
    local simulation=$1 action name old candidate rest row p v o expected seen=' '
    while read -r action name old candidate rest; do
        case $action in
            Remv|Purg) block_reason='APT proposed package removal; repair refused.'; return 1;;
            Inst)
                candidate=${candidate#(}
                [[ " ${pins[*]} " == *" $name=$candidate "* && $old == \[*\] ]] || { block_reason='APT proposed a new/unapproved package or an unreviewed version.'; return 1; }
                expected=''
                for row in "${scope_rows[@]}"; do
                    IFS='|' read -r p v o <<< "$row"
                    [[ $p != "$name" ]] || expected=$v
                done
                [[ -n $expected && $old == "[$expected]" && $seen != *" $name "* ]] || { block_reason='APT installed-version evidence changed or is incomplete.'; return 1; }
                seen+="$name ";;
            Conf)
                [[ " ${pins[*]} " == *" $name="* ]] || { block_reason='APT proposed configuring an unrelated package.'; return 1; };;
        esac
    done <<< "$simulation"
    for row in "${pins[@]}"; do
        [[ $seen == *" ${row%%=*} "* ]] || { block_reason='APT did not confirm every pinned upgrade.'; return 1; }
    done
}
simulate_plan() {
    local simulation
    simulation=$(apt-get -s --no-remove --no-install-recommends --only-upgrade \
        -o APT::Get::AutomaticRemove=false install "${pins[@]}" 2>/dev/null) || { block_reason='APT simulation failed (dependencies, locks or unavailable versions). No package update attempted.'; return 1; }
    validate_simulation "$simulation"
}
show_scope() {
    local row p v o
    heading 'Repair scope'
    for row in "${scope_rows[@]}"; do IFS='|' read -r p v o <<< "$row"; message "$p  (installed $v)"; done
    message "Active services to restart: ${fix_services[*]:-none}"
    message 'Refresh APT metadata, then install only verified same-source PHP upgrades in this scope.'
message 'No removals, new packages or PHP branch changes are allowed.'
    if [[ -n $repo_file ]]; then
        message "Repository repair: $repo_file ($repo_old_suite -> $repo_suite, enabled)."
        message "Existing signing key: $repo_key. A backup is created before the atomic source replacement."
        message 'The publisher signature, host release and fixed candidates must verify before any source edit.'
    else message 'No repository change planned.'; fi
    message 'Unverified installed provenance can only be replaced with a verified Ubuntu/PPA candidate.'
    message 'Service restarts may briefly interrupt PHP requests. Inactive services stay stopped.'
}
show_plan() {
    local row p old new candidate_origin
    heading 'Verified update plan'
    for row in "${plan_rows[@]}"; do
        IFS='|' read -r p old new candidate_origin <<< "$row"
        message "$p"
        message "  $old -> $new"
    done
}
repair() {
    local pending
    if ! authorize_root; then action_error=1; workflow_note='Root authorization failed; no changes made.'; return; fi
    if [[ -n $repo_file ]]; then
        restore_repository || return 0
    else
        message 'Refreshing package lists...'
    fi
    # Fail even on partial repository/network errors, rather than silently using stale indexes.
    if [[ -z $repo_file ]] && ! run_root apt-get -o APT::Update::Error-Mode=any -o Acquire::AllowInsecureRepositories=false -o Acquire::AllowDowngradeToInsecureRepositories=false update >/dev/null 2>&1; then
        action_error=1; workflow_note='APT refresh failed or root authorization was denied. No package update attempted; inspect repository/network access.'; return
    fi
    snapshot
    if [[ $inventory != "$approved_inventory" || $supported != 1 || $overall == ERROR ]]; then
        action_error=1; workflow_note='Installed package/platform state changed during planning. Repair stopped; run the command again.'; return
    fi
    if [[ $overall == PASS ]]; then
        if [[ -n $repo_file ]]; then workflow_note="Repository restored for $repo_suite; packages meet the baselines. Backup retained beside $repo_file."
        else workflow_note='Packages already meet the verified baselines; no update needed.'; fi
        return
    fi
    pending=$(dpkg --audit 2>/dev/null) || { action_error=1; workflow_note='Cannot inspect dpkg state.'; return; }
    if [[ -n $pending ]]; then action_error=1; workflow_note='dpkg has incomplete transactions. Repair them manually first.'; return; fi
    local holds
    holds=$(apt-mark showhold 2>/dev/null) || { action_error=1; workflow_note='Cannot inspect package holds.'; return; }
    if ! check_holds "$holds" || ! build_plan || ! simulate_plan; then workflow_note=$block_reason; return; fi
    show_plan
    if ! validate_services; then action_error=1; workflow_note=$service_error; return; fi
    message 'Installing the verified PHP updates...'
    if ! run_root bash "$BASE/lib/transaction.sh" "${pins[@]}" >/dev/null 2>&1; then
        action_error=1; workflow_note='PHP update failed or safety checks refused it. Partial package changes are possible; inspect APT/dpkg state. No automatic restart attempted.'; return
    fi
    if ! validate_services || ! restart_services; then
        action_error=1; workflow_note=$service_error; return
    fi
    if ((${#fix_services[@]})); then restart_note="Restarted and active: ${fix_services[*]}"
    else restart_note='No active PHP-serving services needed a restart.'; fi
    workflow_note='Repair completed; installed packages were checked again.'
    [[ -z $repo_file ]] || workflow_note+=" Repository restored for $repo_suite; backup retained beside $repo_file."
    return 0
}
workflow() {
    snapshot
    report_human
    [[ $mode != check && $overall != PASS && $overall != ERROR ]] || return 0
    if ! prepare_scope; then message "$block_reason"; return 0; fi
    if ! is_interactive; then message 'No changes made. Run this command in a terminal to review and confirm repair.'; return 0; fi
    show_scope
    if build_plan; then
        show_plan
        message 'Cached-metadata preview; final versions are revalidated after refresh within this same scope.'
    else
        message "$block_reason"
        message 'Refresh may reveal a verified fix. Nothing is installed unless the final plan passes all checks.'
    fi
    if ! confirm 'Refresh, apply verified PHP patches and restart the listed services?'; then
        message 'Cancelled. No changes made.'; return 0
    fi
    repair
    # Always obtain a new package snapshot, including after failed/partial operations.
    snapshot
    if ((action_error)); then overall=ERROR
    elif [[ $workflow_note == 'Repair completed;'* && $overall != PASS ]]; then
        workflow_note='Installation finished, but the CVE baselines remain unverified. Manual review is required.'
    fi
    report_human
}

transaction_policy_available() { [[ ! -e /usr/sbin/policy-rc.d && ! -L /usr/sbin/policy-rc.d ]]; }

explain_no_candidates() {
    local entry p installed kind branch policy candidate seen=' '
    block_reason='APT offers no newer eligible candidate for the unresolved PHP branches. No packages changed.'
    for entry in "${runtimes[@]}"; do
        IFS='|' read -r p installed kind <<< "$entry"
        package_branch "$p"
        [[ " ${fix_branches[*]} " == *" $branch "* && $seen != *" $branch "* ]] || continue
        seen+="$branch "
        policy=$(apt-cache policy "$p" 2>/dev/null) || policy=''
        candidate=$(awk '$1=="Candidate:" {print $2}' <<< "$policy")
        block_reason+=$'\n  '"PHP $branch: installed $installed; APT candidate ${candidate:-unavailable}."
        if ! release_matches_host "$installed"; then
            block_reason+=$'\n  '"This installed build targets Ubuntu $build_release; the host is $os_version."
        fi
        block_reason+=$'\n  '"Inspect: apt-cache policy $p"
    done
    block_reason+=$'\n  '"Review repositories for Ubuntu $os_version and APT pinning. This is not proof that no upstream patch exists."
    block_reason+=$'\n  '"A patched different PHP branch does not patch these installed runtimes. No automatic branch switch or removal is attempted."
}
