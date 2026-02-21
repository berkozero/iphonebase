# iphonebase

Swift CLI to control iPhone via macOS iPhone Mirroring. Built for AI agents (OpenClaw, Claude Code) — the CLI is a thin perceive-and-act bridge, all reasoning lives in the agent.

## Tech Stack

- Swift 5.9+, macOS 14+ (requires Sequoia 15.0+ at runtime)
- ArgumentParser 1.3.0
- Frameworks: ScreenCaptureKit, Vision, CoreGraphics, AppKit
- Karabiner-Elements required (DriverKit virtual HID for input injection)

## Build & Run

```
swift build                                        # debug
swift build -c release                             # release
swift test                                         # run tests
sudo cp .build/release/iphonebase /usr/local/bin/  # install
```

## Project Structure

```
Sources/
  IPhoneBaseCore/        # Library
    WindowManager.swift  # Find & focus iPhone Mirroring window
    ScreenCapture.swift  # ScreenCaptureKit capture + grid overlay
    OCREngine.swift      # Apple Vision text recognition
    InputInjector.swift  # Karabiner DriverKit virtual HID input
    HIDKeyMap.swift      # USB HID keycodes & character mappings
    ActionResult.swift   # Shared JSON response envelope
  iphonebase/            # CLI executable
    IPhoneBase.swift     # Entry point, command registration
    Commands/            # One file per command (11 commands)
skills/
  iphonebase/SKILL.md   # OpenClaw skill definition
Tests/
  IPhoneBaseCoreTests/   # Unit tests
```

## Design Philosophy

**Perceive → Reason → Act.** The CLI provides two things:
1. **Perception:** `perceive --json` returns screenshot + OCR + grid metadata
2. **Actions:** `tap`, `swipe`, `scroll`, `drag`, `type`, `key`, `home`

The agent (LLM) does all reasoning. No OCR-based decision-making in the CLI.

## Commands (11)

| Category | Commands |
|----------|----------|
| **Perceive** | `perceive`, `screenshot`, `status`, `doctor` |
| **Act** | `tap`, `swipe`, `scroll`, `drag`, `type`, `key`, `home` |

## Adding a New Command

1. Create `Sources/iphonebase/Commands/XxxCommand.swift`
2. Implement `AsyncParsableCommand` (or `ParsableCommand` for sync-only)
3. Add `XxxCommand.self` to the `subcommands` array in `IPhoneBase.swift`
4. Include `--json` flag using the shared `ActionResult<T>` envelope
5. Update `skills/iphonebase/SKILL.md` with the new command docs
6. Action commands must be "dumb executors" — no embedded OCR or reasoning

## Code Conventions

- Import order: ArgumentParser, IPhoneBaseCore, Foundation
- All commands support `--json` via shared `ActionResult<T>` envelope (`Sources/IPhoneBaseCore/ActionResult.swift`)
- Results to stdout, debug/verbose to stderr
- InputInjector pattern: `connect()` then `defer { disconnect() }`; set `windowBounds` for coordinate validation
- Call `wm.bringToFront()` before any input injection
- Errors: typed enums with `CustomStringConvertible`; throw `ExitCode.failure` for user errors
- Commit messages: imperative mood ("Add feature" not "Added feature"), first line under 72 characters

## Coordinate System (critical)

- ScreenCapture captures at 2x retina resolution (image pixels)
- OCR (Vision) returns normalized coords with bottom-left origin — `OCREngine` inverts Y
- `perceive` scales all coordinates (OCR elements + grid cells) to **window-relative screen points**
- `tap x y` expects window-relative screen points — coordinates from `perceive` flow directly
- All InputInjector operations use absolute screen coordinates (`window.bounds.origin + offset`)

## Input Injection Gotchas

- iPhone Mirroring accepts CGEvent mouse input for taps
- Swipe/drag uses Karabiner HID pointing click-drag (CGEvent scroll wheel is ignored)
- Tap sequence: `CGWarpMouseCursorPosition` → CGEvent mouseDown/mouseUp
- Timing delays (`usleep`) throughout InputInjector are tuned values, not arbitrary
- Karabiner daemon must be running (not just installed)

## OpenClaw Skill

- Skill at `skills/iphonebase/SKILL.md` follows AgentSkills spec (YAML frontmatter + markdown)
- Requires `bins: ["iphonebase"]`, `os: ["darwin"]`
- Install to `~/.openclaw/skills/` for agent discovery
