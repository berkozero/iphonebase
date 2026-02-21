# iphonebase

[![CI](https://github.com/berkozero/iphonebase/actions/workflows/ci.yml/badge.svg)](https://github.com/berkozero/iphonebase/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

**Control your iPhone from the command line via macOS iPhone Mirroring.**

A single native binary — no Node.js, no Python, no runtime dependencies. Built for AI agents ([OpenClaw](https://github.com/openclaw/openclaw), Claude Code, Cursor, Codex) but works great standalone from the terminal.

<!-- TODO: Record a demo showing: doctor → describe → tap --text "Settings" → wait-for "General" → screenshot -->
<!-- ![demo](assets/demo.gif) -->

## Why iphonebase?

- **Single binary, zero dependencies.** One `brew install` and you're done. No Node.js, no npm, no Python virtualenvs. ~15MB in memory.
- **Fast.** Native Swift, ~50ms startup. No interpreter boot time.
- **Works with any AI agent.** Plain CLI with `--json` output. OpenClaw, Claude Code, Cursor, Codex, custom scripts — anything that can call a shell command can drive your iPhone.
- **Grid mode for vision-model agents.** Labeled screenshot grid (A1, B2, C3...) lets Claude, GPT-4o, and other vision models see and tap the full screen — not just OCR-visible text.
- **Embeddable.** `IPhoneBaseCore` is a standalone Swift library. Import it directly into your Swift app or agent.
- **No jailbreak. No developer account. No app on the phone.** iPhone stays locked and secure.

## Install

### Homebrew (recommended)

```bash
brew tap berkozero/iphonebase && brew install iphonebase
```

### Build from source

```bash
git clone https://github.com/berkozero/iphonebase.git
cd iphonebase
swift build -c release
sudo cp .build/release/iphonebase /usr/local/bin/
```

Then verify everything:

```bash
iphonebase doctor
```

## Requirements

| Requirement | Details |
|---|---|
| macOS | 15.0+ (Sequoia) |
| iPhone Mirroring | Set up and active |
| Karabiner-Elements | [Install](https://karabiner-elements.pqrs.org/) — provides DriverKit virtual HID for input |
| Screen Recording | Permission granted to Terminal/iTerm (System Settings > Privacy & Security) |

Run `iphonebase doctor` to check all prerequisites at once.

## Real-World Examples

All examples follow the **perceive → reason → act** loop. The AI agent reads the `perceive` output, reasons about what to do, then acts.

### Send an iMessage

```bash
iphonebase key 3 --modifier cmd          # open Spotlight
iphonebase type "Messages"               # search for Messages
iphonebase key enter                     # open it
sleep 1
iphonebase perceive --json               # see Messages screen
# Agent reads image, finds "Mom" at (200, 340)
iphonebase tap 200 340                   # tap on Mom's conversation
sleep 1
iphonebase perceive --json               # see conversation
iphonebase type "Running 10 min late!"
iphonebase perceive --json               # find Send button at (350, 680)
iphonebase tap 350 680                   # tap Send
```

### Navigate Settings

```bash
iphonebase key 3 --modifier cmd          # open Spotlight
iphonebase type "Settings"
iphonebase key enter
sleep 1
iphonebase perceive --json               # see Settings screen
# Agent finds "General" at (200, 340)
iphonebase tap 200 340
sleep 1
iphonebase perceive --json               # see General screen
# Agent finds "About" at (200, 280)
iphonebase tap 200 280
sleep 1
iphonebase perceive --json               # read iOS version from screen
```

### Scroll through a feed

```bash
iphonebase perceive --json               # see current screen
iphonebase scroll down --clicks 5        # scroll content
sleep 0.5
iphonebase perceive --json               # see new content
```

### Tap an app icon (grid cell)

```bash
iphonebase perceive --json               # get screen state
# Agent reads grid image, sees Gmail icon in cell B12
iphonebase tap --cell B12                # tap the icon by grid cell
sleep 1
iphonebase perceive --json               # verify app opened
```

Use grid cells for icons, toggles, and non-text elements. Use OCR coordinates for text labels and menu items. See [Grid Mode](#grid-mode-for-vision-model-agents) below.

## Grid Mode for Vision-Model Agents

OCR misses icons, images, and non-text UI elements. Grid mode lets vision-capable LLMs (Claude, GPT-4o) see the full screen with coordinate references:

```bash
iphonebase screenshot --grid --output screen.png
# AI sees labeled grid cells: A1, A2, B1, B2, C3...
# AI responds: "tap cell B3"
iphonebase tap --cell B3
```

<!-- TODO: Add a real grid screenshot example -->
<!-- ![grid example](assets/grid-example.png) -->

Grid cells default to ~44pt (iOS tap target size) and can be customized:

```bash
iphonebase screenshot --grid --rows 10 --cols 5 --output grid.png
```

This is strictly better than raw screenshots for AI agents — the labeled cells give the model unambiguous spatial references, even for icons, images, and non-text buttons that OCR can't detect.

## How It Works

`iphonebase` interacts with your iPhone through the iPhone Mirroring window on macOS Sequoia:

1. **Screen Capture** — captures the mirroring window via ScreenCaptureKit
2. **OCR** — uses Apple Vision to identify UI elements and their coordinates
3. **Input Injection** — sends taps, swipes, and keystrokes via Karabiner DriverKit virtual HID (the only method that bypasses Apple's CGEvent blocking on the mirroring window)

No jailbreak. No developer account. No app installation on the phone. Your iPhone stays locked and secure.

## Commands

| Command | Description |
|---|---|
| `perceive` | Screenshot + OCR + grid metadata — the agent's primary input |
| `tap` | Tap by coordinates or grid cell |
| `swipe` | Swipe up/down/left/right |
| `scroll` | Scroll up/down |
| `drag` | Point-to-point drag |
| `type` | Type text character by character |
| `key` | Press a key with optional modifiers |
| `home` | Go to iPhone home screen |
| `screenshot` | Capture the iPhone screen as PNG (supports `--grid`) |
| `status` | Check if iPhone Mirroring is available |
| `doctor` | Run diagnostics on all prerequisites |

Every command supports `--json` for structured machine-readable output.

### Command Examples

```bash
# Perceive: screenshot + OCR + grid metadata (agent's primary input)
iphonebase perceive --json
iphonebase perceive --json --base64    # inline image for OpenClaw

# Tap by coordinates (from perceive output) or grid cell
iphonebase tap 200 400
iphonebase tap --cell B3
iphonebase tap 200 400 --double
iphonebase tap 200 400 --long

# Swipe and scroll
iphonebase swipe up
iphonebase swipe left --from 200,400 --distance 500
iphonebase scroll down --clicks 5

# Drag (fromX fromY toX toY)
iphonebase drag 100 200 300 400 --steps 30

# Type and press keys
iphonebase type "hello world"
iphonebase key enter
iphonebase key a --modifier cmd
iphonebase key 3 --modifier cmd    # open Spotlight on iPhone

# Navigate
iphonebase home

# Screenshot (with optional grid overlay)
iphonebase screenshot --output screen.png
iphonebase screenshot --grid --output grid.png
```

### JSON Output

All commands return a consistent envelope when `--json` is passed:

```json
{
  "success": true,
  "action": "tap",
  "data": { ... },
  "error": null,
  "durationMs": 42
}
```

## Agent Integration

### OpenClaw

Install the [OpenClaw](https://github.com/openclaw/openclaw) skill for automatic discovery:

```bash
cp -r skills/iphonebase ~/.openclaw/skills/
```

Then ask your agent to interact with your phone:

> "Open Settings on my iPhone and check the iOS version"

OpenClaw will automatically use iphonebase to:
1. `perceive --json --base64` — capture current screen state (image + OCR + grid)
2. Decide next action (LLM) based on what it sees
3. `tap 200 340` — tap "General" using coordinates from perceive
4. `perceive --json --base64` — verify navigation
5. `tap 200 280` — tap "About"
6. `perceive --json --base64` — read the iOS version and report back

The skill definition lives in `skills/iphonebase/SKILL.md` — it teaches agents the full command set, recommended workflow, and coordinate system.

### Claude Code

`iphonebase` ships with `CLAUDE.md` and `AGENTS.md` — Claude Code picks up the project context automatically. Just ensure the binary is on your `PATH`:

```bash
brew install iphonebase   # or build from source
```

### Any AI Agent

iphonebase is a plain CLI with `--json` output. Any agent that can execute shell commands can use it:

```python
import subprocess, json

result = subprocess.run(
    ["iphonebase", "perceive", "--json"],
    capture_output=True, text=True
)
screen = json.loads(result.stdout)
for element in screen["data"]["elements"]:
    print(f"{element['text']} at ({element['x']}, {element['y']})")
```

## Agent Workflow

The recommended **perceive → reason → act** loop:

```
1. iphonebase doctor            # Verify prerequisites (first run only)
2. iphonebase perceive --json   # Read current screen state
3. Read the gridImagePath file  # See the screen (Claude Code)
4. Reason about which element to interact with
5. Act: tap / type / swipe / scroll / drag / key / home
6. sleep 0.5-1                  # Let UI settle
7. iphonebase perceive --json   # Verify action had expected effect
   ↳ Repeat 2–7 for multi-step tasks
```

All coordinates from `perceive` flow directly into `tap x y` — no conversion needed.

## Architecture

```
iphonebase (CLI — ArgumentParser)
└── IPhoneBaseCore (library)
    ├── WindowManager    — find & focus the iPhone Mirroring window
    ├── ScreenCapture    — ScreenCaptureKit capture + grid overlay
    ├── OCREngine        — Apple Vision text recognition
    ├── InputInjector    — Karabiner DriverKit virtual HID input
    ├── HIDKeyMap        — USB HID keycodes & character mappings
    └── ActionResult     — consistent JSON response envelope
```

`IPhoneBaseCore` is a standalone Swift library — import it directly into your own Swift app or agent without the CLI.

## Why iPhone Mirroring?

| | iphonebase | WebDriverAgent | Appium |
|---|---|---|---|
| Install on iPhone | Nothing | XCTest runner | WebDriverAgent |
| Developer account | Not needed | Required | Required |
| Xcode on Mac | Not needed | Required | Required |
| Works with any app | Yes | Most | Most |
| Phone stays locked | Yes | No | No |
| Setup time | Minutes | Hours | Hours |

## Limitations

- One phone at a time (macOS iPhone Mirroring limitation)
- Mirroring window must be visible (steals focus during input)
- Text is typed character by character (no clipboard paste)
- Element detection is OCR-based (no accessibility tree)
- Requires Karabiner-Elements with DriverKit for input injection
- macOS-only (Sequoia 15.0+)

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- [Bug reports](https://github.com/berkozero/iphonebase/issues/new?template=bug_report.md)
- [Feature requests](https://github.com/berkozero/iphonebase/issues/new?template=feature_request.md)
- [Security issues](SECURITY.md) — please report privately

## License

[MIT](LICENSE)
