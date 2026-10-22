# Security policy

Only the latest tagged release is intended to receive fixes. No release or
public repository has been published by this workspace task.

Report vulnerabilities privately to the repository maintainer through the
hosting platform's private vulnerability reporting feature when available.
If no private channel is configured, request a security contact without posting
exploit details or secrets in a public issue. There is no promised response SLA.

Include affected commit/version, Ubuntu version, minimal sanitized reproduction,
impact, and expected behavior. Never attach credentials or raw server configs.

This tool runs local package-manager commands with root only on explicit fix or
restart. Trust the checkout, APT configuration, local package database and OS.
It is not a malware detector or full server audit. Unknown findings require
manual review. Advisory updates must cite primary sources and verification dates.
