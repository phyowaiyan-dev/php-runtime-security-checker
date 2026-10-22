# Existing-repository repair verification

Checked 2026-10-22 against publisher sources:

- https://launchpad.net/~ondrej/+archive/ubuntu/php
  Publishes the Ondrej PHP PPA URL and primary signing fingerprint:
  `B8DC7E53946656EFBCE4C1DD71DAEAAB4AD4CAB6`.
- https://ppa.launchpadcontent.net/ondrej/php/ubuntu/dists/
  The live index listed jammy and noble, but not resolute, at verification time.
- https://ppa.launchpadcontent.net/ondrej/php/ubuntu/dists/resolute/InRelease
  A direct read-only HTTPS request returned HTTP 404 at verification time.
- https://ppa.launchpadcontent.net/ondrej/php/ubuntu/dists/noble/InRelease
  Publisher metadata identifies Origin `LP-PPA-ondrej-php`, Codename `noble`
  and architecture availability. Reading this page alone is not signature validation;
  actual restoration uses local gpgv verification before trusting its contents.

This is a dated observation, not a permanent support declaration. The private helper
checks availability and authenticity again at runtime. It never substitutes noble
metadata for a resolute host, fetches a new key, disables authentication or claims
that signature verification alone proves application compatibility. A publisher key
rotation requires a reviewed update and matching trusted local key; unknown keys fail closed.
