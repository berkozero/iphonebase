# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `doctor` command — diagnostic check of all prerequisites (8 checks)
- `wait-for` command — poll screen via OCR until text appears or timeout
- `scroll` command — scroll up/down via mouse wheel with configurable clicks
- `drag` command — smooth point-to-point drag with configurable steps
- `--json` flag on all commands via shared `ActionResult<T>` envelope
- `AGENTS.md` for cross-agent (Cursor, Codex, Copilot) compatibility
- `SECURITY.md` vulnerability disclosure policy
- `CHANGELOG.md`
- PR template

### Changed
- All commands now return structured `ActionResult` JSON with `success`, `action`, `data`, `error`, `durationMs`
- Improved input injection reliability with tuned timing and nudge-sync sequence
- README rewritten with badges, agent quick start, comparison table

## [0.1.0] - 2025-01-20

### Added
- Initial release
- `status` command — check iPhone Mirroring availability
- `screenshot` command — capture screen as PNG with optional grid overlay
- `describe` command — OCR text detection with coordinates and confidence
- `tap` command — tap by coordinates, text (OCR), or grid cell; double-tap and long-press support
- `swipe` command — directional swipe with configurable start point and distance
- `type` command — character-by-character text input via virtual HID
- `key` command — named key press with modifier support (cmd, shift, opt, ctrl)
- `home` command — navigate to iPhone home screen
- `launch` command — open app by name via Spotlight search
- `IPhoneBaseCore` library: WindowManager, ScreenCapture, OCREngine, InputInjector, HIDKeyMap
- OpenClaw skill definition (`skills/iphonebase/SKILL.md`)
- GitHub Actions CI (build + test on macOS 15)
- Unit tests for HIDKeyMap

[Unreleased]: https://github.com/berkozero/iphonebase/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/berkozero/iphonebase/releases/tag/v0.1.0
