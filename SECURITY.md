# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in iphonebase, **please report it responsibly**.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, use [GitHub's private vulnerability reporting](https://github.com/berkozero/iphonebase/security/advisories/new) to submit your report. This ensures the issue is handled privately until a fix is available.

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix**: Dependent on severity — critical issues are prioritized

## Scope

The following are in scope:

- Command injection via CLI arguments
- Unauthorized access to iPhone Mirroring input
- Socket communication vulnerabilities (Karabiner HID interface)
- Information disclosure through screenshots or OCR output

The following are out of scope:

- Vulnerabilities in macOS, iPhone Mirroring, or Karabiner-Elements themselves (report to Apple or Karabiner maintainers)
- Issues requiring physical access to the machine

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest  | Yes       |

## Disclosure

We follow [coordinated disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure). Once a fix is released, we will credit the reporter (unless anonymity is requested) and publish an advisory.
