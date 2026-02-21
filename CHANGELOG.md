# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `perceive` now saves screenshots to `/tmp/iphonebase/` as files and returns paths in JSON (much smaller output)
- `perceive --base64` flag for inline base64 image data (OpenClaw compatibility)
- `perceive` now generates grid-overlay screenshot (`screen-grid.png`) alongside raw screenshot
- `doctor` command — diagnostic check of all prerequisites (8 checks)
- `scroll` command — scroll up/down via mouse wheel with configurable clicks
- `drag` command — smooth point-to-point drag with configurable steps
- `--json` flag on all commands via shared `ActionResult<T>` envelope
- `AGENTS.md` for cross-agent (Cursor, Codex, Copilot) compatibility
- `SECURITY.md` vulnerability disclosure policy
- `CHANGELOG.md`
- PR template

### Changed
- Agent-first refactor: CLI is now a thin perceive-and-act bridge, all reasoning lives in the agent
- All commands now return structured `ActionResult` JSON with `success`, `action`, `data`, `error`, `durationMs`
- `perceive` grid cell coordinates now use window-relative screen points (matching OCR elements)
- Improved input injection reliability with tuned timing and nudge-sync sequence
- README rewritten with badges, agent quick start, comparison table

### Removed
- `describe` command — redundant with `perceive --json` which includes OCR elements
- `wait-for` command — agents should use perceive polling loops for full screen visibility
- `launch` command — agents orchestrate app launching via Spotlight (`key 3 --modifier cmd` + `type` + `key enter`)
- `tap --text` option — agents use coordinates from `perceive` with `tap x y`

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
