---
name: iphonebase
version: "0.1.0"
description: Control your iPhone from macOS via iPhone Mirroring — tap, swipe, type, screenshot, OCR, scroll, drag, and launch apps.
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

Run `iphonebase doctor` to verify all prerequisites are met.

## Commands

### Check status

```bash
iphonebase status
iphonebase status --json
```

Returns whether iPhone Mirroring is active and the window is found.

### Doctor (diagnostics)

```bash
iphonebase doctor
iphonebase doctor --json
```

Checks all prerequisites (macOS version, iPhone Mirroring, Karabiner, screen recording, OCR) and reports pass/fail for each. Exit code = number of failed checks.

### Screenshot

```bash
iphonebase screenshot --output /tmp/screen.png
iphonebase screenshot --json
iphonebase screenshot --grid --output /tmp/grid.png
iphonebase screenshot --grid --rows 10 --cols 5 --json
```

Captures the mirrored iPhone screen. With `--json`, returns a base64-encoded PNG. With `--grid`, draws a labeled grid overlay (A1, A2, B1, B2...) on the screenshot for vision-model agents. Grid cell dimensions default to ~44pt (iOS tap target size) and can be overridden with `--rows` and `--cols`.

### Describe screen (OCR)

```bash
iphonebase describe
iphonebase describe --json
```

Runs OCR on the current screen and returns detected text elements with their coordinates, dimensions, and confidence scores. Use `--json` for structured output.

### Wait for text (OCR polling)

```bash
iphonebase wait-for "Settings" --timeout 10
iphonebase wait-for "General" --timeout 5 --interval 0.5 --json
```

Polls the screen via OCR until the specified text appears or timeout expires. Returns the matched element on success. Exit code 1 on timeout. Use this between actions to wait for screen transitions instead of hardcoded delays.

### Tap

```bash
iphonebase tap 200 400
iphonebase tap --text "Settings"
iphonebase tap --text "Send" --double
iphonebase tap --text "Photos" --long
iphonebase tap --text "Delete" --long --duration 2000
iphonebase tap --cell B3
```

Tap at coordinates, find an element by text (OCR), or tap a grid cell center. Coordinates are relative to the mirroring window. Options: `--double` for double-tap, `--long` for long press, `--duration <ms>` to set long press duration. Use `--cell` with grid labels from `screenshot --grid`.

### Swipe

```bash
iphonebase swipe up
iphonebase swipe left --from 200,400
iphonebase swipe down --distance 500
```

Swipe in a direction (up, down, left, right). Defaults to center of screen. Use `--from x,y` to set start point and `--distance` to control swipe length (default: 300).

### Scroll

```bash
iphonebase scroll up
iphonebase scroll down --clicks 5
```

Scroll up or down. The `--clicks` option controls scroll amount (default: 3).

### Drag

```bash
iphonebase drag 100 200 300 400
iphonebase drag 50 300 50 100 --steps 30
```

Drag from one point to another (arbitrary point-to-point). Arguments: fromX fromY toX toY. Coordinates are relative to the mirroring window. Use `--steps` to control smoothness (default: 20). Useful for sliders, maps, and list reordering.

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

1. `iphonebase doctor` -- verify all prerequisites (first run only)
2. `iphonebase status --json` -- verify iPhone Mirroring is active
3. `iphonebase describe --json` -- read the current screen (or `screenshot --grid --json` for vision-model agents)
4. Reason about which UI element to interact with
5. Act: `tap`, `type`, `swipe`, `scroll`, `drag`, `key`, `launch`, or `home`
6. `iphonebase wait-for "expected text" --timeout 5` -- wait for screen transition
7. `iphonebase describe --json` -- verify the action had the expected effect

Repeat steps 3-7 for multi-step tasks. Use `wait-for` instead of hardcoded delays.

## Coordinate system

- `describe` returns coordinates in image pixels (retina resolution)
- `tap --text` handles coordinate conversion automatically -- prefer this over raw coordinates
- `tap --cell B3` resolves grid cell to screen coordinates -- use with `screenshot --grid`
- When using raw `tap x y`, coordinates are relative to the mirroring window (screen points, not retina pixels)

## JSON output

Every command supports `--json` for structured output. All JSON responses use a consistent envelope:

```json
{
  "success": true,
  "action": "tap",
  "data": { ... },
  "error": null,
  "durationMs": 42
}
```

Always use `--json` when parsing results programmatically.

## Guardrails

- **Never** send messages, make purchases, delete data, or change settings without explicit user confirmation
- Always describe the screen before acting so you know what you're tapping
- If an action doesn't produce the expected result, screenshot and describe the current state before retrying
- Use `wait-for` between actions to handle variable screen transition times
- Use `--json` output for reliable parsing
- The iPhone Mirroring window must be visible during interaction -- warn the user if status reports it's not found
