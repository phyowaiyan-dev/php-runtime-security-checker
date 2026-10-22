# PHP Runtime Security Checker

Check PHP, review a repair, apply verified updates and check again—from one terminal command.
Focused on **CVE-2026-109618** and **CVE-2026-109619** in PHP runtimes used by Laravel and other PHP applications.

## Run

```sh
git clone https://github.com/phyowaiyan-dev/php-runtime-security-checker.git
cd php-runtime-security-checker
bash bin/php-security-check
```

Requires Bash 4.4+, Ubuntu 22.04 / 24.04 / 26.04, amd64 / arm64, dpkg, APT
and standard Ubuntu utilities. Guided FPM/Apache repair requires systemd.
Start as your normal user: sudo is requested only after you approve a repair.
Use a trusted local checkout. No Composer, Python, Node.js or JSON/export setup.

## One command, one confirmation

1. **Check.** Detect the OS and installed PHP runtimes; compare both CVEs with documented upstream/vendor fixes.
2. **Review.** If a fix may be needed, show the installed core PHP packages in scope, their cached candidate plan when verifiable, and the active services to restart.
3. **Choose.** Enter `1` / `yes` to authorize the whole scoped repair, or `0` / `no` / Enter to exit unchanged. Invalid input is asked again. Sudo may separately request your password.
4. **Repair.** Refresh APT metadata, display the final verified version plan, simulate it, install only allowed updates, validate configuration and restart the affected active services.
5. **Verify.** Check packages again and show the final result, including after a partial failure. No second confirmation is required.

The confirmation authorizes metadata refresh and verified updates **within the displayed package/service scope**. Final versions can differ from the cached preview after refresh. If the refreshed plan needs broader changes, it stops. A patched system exits immediately without root, metadata refresh or restarts.

```text
PHP Runtime Security Checker  1.2.0
  Ubuntu 24.04.5 LTS  |  amd64
  ------------------------------------------------------------
  php8.4-cli                8.4.27-1+ubuntu24.04.1+deb.sury.org+1
  php8.4-fpm                8.4.27-1+ubuntu24.04.1+deb.sury.org+1

  CVE-2026-109618           PASS
  CVE-2026-109619           PASS
  Package result            PASS
  No package fix needed for these two CVEs.
```

Repair menu:

```text
Refresh, apply verified PHP patches and restart the listed services?
  [1] Continue    [0] No / exit
  Choice [0]:
```

Terminal status colors are automatic. `NO_COLOR` or `--no-color` disables them;
redirected output stays plain. Optional `--check` is strictly read-only; `--fix`
opens the same guided flow. `--help` and `--version` are available. JSON, export,
standalone restart and unconfirmed `--yes` modes are intentionally absent.
Piped/noninteractive runs only report; they cannot authorize modifications.

## Results and blocked repairs

| Result / exit | Meaning |
| --- | --- |
| PASS / 0 | Installed packages meet the documented baselines for these two CVEs |
| FAIL / 1 | A package is below a verified Ubuntu vendor fix |
| UNKNOWN / 2 | Insufficient package/platform evidence, including unsupported PHP or unverified backports |
| ERROR / 3 | Check, authorization, APT, configuration validation or restart failed |

A declined repair retains the original check result. A failed operation overrides
a package PASS: partially upgraded packages do not make a failed repair green.

- **Old/EOL PHP:** a documented Ubuntu vendor backport can pass even when upstream support has ended. Otherwise it stops with manual migration guidance. It never switches PHP branches for you.
- **No fixed candidate:** it explains that no verified patch is available from configured repositories. A newer version below the baseline is not called a fix.
- **Unknown provenance/backport:** it does not invent vulnerability facts. An unindexed installed version can be replaced by a verified Ubuntu/PPA candidate after consent; changing a known vendor origin is blocked.
- **Held packages, incomplete dpkg state, missing dependencies, unsupported OS/architecture or unmanaged CGI:** it stops rather than unholding packages, installing dependencies or guessing process management.

Ubuntu vendor revisions use Debian version comparisons. Recognized Ondrej PPA
candidates use verified upstream baselines. Local APT metadata and distributor
version claims must be trusted; binary contents are not independently attested.
See [advisory sources and verification date](data/SOURCES.md).

## Repair boundaries

Only already-installed core packages from an affected `phpX.Y` source are eligible.
Third-party extensions, unrelated packages, new packages and removals are excluded.
No autoremove, full/dist upgrade, repository installation, branch change or reboot.
Versions are pinned and the simulation is checked again in the root transaction.
Signed-repository authentication remains APT's responsibility; the tool never
allows unauthenticated packages or downgrades. Do not run concurrent package
managers or alter APT configuration during repair.

Ordinary maintainer-script service restarts are delayed with a temporary
`/usr/sbin/policy-rc.d`; an existing administrator policy blocks repair and is
never replaced. Cleanup runs on normal exit/signals. SIGKILL or power loss may
leave this file behind; inspect and remove only the temporary checker-created
file before retrying. Administrator APT hooks/nonconforming scripts can still
have side effects. Existing conffiles are preserved using APT/dpkg options.

Active FPM and Apache mod_php services in the repair scope are configuration-tested
before installation and again before restart. Inactive services stay stopped.
Restart verification requires a new systemd MainPID, a later monotonic start and
active state, not activity alone. This confirms the managed restart, not application
health or exhaustive worker freshness. Configuration output is suppressed to avoid
exposing secrets. Failure messages direct you to local APT/dpkg or systemd logs;
no automatic rollback or reboot is attempted.

**Scope:** two PHP CVEs and installed package evidence. PASS does not certify an
entire server, Laravel/Composer dependencies, custom/container PHP, remote handlers,
Octane or pre-existing queue workers. Application-specific worker restarts remain
the operator's responsibility. No web-handler parser or repeated generic warnings.

## Development

```sh
for file in bin/php-security-check lib/*.sh tests/*.sh examples/*.sh; do
    bash -n "$file" || exit
done
shellcheck -x bin/php-security-check lib/*.sh tests/*.sh examples/*.sh
bash tests/run.sh
```

Privileged calls are mocked; tests never run real APT refresh/upgrades or service
restarts. macOS uses a limited version-comparison fixture fallback; Ubuntu CI uses
real dpkg comparisons. CI covers Ubuntu 22.04/24.04; live 26.04/arm64 deployment
validation and real maintainer-script behavior remain separate verification tasks.

For a YouTube demo, use a disposable VM/snapshot: show a patched check, a simulated
repair, `0` to cancel and `1` to approve only inside the demo VM. Do not show private
application data. MIT licensed; see [Burmese README](README.my.md),
[SECURITY.md](SECURITY.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

Implementation references: [Ubuntu APT manual](https://manpages.ubuntu.com/manpages/noble/man8/apt-get.8.html),
[systemd service properties](https://freedesktop.org/software/systemd/man/latest/org.freedesktop.systemd1.html).
