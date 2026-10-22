#!/usr/bin/env bash
# Read-only video demo. Guided repair is available from the main command in a terminal.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 3
bash bin/php-security-check --check
status=$?
printf '\nAudit exit code: %s\n' "$status"
exit "$status"
