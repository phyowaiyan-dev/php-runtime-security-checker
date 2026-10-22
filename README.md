# PHP Runtime Security Checker

A minimal, read-only check for two PHP runtime CVEs affecting PHP applications,
including Laravel:

- CVE-2026-109618
- CVE-2026-109619

It checks **installed Ubuntu PHP packages**, not Laravel/Composer dependencies,
application code, web-server configuration or running-worker freshness.

## Usage

Requires Bash 4.4+, dpkg and apt-cache on Ubuntu 22.04 / 24.04 / 26.04
(amd64 / arm64). No root, Composer, Python, Node.js or network request is needed.

```sh
git clone https://github.com/phyowaiyan-dev/php-runtime-security-checker.git
cd php-runtime-security-checker
bash bin/php-security-check --check
bash bin/php-security-check --json
bash bin/php-security-check --output report.txt
```

Default mode is `--check`. `--help`, `--version` and `--no-color` are supported.
Reports use no terminal colors. Output files are private and existing files are
never overwritten. JSON includes per-package versions, origins and CVE results.

## Example

For the reported PHP packages, with their PPA origin verified in local APT metadata:

```text
PHP Runtime Security Checker v1.1.0
OS: Ubuntu 24.04.5 LTS (amd64)
PHP CLI: 8.4.27-1+ubuntu24.04.1+deb.sury.org+1
PHP FPM: 8.4.27-1+ubuntu24.04.1+deb.sury.org+1
CVE-2026-109618: PASS
CVE-2026-109619: PASS
Overall: PASS (PHP package checks)
Scope: Installed PHP packages only; Laravel dependencies and running workers are not checked.
```

Each CVE line summarizes all detected runtime packages. JSON retains individual
package results. There are no Apache handler, service, reboot or repeated generic
warning sections. An unknown package mapping produces one note per package.

| Result / exit | Meaning |
| --- | --- |
| PASS / 0 | Installed packages meet the documented baselines for these two CVEs |
| FAIL / 1 | A package is below a verified Ubuntu vendor fix |
| UNKNOWN / 2 | Package origin/backport mapping, platform or PHP inventory is unverified |
| ERROR / 3 | Invalid command, package query or report output failure |

Ubuntu backports use exact documented source/revision mappings. Recognized PPA
packages use upstream fixed-version baselines. Older PPA builds and unknown
origins remain UNKNOWN because their backports cannot be inferred. Provenance
comes from the installed version's local APT policy block; binary contents are
not independently authenticated. See [sources and verification date](data/SOURCES.md).

## Safety and scope

Version 1.1 removes `--fix`, `--restart` and `--yes`, along with service/handler
inspection. It never upgrades packages, restarts services, reads application
secrets or executes PHP. There are no automatic remediation commands.

PASS applies only to installed package evidence for the two named CVEs. It does
not certify Laravel, a server, containers, custom PHP builds or the PHP actually
loaded by workers. If packages were recently updated, manage any required PHP-FPM,
Apache and Laravel worker restarts separately. Those operations are outside this
checker's scope.

## Development

```sh
for file in bin/php-security-check lib/*.sh tests/*.sh examples/*.sh; do
    bash -n "$file" || exit
done
shellcheck -x bin/php-security-check lib/*.sh tests/*.sh examples/*.sh
bash tests/run.sh
```

Tests use package fixtures and reject accidental service/package modifications.
Ruby parses JSON in CI; it is not a runtime dependency. macOS tests use a limited
version-comparison mock; Ubuntu CI uses real dpkg comparisons. No live server
remediation is performed. For a video demo, show the read-only check, JSON output
and tests on a disposable VM without displaying private application data.

MIT license. See [Burmese README](README.my.md), [security policy](SECURITY.md)
and [contributing guide](CONTRIBUTING.md).
