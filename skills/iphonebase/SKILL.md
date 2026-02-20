---
name: iphonebase
description: Control your iPhone from macOS via iPhone Mirroring — tap, swipe, type, screenshot, OCR, and launch apps.
homepage: https://github.com/berkozero/iphonebase
user-invocable: true
metadata:
  openclaw:
    emoji: "\U0001F4F1"
    os: ["darwin"]
    requires:
      bins: ["iphonebase"]
    install: |
      git clone https://github.com/berkozero/iphonebase.git
      cd iphonebase
      swift build -c release
      sudo cp .build/release/iphonebase /usr/local/bin/
---

# iphonebase

Control an iPhone from macOS through Apple's iPhone Mirroring window. Use the `exec` tool to run `iphonebase` commands.

## Prerequisites

- macOS 15.0+ (Sequoia) with iPhone Mirroring set up and the mirroring window open
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) installed (provides DriverKit virtual HID for input injection)
- Screen Recording permission granted to your terminal app (System Settings > Privacy & Security > Screen Recording)

## Commands

### Check status

```bash
iphonebase status
iphonebase status --json
```

Returns whether iPhone Mirroring is active and the window is found.

### Screenshot

```bash
iphonebase screenshot --output /tmp/screen.png
iphonebase screenshot --json
```

Captures the mirrored iPhone screen. With `--json`, returns a base64-encoded PNG.

### Describe screen (OCR)

```bash
iphonebase describe
iphonebase describe --json
```

Runs OCR on the current screen and returns detected text elements with their coordinates, dimensions, and confidence scores. Use `--json` for structured output.

### Tap

```bash
iphonebase tap 200 400
iphonebase tap --text "Settings"
iphonebase tap --text "Send" --double
iphonebase tap --text "Photos" --long
iphonebase tap --text "Delete" --long --duration 2000
```

Tap at coordinates or find an element by text (OCR) and tap its center. Coordinates are relative to the mirroring window. Options: `--double` for double-tap, `--long` for long press, `--duration <ms>` to set long press duration.

### Swipe

```bash
iphonebase swipe up
iphonebase swipe left --from 200,400
iphonebase swipe down --distance 500
```

Swipe in a direction (up, down, left, right). Defaults to center of screen. Use `--from x,y` to set start point and `--distance` to control swipe length (default: 300).

### Type text

```bash
iphonebase type "hello world"
```

Types text character by character via virtual keyboard input.

### Press a key

```bash
iphonebase key enter
iphonebase key a --modifier cmd
iphonebase key backspace
iphonebase key tab --modifier shift
```

Press a named key with optional modifiers. Valid keys: return, escape, backspace, tab, space, up, down, left, right, home, end, pageup, pagedown, or any single character. Modifiers: cmd, shift, opt, ctrl (comma-separated for multiple).

### Go home

```bash
iphonebase home
```

Navigate to the iPhone home screen.

### Launch an app

```bash
iphonebase launch "Messages"
iphonebase launch "Safari"
```

Opens an app by name using Spotlight search.

## Recommended workflow

Always follow this pattern for reliable automation:

1. `iphonebase status --json` -- verify iPhone Mirroring is active
2. `iphonebase describe --json` -- read the current screen
3. Reason about which UI element to interact with
4. Act: `tap`, `type`, `swipe`, `key`, `launch`, or `home`
5. `iphonebase describe --json` -- verify the action had the expected effect

Repeat steps 2-5 for multi-step tasks. Never act blindly -- always describe before and after.

## Coordinate system

- `describe` returns coordinates in image pixels (retina resolution)
- `tap --text` handles coordinate conversion automatically -- prefer this over raw coordinates
- When using raw `tap x y`, coordinates are relative to the mirroring window (screen points, not retina pixels)

## JSON output

Every command supports `--json` for structured output. Always use `--json` when parsing results programmatically.

## Guardrails

- **Never** send messages, make purchases, delete data, or change settings without explicit user confirmation
- Always describe the screen before acting so you know what you're tapping
- If an action doesn't produce the expected result, screenshot and describe the current state before retrying
- Use `--json` output for reliable parsing
- The iPhone Mirroring window must be visible during interaction -- warn the user if status reports it's not found
