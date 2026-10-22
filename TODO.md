# Guided check-and-fix workflow

- [x] Inspect current package-only checker and existing tests.
- [x] Restore one guided entry point with explicit 1/0 confirmations.
- [x] Add verified candidate planning, held-package and APT transaction guards.
- [x] Validate/restart relevant active services and re-audit after remediation.
- [x] Add a compact terminal UI and remove JSON/export options.
- [x] Cover failures, unsupported versions and confirmation paths with mocks.
- [x] Update English/Burmese documentation and run syntax, lint and tests.

Development must not execute real package updates or service restarts.

## Verification

- Bash 5.3.20 syntax checks passed for every shell script.
- ShellCheck 0.11.0 passed.
- 43 mocked regression checks passed; no real APT refresh, upgrade, restart or reboot executed.
- Ubuntu CI is configured but was not run in this macOS session.
- Live Ubuntu 26.04/arm64 and maintainer-script behavior remain deployment validation tasks.

## Mixed-release repository diagnosis (1.2.1)

- [x] Reproduce reported 26.04 host / 24.04-targeted 8.3 and 8.4 builds / patched vendor 8.5.
- [x] Display per-runtime results and group repeated advisory notes by branch.
- [x] Explain unchanged candidates without claiming that upstream patches do not exist.
- [x] Block foreign-release candidates in both planner and root transaction.
- [x] Add regressions and update English/Burmese documentation.

The server's repository/pinning cause cannot be established from the provided
report alone; actual apt-cache policy output is needed. No server changes performed.

## Authorized existing-repository repair (1.3.0)

- [x] Implement bounded existing-source discovery and preview under the same confirmation.
- [x] Verify publisher signature, release and compatible fixed candidates before source edits.
- [x] Back up/atomically replace the source and roll back failed host metadata refreshes.
- [x] Cover parsing, signatures, source rollback, unavailable suites and integrated confirmation with mocks.
- [x] Update English/Burmese documentation and security policy.

Current publisher resolute endpoint returned HTTP 404 during read-only verification.
This authorization does not authorize PHP migration or allow publishing nonexistent packages.
No real source changes, APT operations, service restarts or reboots ran in development.
The private root helper still requires disposable Ubuntu integration validation.
