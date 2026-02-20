import Foundation

/// USB HID keyboard modifier flags
public struct HIDModifier: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let leftControl  = HIDModifier(rawValue: 0x01)
    public static let leftShift    = HIDModifier(rawValue: 0x02)
    public static let leftOption   = HIDModifier(rawValue: 0x04)
    public static let leftCommand  = HIDModifier(rawValue: 0x08)
    public static let rightControl = HIDModifier(rawValue: 0x10)
    public static let rightShift   = HIDModifier(rawValue: 0x20)
    public static let rightOption  = HIDModifier(rawValue: 0x40)
    public static let rightCommand = HIDModifier(rawValue: 0x80)
}

/// A mapping from a character to a USB HID keycode + modifiers
public struct HIDKeyMapping {
    public let keycode: UInt16
    public let modifiers: HIDModifier
}

// USB HID Usage Table keycodes (Keyboard/Keypad Page 0x07)
public enum HIDKeyCode {
    public static let a: UInt16 = 0x04
    public static let b: UInt16 = 0x05
    public static let c: UInt16 = 0x06
    public static let d: UInt16 = 0x07
    public static let e: UInt16 = 0x08
    public static let f: UInt16 = 0x09
    public static let g: UInt16 = 0x0A
    public static let h: UInt16 = 0x0B
    public static let i: UInt16 = 0x0C
    public static let j: UInt16 = 0x0D
    public static let k: UInt16 = 0x0E
    public static let l: UInt16 = 0x0F
    public static let m: UInt16 = 0x10
    public static let n: UInt16 = 0x11
    public static let o: UInt16 = 0x12
    public static let p: UInt16 = 0x13
    public static let q: UInt16 = 0x14
    public static let r: UInt16 = 0x15
    public static let s: UInt16 = 0x16
    public static let t: UInt16 = 0x17
    public static let u: UInt16 = 0x18
    public static let v: UInt16 = 0x19
    public static let w: UInt16 = 0x1A
    public static let x: UInt16 = 0x1B
    public static let y: UInt16 = 0x1C
    public static let z: UInt16 = 0x1D

    public static let key1: UInt16 = 0x1E
    public static let key2: UInt16 = 0x1F
    public static let key3: UInt16 = 0x20
    public static let key4: UInt16 = 0x21
    public static let key5: UInt16 = 0x22
    public static let key6: UInt16 = 0x23
    public static let key7: UInt16 = 0x24
    public static let key8: UInt16 = 0x25
    public static let key9: UInt16 = 0x26
    public static let key0: UInt16 = 0x27

    public static let returnKey: UInt16 = 0x28
    public static let escape: UInt16 = 0x29
    public static let backspace: UInt16 = 0x2A
    public static let tab: UInt16 = 0x2B
    public static let space: UInt16 = 0x2C
    public static let minus: UInt16 = 0x2D
    public static let equal: UInt16 = 0x2E
    public static let leftBracket: UInt16 = 0x2F
    public static let rightBracket: UInt16 = 0x30
    public static let backslash: UInt16 = 0x31
    public static let semicolon: UInt16 = 0x33
    public static let quote: UInt16 = 0x34
    public static let graveAccent: UInt16 = 0x35
    public static let comma: UInt16 = 0x36
    public static let period: UInt16 = 0x37
    public static let slash: UInt16 = 0x38

    public static let rightArrow: UInt16 = 0x4F
    public static let leftArrow: UInt16 = 0x50
    public static let downArrow: UInt16 = 0x51
    public static let upArrow: UInt16 = 0x52

    public static let home: UInt16 = 0x4A
    public static let pageUp: UInt16 = 0x4B
    public static let delete: UInt16 = 0x4C
    public static let end: UInt16 = 0x4D
    public static let pageDown: UInt16 = 0x4E
}

/// Maps ASCII characters to HID keycodes (US ANSI keyboard layout)
public struct HIDKeyMap {

    private static let charMap: [Character: HIDKeyMapping] = {
        var map: [Character: HIDKeyMapping] = [:]

        // Lowercase letters
        let letters: [(Character, UInt16)] = [
            ("a", HIDKeyCode.a), ("b", HIDKeyCode.b), ("c", HIDKeyCode.c),
            ("d", HIDKeyCode.d), ("e", HIDKeyCode.e), ("f", HIDKeyCode.f),
            ("g", HIDKeyCode.g), ("h", HIDKeyCode.h), ("i", HIDKeyCode.i),
            ("j", HIDKeyCode.j), ("k", HIDKeyCode.k), ("l", HIDKeyCode.l),
            ("m", HIDKeyCode.m), ("n", HIDKeyCode.n), ("o", HIDKeyCode.o),
            ("p", HIDKeyCode.p), ("q", HIDKeyCode.q), ("r", HIDKeyCode.r),
            ("s", HIDKeyCode.s), ("t", HIDKeyCode.t), ("u", HIDKeyCode.u),
            ("v", HIDKeyCode.v), ("w", HIDKeyCode.w), ("x", HIDKeyCode.x),
            ("y", HIDKeyCode.y), ("z", HIDKeyCode.z),
        ]
        for (char, code) in letters {
            map[char] = HIDKeyMapping(keycode: code, modifiers: [])
            // Uppercase
            let upper = Character(char.uppercased())
            map[upper] = HIDKeyMapping(keycode: code, modifiers: .leftShift)
        }

        // Digits
        let digits: [(Character, UInt16)] = [
            ("1", HIDKeyCode.key1), ("2", HIDKeyCode.key2), ("3", HIDKeyCode.key3),
            ("4", HIDKeyCode.key4), ("5", HIDKeyCode.key5), ("6", HIDKeyCode.key6),
            ("7", HIDKeyCode.key7), ("8", HIDKeyCode.key8), ("9", HIDKeyCode.key9),
            ("0", HIDKeyCode.key0),
        ]
        for (char, code) in digits {
            map[char] = HIDKeyMapping(keycode: code, modifiers: [])
        }

        // Shift+digit symbols (US ANSI)
        let shiftDigits: [(Character, UInt16)] = [
            ("!", HIDKeyCode.key1), ("@", HIDKeyCode.key2), ("#", HIDKeyCode.key3),
            ("$", HIDKeyCode.key4), ("%", HIDKeyCode.key5), ("^", HIDKeyCode.key6),
            ("&", HIDKeyCode.key7), ("*", HIDKeyCode.key8), ("(", HIDKeyCode.key9),
            (")", HIDKeyCode.key0),
        ]
        for (char, code) in shiftDigits {
            map[char] = HIDKeyMapping(keycode: code, modifiers: .leftShift)
        }

        // Punctuation (unshifted)
        map[" "] = HIDKeyMapping(keycode: HIDKeyCode.space, modifiers: [])
        map["-"] = HIDKeyMapping(keycode: HIDKeyCode.minus, modifiers: [])
        map["="] = HIDKeyMapping(keycode: HIDKeyCode.equal, modifiers: [])
        map["["] = HIDKeyMapping(keycode: HIDKeyCode.leftBracket, modifiers: [])
        map["]"] = HIDKeyMapping(keycode: HIDKeyCode.rightBracket, modifiers: [])
        map["\\"] = HIDKeyMapping(keycode: HIDKeyCode.backslash, modifiers: [])
        map[";"] = HIDKeyMapping(keycode: HIDKeyCode.semicolon, modifiers: [])
        map["'"] = HIDKeyMapping(keycode: HIDKeyCode.quote, modifiers: [])
        map["`"] = HIDKeyMapping(keycode: HIDKeyCode.graveAccent, modifiers: [])
        map[","] = HIDKeyMapping(keycode: HIDKeyCode.comma, modifiers: [])
        map["."] = HIDKeyMapping(keycode: HIDKeyCode.period, modifiers: [])
        map["/"] = HIDKeyMapping(keycode: HIDKeyCode.slash, modifiers: [])

        // Punctuation (shifted)
        map["_"] = HIDKeyMapping(keycode: HIDKeyCode.minus, modifiers: .leftShift)
        map["+"] = HIDKeyMapping(keycode: HIDKeyCode.equal, modifiers: .leftShift)
        map["{"] = HIDKeyMapping(keycode: HIDKeyCode.leftBracket, modifiers: .leftShift)
        map["}"] = HIDKeyMapping(keycode: HIDKeyCode.rightBracket, modifiers: .leftShift)
        map["|"] = HIDKeyMapping(keycode: HIDKeyCode.backslash, modifiers: .leftShift)
        map[":"] = HIDKeyMapping(keycode: HIDKeyCode.semicolon, modifiers: .leftShift)
        map["\""] = HIDKeyMapping(keycode: HIDKeyCode.quote, modifiers: .leftShift)
        map["~"] = HIDKeyMapping(keycode: HIDKeyCode.graveAccent, modifiers: .leftShift)
        map["<"] = HIDKeyMapping(keycode: HIDKeyCode.comma, modifiers: .leftShift)
        map[">"] = HIDKeyMapping(keycode: HIDKeyCode.period, modifiers: .leftShift)
        map["?"] = HIDKeyMapping(keycode: HIDKeyCode.slash, modifiers: .leftShift)

        // Special keys
        map["\n"] = HIDKeyMapping(keycode: HIDKeyCode.returnKey, modifiers: [])
        map["\t"] = HIDKeyMapping(keycode: HIDKeyCode.tab, modifiers: [])

        return map
    }()

    /// Look up the HID keycode mapping for a character
    public static func lookup(_ char: Character) -> HIDKeyMapping? {
        return charMap[char]
    }

    /// Look up a named key (return, escape, backspace, tab, space, up, down, left, right, home, end, etc.)
    public static func namedKey(_ name: String) -> UInt16? {
        switch name.lowercased() {
        case "return", "enter": return HIDKeyCode.returnKey
        case "escape", "esc": return HIDKeyCode.escape
        case "backspace", "delete": return HIDKeyCode.backspace
        case "tab": return HIDKeyCode.tab
        case "space": return HIDKeyCode.space
        case "up": return HIDKeyCode.upArrow
        case "down": return HIDKeyCode.downArrow
        case "left": return HIDKeyCode.leftArrow
        case "right": return HIDKeyCode.rightArrow
        case "home": return HIDKeyCode.home
        case "end": return HIDKeyCode.end
        case "pageup": return HIDKeyCode.pageUp
        case "pagedown": return HIDKeyCode.pageDown
        default:
            // Single character
            if name.count == 1, let mapping = lookup(name.first!) {
                return mapping.keycode
            }
            return nil
        }
    }

    /// Parse modifier string to HIDModifier
    public static func parseModifier(_ name: String) -> HIDModifier? {
        switch name.lowercased() {
        case "cmd", "command": return .leftCommand
        case "shift": return .leftShift
        case "opt", "option", "alt": return .leftOption
        case "ctrl", "control": return .leftControl
        default: return nil
        }
    }
}
