# Security policy

Only the latest tagged release is intended to receive fixes. Report vulnerabilities
privately through the repository host's private reporting feature when available.
Otherwise request a security contact without posting exploit details or secrets.
There is no promised response SLA.

Include version/commit, Ubuntu version, sanitized reproduction, impact and expected
behavior. Never attach credentials, raw application data or full configurations.

The guided command is read-only until a terminal user approves its displayed
PHP repair scope. It can then refresh APT metadata, upgrade verified installed PHP
core packages and restart affected active systemd services. Trust the local
checkout, advisory data, APT configuration, installed package database and OS.
Root executes the checkout's private transaction script; use a trusted directory.

The temporary policy-rc.d delays conventional maintainer-script restarts. It does
not sandbox administrator APT hooks or malicious/nonconforming package scripts.
An existing policy is preserved by refusing automatic repair. SIGKILL/power loss
may require manual cleanup of a checker-created policy file. Package failures
can leave partial changes; there is no automatic rollback. Never run concurrent
package managers during a repair.

PASS concerns installed package evidence for the two documented PHP CVEs. It
is not a server, Laravel dependency, binary attestation or exhaustive worker audit.
Unknown findings require manual review. Advisory changes require primary sources,
verification dates and regression tests.
