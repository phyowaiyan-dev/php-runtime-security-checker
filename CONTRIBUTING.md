# Contributing

Use Bash 4.4+ and standard Ubuntu utilities. Keep checks read-only and secrets
out of logs. Never execute real upgrades/restarts in development tests.
Mock systemctl, apt-get, package queries and Apache validation. Add regressions
for safety bugs, unknown evidence and JSON/exit codes.

Run `bash -n` on every shell file, `shellcheck -x` on the entry point/modules/tests,
and `bash tests/run.sh`. CI uses Ruby to parse JSON; production does not.
Cross-module globals are documented by the module layout and excluded from
ShellCheck unused/undefined-global diagnostics in .shellcheckrc; other lint rules
remain enabled.

Advisory changes require authoritative source URLs, a verification date, exact
package applicability and tests. Never infer vendor vulnerability from an
upstream version alone. New dependencies, branches and package removals must
remain outside automatic remediation. Review privileged code carefully.

Open a pull request describing the problem, resulting behavior, tests and known
limitations. Do not publish releases or run production actions as part of tests.
