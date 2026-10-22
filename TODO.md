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
- 28 mocked regression checks passed; no real APT refresh, upgrade, restart or reboot executed.
- Ubuntu CI is configured but was not run in this macOS session.
- Live Ubuntu 26.04/arm64 and maintainer-script behavior remain deployment validation tasks.
