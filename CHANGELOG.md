# Changelog

## 1.2.0 — Unreleased

- Restore guided check, scope preview, one 1/0 confirmation, fix and automatic recheck.
- Refresh APT after consent; verify candidate provenance/baselines and pin core PHP upgrades.
- Block holds, incomplete transactions, new packages/removals and unsupported/unverified repairs.
- Validate FPM/Apache configuration, preserve inactive services and verify new systemd main processes.
- Add a private guarded root transaction and concise color-aware terminal report.
- Remove JSON/export modes; retain read-only --check and guided --fix aliases.
- Keep package PASS distinct from whole-server/application/worker security.

## 1.1.0 — Unreleased

- Simplify to a read-only installed PHP package check for the two documented CVEs.
- Remove update/restart commands, handler/freshness audits and reboot reporting.
- Summarize each CVE once and deduplicate unknown mapping notes.
- Keep vendor-backport checks, provenance evidence, JSON and safe output files.
- PASS explicitly covers installed packages, not Laravel dependencies or workers.

## 1.0.0 — Unreleased

- Initial Ubuntu PHP package audit, two documented CVEs and vendor mappings.
- Conservative unknown handling, JSON/human reports and separate reboot state.
- Confirmed, scoped package upgrades and validated local service restarts.
- Mocked tests, CI, English/Burmese documentation and security policy.
