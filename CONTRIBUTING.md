# Contributing to iphonebase

Thanks for your interest in contributing! Here's how to get started.

## Reporting Bugs

Open a [GitHub issue](https://github.com/berkozero/iphonebase/issues/new?template=bug_report.md) with:

- What you ran (command + flags)
- What you expected
- What actually happened
- macOS version, iPhone model, and Karabiner-Elements version

If a command fails silently, re-run with `--verbose` (where supported) and include the stderr output.

For security vulnerabilities, see [SECURITY.md](SECURITY.md).

## Suggesting Features

Open a [feature request](https://github.com/berkozero/iphonebase/issues/new?template=feature_request.md). Describe the use case, not just the solution.

## Development Setup

```bash
git clone https://github.com/berkozero/iphonebase.git
cd iphonebase
swift build
swift test
```

Requirements:
- macOS 15.0+ (Sequoia)
- Xcode 16+ or Swift 6.0+ toolchain
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) installed
- iPhone Mirroring active (for testing)

## Submitting Changes

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `swift build` and `swift test`
4. Test against a real iPhone Mirroring session
5. Open a pull request with a clear description of what and why

### When Adding or Changing Commands

- Update `skills/iphonebase/SKILL.md` with the new command docs
- Add an entry to `CHANGELOG.md` under `[Unreleased]`
- Ensure `--json` output works via the `ActionResult<T>` envelope

### Code Style

- Follow existing conventions (see [AGENTS.md](AGENTS.md) for details)
- Keep functions focused and small
- Write to stderr for debug/verbose output, stdout for results

### Commit Messages

- Use imperative mood ("Add feature" not "Added feature")
- First line under 72 characters
- Explain *why*, not just *what*, in the body if needed
