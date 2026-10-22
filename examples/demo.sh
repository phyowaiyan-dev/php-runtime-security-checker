#!/usr/bin/env bash
# Read-only demo. No privileged modifications.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 3
bash bin/php-security-check --check
status=$?
printf 'Audit exit code: %s\n' "$status"
bash bin/php-security-check --json
