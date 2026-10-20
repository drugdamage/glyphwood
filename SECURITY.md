# Security Policy

Glyphwood is a single-player offline game: it does not use the network or
accounts, and saves are local files. Security issues are still possible, for
example in the build pipeline (GitHub Actions) or in the install scripts
(`install.sh`, `install.ps1`) that download releases from GitHub.

## Supported versions

Only the [latest release](https://github.com/drugdamage/glyphwood/releases/latest)
and the `main` branch receive fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's
[private vulnerability reporting](https://github.com/drugdamage/glyphwood/security/advisories/new)
instead (**Security → Report a vulnerability**).

Include what you found, how to reproduce it, and the affected version or commit.
You can expect an initial reply within a week. Once a fix is released, you will
be credited in the release notes unless you prefer otherwise.

Ordinary bugs such as crashes or glitches are not security issues; please report
them with the [bug report form](https://github.com/drugdamage/glyphwood/issues/new?template=bug_report.yml).
