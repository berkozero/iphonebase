# iphonebase

Swift CLI to control iPhone via macOS iPhone Mirroring. Built for AI agents (OpenClaw, Claude Code, MCP) and standalone terminal use.

## Tech Stack
- Swift 5.9+, macOS 14+ (requires Sequoia 15.0+ at runtime)
- ArgumentParser 1.3.0
- Frameworks: ScreenCaptureKit, Vision, CoreGraphics, AppKit
- Karabiner-Elements required (DriverKit virtual HID for input injection)

## Build & Run
swift build                                    # debug
swift build -c release                         # release
sudo cp .build/release/iphonebase /usr/local/bin/  # install

## Project Structure
- Sources/IPhoneBaseCore/ — library: WindowManager, ScreenCapture, OCREngine, InputInjector, HIDKeyMap
- Sources/iphonebase/ — CLI entry point + Commands/
- skills/iphonebase/ — OpenClaw skill definition (SKILL.md)

## Adding a New Command
1. Create Sources/iphonebase/Commands/XxxCommand.swift
2. Implement AsyncParsableCommand (or ParsableCommand for sync-only)
3. Add XxxCommand.self to subcommands array in IPhoneBase.swift
4. Include --json flag for structured output

## Code Conventions
- Import order: ArgumentParser, IPhoneBaseCore, Foundation
- All commands support --json (use JSONSerialization with .prettyPrinted)
- Results to stdout, debug/verbose to stderr
- InputInjector pattern: connect() then defer { disconnect() }
- Call wm.bringToFront() before any input injection
- Errors: typed enums with CustomStringConvertible; throw ExitCode.failure for user errors

## Coordinate System (critical)
- ScreenCapture captures at 2x retina resolution
- OCR (Vision) returns normalized coords with bottom-left origin — must invert Y
- tap --text handles conversion automatically; raw tap x y is relative to window (screen points)
- All InputInjector operations use absolute screen coordinates (window.bounds.origin + offset)

## Input Injection Gotchas
- iPhone Mirroring blocks CGEvent clicks — only Karabiner virtual HID works
- Tap sequence: CGWarp cursor → nudge-sync virtual pointer (3x 1px/-1px) → click via HID
- Timing delays (usleep) throughout InputInjector are tuned values, not arbitrary
- Karabiner daemon must be running (not just installed)

## OpenClaw Skill
- Skill at skills/iphonebase/SKILL.md follows AgentSkills spec (YAML frontmatter + markdown)
- Requires bins: ["iphonebase"], os: ["darwin"]
- Install to ~/.openclaw/skills/ for agent discovery

## Commits
- Imperative mood ("Add feature" not "Added feature")
- First line under 72 characters
