# Advisory provenance

Verified 2026-10-22 against primary publisher pages. This is a static snapshot,
not an automatically refreshed vulnerability database.

- PHP security advisory, 21 October 2026:
  https://www.php.net/archive/2026.php#2026-10-21-5
  Confirms both CVE IDs, web-facing SAPIs, and fixed 8.2.35, 8.3.36,
  8.4.27 and 8.5.12 releases. Earlier releases in those branches require
  an upstream fix or vendor backport. PHP 8.1 and older are upstream EOL;
  a vendor can still maintain a branch.
- Publisher technical advisories:
  https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
  https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
  Linked by PHP; these technical pages were not independently inspected.
- Ubuntu USN-8948-1, 21 October 2026:
  https://ubuntu.com/security/notices/USN-8948-1
  Both CVEs; enumerates cli, cgi, fpm and libapache2-mod packages:
  - 22.04: 8.1.2-1ubuntu2.28
  - 24.04: 8.3.6-0ubuntu0.24.04.13
  - 26.04: 8.5.4-0ubuntu1.5

TSV mappings apply only to those runtime package families, Ubuntu release,
installed-version archive provenance and matching source-base version. Debian
revision comparisons use dpkg. Unrecognized source bases, epochs, mirrors,
origins and older PPA builds remain UNKNOWN rather than guessed vulnerable.
PPA fixed upstream baselines assume the package distributor preserved the
upstream fixes; this tool does not authenticate binary contents.

Do not extend the table from version resemblance alone. Confirm source,
release, exact binary package applicability and vendor revisions. New PHP
branches and advisories default to UNKNOWN.
