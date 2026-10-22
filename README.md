# PHP Runtime Security Checker

An open-source Bash CLI tool to check PHP runtime security vulnerabilities and apply security patches on Ubuntu servers.

**Supported CVEs:**

- CVE-2026-109618
- CVE-2026-109619

**Requirements:** Ubuntu 22.04 / 24.04 / 26.04, supported PHP 8.x versions, Bash 4.4+ (amd64 / arm64).

## Installation

```bash
git clone https://github.com/phyowaiyan-dev/php-runtime-security-checker.git
cd php-runtime-security-checker
```

## Usage

**1. Check PHP Security**

```bash
bash bin/php-security-check --check
```

**2. Apply Security Updates**

```bash
sudo bash bin/php-security-check --fix
```

**3. Apply Updates Without Confirmation**

```bash
sudo bash bin/php-security-check --fix --yes
```

**4. Restart Apache / PHP-FPM**

```bash
sudo bash bin/php-security-check --restart
```

**5. Generate JSON Report**

```bash
bash bin/php-security-check --json
```

## Security Check Results

| Status | Description |
| --- | --- |
| ✅ PASS | Verified patches are installed for the checked CVEs |
| ❌ FAIL | Required security patches are missing |
| ⚠️ UNKNOWN | Insufficient information to verify patch status |
| ❗ ERROR | Security check or update operation failed |

## Important Notes

- Back up or snapshot your server before applying updates.
- Security checks are read-only by default and do not require root access.
- PHP security updates may require restarting Apache or PHP-FPM.
- A **PASS** result does not guarantee that the entire server is secure.
- This tool currently checks only the two listed PHP runtime CVEs.

**License:** MIT

## Service freshness and Apache handler coverage

`Services: PASS` now requires both **Restart freshness: PASS** and **Web handler
coverage: PASS**. A successful restart outside this tool can satisfy the check;
there is no requirement to restart again through this CLI. Service activity
alone never proves that patched PHP is loaded. CVE package results, service
results and reboot state remain separate. Overall stays UNKNOWN if any required
evidence is missing, even when both CVE package checks pass.

The earlier implementation only trusted an in-memory `restarted` flag set during
that invocation. Every new read-only audit lost that flag. It also marked every
active Apache/Nginx deployment unknown without examining handlers and retained
superseded warnings after remediation. Those paths have been replaced; the final
post-remediation report uses fresh findings.

Freshness checks use systemd MainPID, wall-clock and monotonic main-process start
times, cross-checked against kernel `/proc` start times. Every process in the
service's cgroup v2 subtree must be inspectable and newer than the local package
and configuration change bounds. These bounds use dpkg installation `.list`
metadata and package files' modification/change times, including symlink changes,
rather than assuming that an upstream release-file timestamp is an install time.
FPM configuration directories are included to catch removed pool configurations.
Missing metadata, timestamp ties, inconsistent clocks, process churn or unsupported
cgroup layouts remain UNKNOWN. These are trusted local filesystem bounds, not
cryptographic attestation or an exact historical package transaction log.

The checker verifies packaged executable identity, rejects deleted code mappings,
and checks Apache's mapped PHP modules. Anonymous OPcache shared memory marked
`/dev/zero (deleted)` does not itself imply stale PHP code. Custom service launch
paths, PHP ini environment overrides and external FPM pool includes require manual
review. Package metadata and process membership are checked again after inspection
to avoid accepting an obviously changing snapshot.

For Apache it examines the enabled include tree (`apache2ctl -t -D DUMP_INCLUDES`)
and configured modules, including directives inside enabled VirtualHosts. Standard
mod_php handlers must map to an installed, audited PHP module and its loaded
process mappings. Standard `SetHandler "proxy:unix:/run/php/...sock|fcgi://localhost/"`
handlers must resolve to a socket actually held by an audited local FPM master;
the filename alone is insufficient. Apache must also postdate its inspected
configuration and include directories. This is a conservative supported subset,
not a complete Apache configuration interpreter.

TCP/remote FPM, dynamic handlers, rewrite proxy/handler overrides, `.htaccess`
handler permissions, custom module paths, directory-style/dynamic includes,
unreadable configs and Nginx upstreams remain unverified. They produce a **Web
handler coverage unverified** warning, not a request to repeat an already verified
FPM restart. Inspect the enabled VirtualHost and any listed class of override;
do not disable security checks merely to force PASS.

Example when restart evidence is sound but a VirtualHost uses an unresolved
remote handler:

```text
Restart freshness: PASS
Web handler coverage: UNKNOWN
Services: UNKNOWN
Reboot: NO
Overall: UNKNOWN
WARNING: Web handler coverage unverified: ... review enabled VirtualHost overrides.
```

If process evidence cannot be read, the message is **restart freshness unverified**
with a suggested evidence check. Inspect package metadata and `/proc` permissions
and retry a stable read-only snapshot. Running `sudo bash bin/php-security-check
--check` can provide read access to root-owned process evidence; it still performs
no package changes or restarts. An actual start time predating package/config
changes warrants reviewing and, if needed, restarting that particular service.
A graceful Apache reload can retain old workers and is not equivalent to proving
a full fresh process set.

JSON preserves `services.status` and adds `services.freshness`,
`services.handler_coverage`, and per-service `services.evidence`. Human reports
show the two dimensions explicitly. Development tests include externally restarted
PHP 8.4.27, mixed mod_php/FPM, stale workers, failed evidence, VirtualHost overrides
and anonymous/deleted mappings. Run:

```sh
for file in bin/php-security-check lib/*.sh tests/*.sh examples/*.sh; do
    bash -n "$file" || exit
done
shellcheck -x bin/php-security-check lib/*.sh tests/*.sh examples/*.sh
bash tests/run.sh
```

The evidence probes are mocked in development; a real unprivileged `/proc` parser
check additionally runs on Linux. No APT upgrade or real service restart is needed
for these tests. Live Ubuntu service validation is still a separate deployment step.

Implementation references: [systemd properties](https://www.freedesktop.org/software/systemd/man/latest/systemctl),
[Apache FPM handler syntax](https://httpd.apache.org/docs/2.4/mod/mod_proxy_fcgi.html),
and [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php).
