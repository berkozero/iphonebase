# iphonebase

Control your iPhone from the command line via macOS iPhone Mirroring.

Built for AI agents (OpenClaw, Claude Code, MCP clients) but works standalone from the terminal.

## How it works

`iphonebase` interacts with your iPhone through the iPhone Mirroring window on macOS Sequoia:

1. **Screen Capture** — captures the mirroring window via ScreenCaptureKit
2. **OCR** — uses Apple Vision to identify UI elements and their coordinates
3. **Input Injection** — sends taps, swipes, and keystrokes via Karabiner DriverKit virtual HID (the only method that bypasses Apple's CGEvent blocking on the mirroring window)

## Requirements

- macOS 15.0+ (Sequoia)
- iPhone Mirroring set up and active
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) installed (for DriverKit virtual HID)
- Screen Recording permission granted to Terminal/iTerm

## Install

```bash
git clone https://github.com/berkozero/iphonebase.git
cd iphonebase
swift build -c release
cp .build/release/iphonebase /usr/local/bin/
```

## Usage

```bash
# Check if iPhone Mirroring is active
iphonebase status

# Take a screenshot of the mirrored iPhone
iphonebase screenshot --output screen.png

# See what's on screen (OCR)
iphonebase describe

# Tap by coordinates
iphonebase tap 200 400

# Tap by text (OCR-finds the element, then taps its center)
iphonebase tap --text "Settings"

# Swipe
iphonebase swipe up
iphonebase swipe left --from 200,400

# Type text
iphonebase type "hello world"

# Press a key
iphonebase key enter
iphonebase key a --modifier cmd

# Go home
iphonebase home

# Launch an app (Spotlight search)
iphonebase launch "Messages"
```

### JSON output

Every command supports `--json` for machine consumption:

```bash
iphonebase describe --json
```

## Architecture

```
iphonebase (CLI)
└── IPhoneBaseCore (library)
    ├── WindowManager    — find/focus iPhone Mirroring window
    ├── ScreenCapture    — ScreenCaptureKit screenshot
    ├── OCREngine        — Apple Vision text recognition
    └── InputInjector    — Karabiner virtual HID input
```

## Why iPhone Mirroring?

- No need to install anything on your iPhone
- No developer account or Xcode required on the phone
- Works with any app — no WebDriverAgent, no XCTest runner
- Your phone stays locked and secure

## Limitations

- One phone at a time
- iPhone Mirroring window must be visible (steals focus during input)
- No clipboard paste (text is typed character by character)
- OCR-based element detection (no accessibility tree)
- Requires Karabiner DriverKit for input injection

## License

MIT
