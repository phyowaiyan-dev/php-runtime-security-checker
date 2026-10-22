# Changelog

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
