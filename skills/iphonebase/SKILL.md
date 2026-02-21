---
name: iphonebase
version: "0.2.0"
description: Control your iPhone from macOS via iPhone Mirroring — perceive screen state, tap, swipe, type, scroll, drag, and press keys.
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

## Core Concept

iphonebase follows a **perceive-then-act** loop. The AI agent does all reasoning:

1. `perceive` gives the agent eyes (screenshot + OCR + grid metadata)
2. The agent reasons about what it sees
3. Action commands (`tap`, `type`, `swipe`, etc.) execute the agent's decision
4. Repeat

The CLI contains no decision-making logic. All intelligence lives in the agent.

## Commands

### Perceive (primary input)

```bash
iphonebase perceive --json
iphonebase perceive --json --rows 10 --cols 5
iphonebase perceive --json --base64    # for OpenClaw (inline image)
```

Returns a JSON payload with:
- `imagePath` / `gridImagePath` — file paths to raw screenshot and grid-overlay screenshot (default mode)
- `image` / `gridImage` — base64-encoded PNG data (when `--base64` is used)
- `elements` — OCR-detected text with coordinates (screen points)
- `grid` — labeled cells (A1, B3...) with center coordinates (screen points)
- `window` — mirroring window bounds

**For Claude Code:** Read the `gridImagePath` file to see the screen with grid labels. OCR elements in the JSON give precise coordinates for text.

**For OpenClaw:** Use `--base64` to get inline image data in the JSON response.

All coordinates are window-relative screen points, directly usable with `tap x y`.

**Image lifecycle:** Each `perceive` call overwrites the previous screenshots at fixed paths (`/tmp/iphonebase/screen.png` and `screen-grid.png`). No cleanup is needed — files are small (~200KB each), reused across calls, and `/tmp` is cleared on reboot.

### Tap

```bash
iphonebase tap 200 400
iphonebase tap --cell B3
iphonebase tap 200 400 --double
iphonebase tap 200 400 --long
iphonebase tap 200 400 --long --duration 2000
```

Tap at coordinates or a grid cell center. Coordinates are window-relative screen points (use values from `perceive` output directly). Options: `--double` for double-tap, `--long` for long press, `--duration <ms>` for long press duration, `--cell` for grid cell.

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

Drag from one point to another (fromX fromY toX toY). Coordinates are window-relative screen points. Use `--steps` to control smoothness (default: 20).

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
iphonebase key 3 --modifier cmd     # Open Spotlight on iPhone
```

Press a named key with optional modifiers. Valid keys: return, escape, backspace, tab, space, up, down, left, right, or any single character. Modifiers: cmd, shift, opt, ctrl.

### Go home

```bash
iphonebase home
```

Navigate to the iPhone home screen.

### Screenshot

```bash
iphonebase screenshot --output /tmp/screen.png
iphonebase screenshot --grid --output /tmp/grid.png
iphonebase screenshot --json
```

Capture the mirrored iPhone screen. With `--grid`, draws a labeled grid overlay. Prefer `perceive` for agent use — it includes screenshot + OCR + grid in one call.

### Check status

```bash
iphonebase status --json
```

Returns whether iPhone Mirroring is active.

### Doctor (diagnostics)

```bash
iphonebase doctor
```

Checks all prerequisites and reports pass/fail for each.

## Recommended Workflow

Always follow this perceive-act loop:

```
1. iphonebase perceive --json         # get screen state
2. Read the gridImagePath file        # see the screen (Claude Code)
3. Reason about what to do            # based on image + OCR elements
4. Act: tap, type, swipe, scroll, drag, key, or home
5. sleep 0.5-1                        # let UI settle
6. iphonebase perceive --json         # verify result, repeat from step 2
```

### Open an app (via Spotlight)

```bash
iphonebase key 3 --modifier cmd       # open Spotlight search
sleep 1
iphonebase type "Settings"            # type app name
sleep 0.5
iphonebase key enter                  # open Top Hit (always use Enter, not tap)
sleep 2
iphonebase perceive --json            # verify app opened
```

## Coordinate System

- All coordinates in `perceive` output (OCR elements and grid cells) are **window-relative screen points**
- Pass these coordinates directly to `tap x y` — no conversion needed
- `tap --cell B3` resolves the grid cell to screen coordinates internally

## Targeting Strategy

You have three ways to interact with elements. Choose based on what you see:

| Target Type | Method | Example |
|---|---|---|
| Text label, menu item, list row | OCR coordinates → `tap x y` | "Settings" at (150, 300) → `tap 150 300` |
| App icon, image, unlabeled button | Grid cell → `tap --cell B3` | Gmail icon in cell B4 → `tap --cell B4` |
| Search results, confirmations | Keyboard → `key enter` | Spotlight Top Hit → `key enter` |

**Rules of thumb:**
- **Home screen apps**: Always use grid cells. OCR gives the label position *below* the icon, which often misses the tap target. Look at the grid image, find the cell containing the icon, use `tap --cell`.
- **Menus and lists**: Use OCR coordinates. Text items in Settings, Gmail rows, etc. have large tap targets that align well with OCR positions.
- **Spotlight / search**: Type your query, then `key enter` to open the Top Hit. Don't tap search results.
- **Toggles / switches / radio buttons**: Use grid cells. These are visual elements that OCR can't reliably detect.
- **When in doubt**: Look at the grid image. If you can see the element in a grid cell, `tap --cell` is safest.

## JSON Output

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
- Always perceive before acting so you know what you're tapping
- If an action doesn't produce the expected result, perceive again before retrying
- Use `--json` output for reliable parsing
- The iPhone Mirroring window must be visible during interaction
