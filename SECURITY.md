# Security Policy

## ⚠️ Intentionally Vulnerable Repository

This repository is a fork of [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) maintained for **security training and CTF (Capture The Flag) purposes**.

It **intentionally contains** malicious/vulnerable sample files, such as PHP web shells under [`Upload Insecure Files/Extension PHP/`](Upload%20Insecure%20Files/Extension%20PHP/). These files are reference material used to demonstrate web application vulnerabilities and are **not** part of any running production application. See [DISCLAIMER.md](DISCLAIMER.md) for the full usage disclaimer.

Because of this, standard SAST/secret-scanning findings for the `Upload Insecure Files/` directory are **expected** and should not be treated as evidence of a compromise. Static analysis and security scanning policies should scope out (allow-list) this repository, or at minimum the `Upload Insecure Files/` directory, to avoid false-positive alerting. This exclusion is configured in [`.github/codeql/codeql-config.yml`](.github/codeql/codeql-config.yml).

## Reporting a Vulnerability

If you believe you have found a vulnerability in the tooling/automation of this repository itself (as opposed to the intentionally vulnerable sample payloads it hosts), please open an issue describing the problem.

Do **not** attempt to exploit any of the sample payloads against systems you do not own or have explicit authorization to test.
