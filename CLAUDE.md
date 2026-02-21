# iphonebase

Swift CLI to control iPhone via macOS iPhone Mirroring. See also [AGENTS.md](AGENTS.md) for cross-agent instructions.

## Build & Test
```
swift build                  # debug
swift build -c release       # release
swift test                   # tests
```

## Project Structure
- `Sources/IPhoneBaseCore/` — library: WindowManager, ScreenCapture, OCREngine, InputInjector, HIDKeyMap, ActionResult
- `Sources/iphonebase/` — CLI entry point + Commands/
- `skills/iphonebase/` — OpenClaw skill (SKILL.md)

## Adding a New Command
1. Create `Sources/iphonebase/Commands/XxxCommand.swift`
2. Implement `AsyncParsableCommand` (or `ParsableCommand` for sync-only)
3. Add `XxxCommand.self` to subcommands array in `IPhoneBase.swift`
4. Include `--json` flag for structured output
5. Update `skills/iphonebase/SKILL.md`

## Code Conventions
- Import order: ArgumentParser, IPhoneBaseCore, Foundation
- All commands support `--json` via shared `ActionResult<T>` envelope
- Results to stdout, debug/verbose to stderr
- InputInjector pattern: `connect()` then `defer { disconnect() }`; set `windowBounds` for coordinate validation
- Call `wm.bringToFront()` before any input injection
- Errors: typed enums with `CustomStringConvertible`; throw `ExitCode.failure` for user errors

## Design Philosophy
- **Perceive → Reason → Act:** `perceive` gives AI eyes, action commands are hands, AI does all reasoning
- No OCR-based decision-making in action commands — agent provides coordinates from `perceive`
- Action commands are "dumb executors": `tap x y`, `swipe up`, `type "text"`

## Coordinate System (critical)
- ScreenCapture captures at 2x retina resolution
- OCR (Vision) returns normalized coords with bottom-left origin — must invert Y
- `perceive` scales all coordinates to window-relative screen points
- `tap x y` expects window-relative screen points — coordinates from `perceive` flow directly
- All InputInjector operations use absolute screen coordinates (`window.bounds.origin + offset`)

## Input Injection Gotchas
- iPhone Mirroring blocks CGEvent clicks — only Karabiner virtual HID works
- Tap sequence: CGWarp cursor → nudge-sync (3x 1px/-1px) → click via HID
- Timing delays (`usleep`) are tuned values, not arbitrary
- Karabiner daemon must be running (not just installed)

## Commits
- Imperative mood ("Add feature" not "Added feature")
- First line under 72 characters
