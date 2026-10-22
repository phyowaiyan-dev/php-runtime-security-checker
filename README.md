# PHP Runtime Security Checker

An open-source Bash CLI tool to check PHP runtime security vulnerabilities and apply security patches on Ubuntu servers.

**Supported CVEs:**

- CVE-2026-109618
- CVE-2026-109619

**Requirements:** Ubuntu 22.04 / 24.04 / 26.04, supported PHP 8.x versions, Bash 4.4+ (amd64 / arm64).

## Installation

```bash
git clone https://github.com/phyowaiyan-dev/php-runtime-security-checker.git
cd php-runtime-security-checker
```

## Usage

**1. Check PHP Security**

```bash
bash bin/php-security-check --check
```

**2. Apply Security Updates**

```bash
sudo bash bin/php-security-check --fix
```

**3. Apply Updates Without Confirmation**

```bash
sudo bash bin/php-security-check --fix --yes
```

**4. Restart Apache / PHP-FPM**

```bash
sudo bash bin/php-security-check --restart
```

**5. Generate JSON Report**

```bash
bash bin/php-security-check --json
```

## Security Check Results

| Status | Description |
| --- | --- |
| ✅ PASS | Verified patches are installed for the checked CVEs |
| ❌ FAIL | Required security patches are missing |
| ⚠️ UNKNOWN | Insufficient information to verify patch status |
| ❗ ERROR | Security check or update operation failed |

## Important Notes

- Back up or snapshot your server before applying updates.
- Security checks are read-only by default and do not require root access.
- PHP security updates may require restarting Apache or PHP-FPM.
- A **PASS** result does not guarantee that the entire server is secure.
- This tool currently checks only the two listed PHP runtime CVEs.

**License:** MIT
