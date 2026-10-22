#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$BASE/lib/common.sh"
# shellcheck source=../lib/repository.sh
source "$BASE/lib/repository.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
count=0
assert() { "$@" || { printf 'FAIL repository: %s\n' "$*" >&2; exit 1; }; }
ok() { count=$((count+1)); printf 'ok repository %d - %s\n' "$count" "$1"; }
cat > "$TMP/php.sources" <<'SOURCE'
Types: deb
URIs: https://ppa.launchpadcontent.net/ondrej/php/ubuntu/
Suites: jammy
Components: main
Signed-By: /etc/apt/keyrings/ondrej.gpg
Enabled: no
SOURCE
assert read_ppa_source "$TMP/php.sources"
assert test "$ppa_suite" = jammy
assert test "$ppa_enabled" = no
ok 'disabled dedicated deb822 source is recognized'
printf '# deb [signed-by=/usr/share/keyrings/ondrej.gpg arch=amd64] https://ppa.launchpad.net/ondrej/php/ubuntu jammy main\n' > "$TMP/php.list"
assert read_ppa_source "$TMP/php.list"
assert test "$ppa_enabled" = no
assert test "$ppa_arch" = amd64
ok 'commented legacy source with explicit key is recognized'
cp "$TMP/php.sources" "$TMP/original"
printf '\nTypes: deb\nURIs: https://other.example/\n' >> "$TMP/php.sources"
if read_ppa_source "$TMP/php.sources"; then exit 1; fi
cp "$TMP/original" "$TMP/php.sources"
printf 'Trusted: yes\n' >> "$TMP/php.sources"
if read_ppa_source "$TMP/php.sources"; then exit 1; fi
cp "$TMP/original" "$TMP/php.sources"
ln -s "$TMP/php.sources" "$TMP/link.sources"
if read_ppa_source "$TMP/link.sources"; then exit 1; fi
ok 'multiple stanzas, trust bypass and symlinks are refused'
# shellcheck disable=SC2329
repository_source_files() { printf '%s\n' "$TMP/php.sources"; }
# macOS fixtures use its equivalent hash utility. Production uses Ubuntu sha256sum.
# shellcheck disable=SC2329
repository_digest() {
    if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'
}
os_version=24.04
discover_repository_repair
assert test "$repo_file" = "$TMP/php.sources"
assert test "$repo_old_suite" = jammy
assert test "$repo_suite" = noble
ok 'preview identifies the exact existing file, digest and host suite'
# shellcheck disable=SC2329
repository_source_files() { printf '%s\n' "$TMP/php.sources" "$TMP/php.list"; }
discover_repository_repair
assert test -z "$repo_file"
ok 'duplicate PPA definitions require manual resolution'
write_ppa_source "$TMP/php.sources" noble /etc/apt/keyrings/ondrej.gpg '' > "$TMP/generated.sources"
assert read_ppa_source "$TMP/generated.sources"
assert test "$ppa_suite" = noble
assert test "$ppa_enabled" = yes
assert test -z "$ppa_arch"
ok 'canonical restoration preserves unrestricted architectures and existing key'
cat > "$TMP/InRelease" <<'RELEASE'
Origin: LP-PPA-ondrej-php
Codename: noble
Architectures: amd64 arm64
RELEASE
MOCK_SIGNATURE=good
# shellcheck disable=SC2329
gpgv() {
    [[ $MOCK_SIGNATURE != bad ]] || return 1
    if [[ $MOCK_SIGNATURE == foreign ]]; then printf '[GNUPG:] VALIDSIG FOREIGN\n'
    else printf '[GNUPG:] VALIDSIG %s\n' "$PPA_FINGERPRINT"; fi
}
assert verify_ppa_release "$TMP/InRelease" /test/key noble amd64
if verify_ppa_release "$TMP/InRelease" /test/key resolute amd64; then exit 1; fi
if verify_ppa_release "$TMP/InRelease" /test/key noble riscv64; then exit 1; fi
MOCK_SIGNATURE=bad
if verify_ppa_release "$TMP/InRelease" /test/key noble amd64; then exit 1; fi
MOCK_SIGNATURE=foreign
if verify_ppa_release "$TMP/InRelease" /test/key noble amd64; then exit 1; fi
ok 'missing/foreign signatures, wrong release and architecture cannot authorize restoration'
# Actual backup/atomic replace/rollback operations touch fixture files only.
# shellcheck disable=SC2329
source_permissions() { chmod 644 "$2"; }
backup=''; replacement=''; changed=0; committed=0
replace_ppa_source "$TMP/php.sources" noble /etc/apt/keyrings/ondrej.gpg ''
assert cmp "$TMP/original" "$backup"
assert read_ppa_source "$TMP/php.sources"
assert test "$ppa_suite" = noble
rollback_ppa_source "$TMP/php.sources"
assert cmp "$TMP/original" "$TMP/php.sources"
ok 'source replacement creates an exact backup and rollback restores the original'
# Controller error handling mocks every privileged operation, including HTTP 404.
# shellcheck disable=SC2329
message() { :; }
# shellcheck disable=SC2329
run_root() { return "$MOCK_CODE"; }
runtimes=('php8.4-cli|8.4.26|CLI'); fix_branches=(8.4)
repo_file="$TMP/php.sources"; repo_digest=fixture; repo_suite=resolute
for MOCK_CODE in 71 72 73 74 75; do
    action_error=0
    if restore_repository; then exit 1; fi
    assert test "$action_error" = 1
done
ok '404/network, signature, source-change, refresh and rollback failures stop package installation'
printf '%d repository checks passed; no network or privileged host operations executed.\n' "$count"
