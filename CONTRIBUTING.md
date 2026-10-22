# Contributing

Use Bash 4.4+ and standard Ubuntu utilities. Keep the public workflow centered on
one guided check/confirm/fix/recheck command. Preserve explicit terminal consent,
narrow PHP source-package scope and conservative evidence handling. Do not add
unrelated checks, web-handler interpreters, JSON/export modes or warning spam.

Never run real APT refresh/upgrades or service restarts during development tests.
Mock run_root, authorization and package/systemd probes. Do not execute the private
root transaction against a real development host. Test cancellations, failures,
partial updates, missing patches and unsafe resolver plans.

Run Bash syntax checks for every script, ShellCheck and `bash tests/run.sh` as
shown in README.md. Linux tests use real dpkg version comparisons; macOS uses a
limited fixture fallback. Cross-module unused/undefined-global lint diagnostics
are excluded in .shellcheckrc; other lint checks remain enabled.

Advisory changes need authoritative sources, exact package/release applicability,
verification dates and tests. Never infer a vendor vulnerability from an upstream
number alone. Privileged transaction changes require careful review and disposable
Ubuntu VM validation before production release. Do not publish automatically.
