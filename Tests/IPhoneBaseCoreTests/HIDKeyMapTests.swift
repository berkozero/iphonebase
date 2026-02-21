import Testing
@testable import IPhoneBaseCore

// MARK: - lookup()

@Suite("HIDKeyMap.lookup")
struct HIDKeyMapLookupTests {

    @Test("Lowercase letters map to unshifted keycodes")
    func lowercaseLetters() {
        let a = HIDKeyMap.lookup("a")
        #expect(a?.keycode == HIDKeyCode.a)
        #expect(a?.modifiers == HIDModifier([]))

        let z = HIDKeyMap.lookup("z")
        #expect(z?.keycode == HIDKeyCode.z)
        #expect(z?.modifiers == HIDModifier([]))
    }

    @Test("Uppercase letters map to shifted keycodes")
    func uppercaseLetters() {
        let A = HIDKeyMap.lookup("A")
        #expect(A?.keycode == HIDKeyCode.a)
        #expect(A?.modifiers == .leftShift)

        let Z = HIDKeyMap.lookup("Z")
        #expect(Z?.keycode == HIDKeyCode.z)
        #expect(Z?.modifiers == .leftShift)
    }

    @Test("Digits map to unshifted keycodes")
    func digits() {
        #expect(HIDKeyMap.lookup("0")?.keycode == HIDKeyCode.key0)
        #expect(HIDKeyMap.lookup("1")?.keycode == HIDKeyCode.key1)
        #expect(HIDKeyMap.lookup("9")?.keycode == HIDKeyCode.key9)
        #expect(HIDKeyMap.lookup("5")?.modifiers == HIDModifier([]))
    }

    @Test("Shifted symbols (! @ # etc.) map to shifted digit keycodes")
    func shiftedSymbols() {
        #expect(HIDKeyMap.lookup("!")?.keycode == HIDKeyCode.key1)
        #expect(HIDKeyMap.lookup("!")?.modifiers == .leftShift)
        #expect(HIDKeyMap.lookup("@")?.keycode == HIDKeyCode.key2)
        #expect(HIDKeyMap.lookup("#")?.keycode == HIDKeyCode.key3)
        #expect(HIDKeyMap.lookup("$")?.keycode == HIDKeyCode.key4)
        #expect(HIDKeyMap.lookup("%")?.keycode == HIDKeyCode.key5)
        #expect(HIDKeyMap.lookup("^")?.keycode == HIDKeyCode.key6)
        #expect(HIDKeyMap.lookup("&")?.keycode == HIDKeyCode.key7)
        #expect(HIDKeyMap.lookup("*")?.keycode == HIDKeyCode.key8)
        #expect(HIDKeyMap.lookup("(")?.keycode == HIDKeyCode.key9)
        #expect(HIDKeyMap.lookup(")")?.keycode == HIDKeyCode.key0)
    }

    @Test("Unshifted punctuation maps correctly")
    func unshiftedPunctuation() {
        #expect(HIDKeyMap.lookup(" ")?.keycode == HIDKeyCode.space)
        #expect(HIDKeyMap.lookup("-")?.keycode == HIDKeyCode.minus)
        #expect(HIDKeyMap.lookup("-")?.modifiers == HIDModifier([]))
        #expect(HIDKeyMap.lookup("=")?.keycode == HIDKeyCode.equal)
        #expect(HIDKeyMap.lookup("[")?.keycode == HIDKeyCode.leftBracket)
        #expect(HIDKeyMap.lookup("]")?.keycode == HIDKeyCode.rightBracket)
        #expect(HIDKeyMap.lookup("\\")?.keycode == HIDKeyCode.backslash)
        #expect(HIDKeyMap.lookup(";")?.keycode == HIDKeyCode.semicolon)
        #expect(HIDKeyMap.lookup("'")?.keycode == HIDKeyCode.quote)
        #expect(HIDKeyMap.lookup("`")?.keycode == HIDKeyCode.graveAccent)
        #expect(HIDKeyMap.lookup(",")?.keycode == HIDKeyCode.comma)
        #expect(HIDKeyMap.lookup(".")?.keycode == HIDKeyCode.period)
        #expect(HIDKeyMap.lookup("/")?.keycode == HIDKeyCode.slash)
    }

    @Test("Shifted punctuation maps correctly")
    func shiftedPunctuation() {
        #expect(HIDKeyMap.lookup("_")?.keycode == HIDKeyCode.minus)
        #expect(HIDKeyMap.lookup("_")?.modifiers == .leftShift)
        #expect(HIDKeyMap.lookup("+")?.keycode == HIDKeyCode.equal)
        #expect(HIDKeyMap.lookup("{")?.keycode == HIDKeyCode.leftBracket)
        #expect(HIDKeyMap.lookup("}")?.keycode == HIDKeyCode.rightBracket)
        #expect(HIDKeyMap.lookup("|")?.keycode == HIDKeyCode.backslash)
        #expect(HIDKeyMap.lookup(":")?.keycode == HIDKeyCode.semicolon)
        #expect(HIDKeyMap.lookup("\"")?.keycode == HIDKeyCode.quote)
        #expect(HIDKeyMap.lookup("~")?.keycode == HIDKeyCode.graveAccent)
        #expect(HIDKeyMap.lookup("<")?.keycode == HIDKeyCode.comma)
        #expect(HIDKeyMap.lookup(">")?.keycode == HIDKeyCode.period)
        #expect(HIDKeyMap.lookup("?")?.keycode == HIDKeyCode.slash)
    }

    @Test("Special characters (newline, tab) map correctly")
    func specialCharacters() {
        #expect(HIDKeyMap.lookup("\n")?.keycode == HIDKeyCode.returnKey)
        #expect(HIDKeyMap.lookup("\n")?.modifiers == HIDModifier([]))
        #expect(HIDKeyMap.lookup("\t")?.keycode == HIDKeyCode.tab)
    }

    @Test("Unknown characters return nil")
    func unknownCharacters() {
        #expect(HIDKeyMap.lookup("\u{00E9}") == nil)  // e-acute
        #expect(HIDKeyMap.lookup("\u{1F600}") == nil)  // emoji
    }
}

// MARK: - namedKey()

@Suite("HIDKeyMap.namedKey")
struct HIDKeyMapNamedKeyTests {

    @Test("Return/enter key aliases")
    func returnKey() {
        #expect(HIDKeyMap.namedKey("return") == HIDKeyCode.returnKey)
        #expect(HIDKeyMap.namedKey("enter") == HIDKeyCode.returnKey)
        #expect(HIDKeyMap.namedKey("Return") == HIDKeyCode.returnKey)
        #expect(HIDKeyMap.namedKey("ENTER") == HIDKeyCode.returnKey)
    }

    @Test("Escape key aliases")
    func escapeKey() {
        #expect(HIDKeyMap.namedKey("escape") == HIDKeyCode.escape)
        #expect(HIDKeyMap.namedKey("esc") == HIDKeyCode.escape)
        #expect(HIDKeyMap.namedKey("ESC") == HIDKeyCode.escape)
    }

    @Test("Backspace/delete aliases")
    func backspaceKey() {
        #expect(HIDKeyMap.namedKey("backspace") == HIDKeyCode.backspace)
        #expect(HIDKeyMap.namedKey("delete") == HIDKeyCode.backspace)
    }

    @Test("Tab and space keys")
    func tabAndSpace() {
        #expect(HIDKeyMap.namedKey("tab") == HIDKeyCode.tab)
        #expect(HIDKeyMap.namedKey("space") == HIDKeyCode.space)
    }

    @Test("Arrow keys")
    func arrowKeys() {
        #expect(HIDKeyMap.namedKey("up") == HIDKeyCode.upArrow)
        #expect(HIDKeyMap.namedKey("down") == HIDKeyCode.downArrow)
        #expect(HIDKeyMap.namedKey("left") == HIDKeyCode.leftArrow)
        #expect(HIDKeyMap.namedKey("right") == HIDKeyCode.rightArrow)
    }

    @Test("Navigation keys")
    func navigationKeys() {
        #expect(HIDKeyMap.namedKey("home") == HIDKeyCode.home)
        #expect(HIDKeyMap.namedKey("end") == HIDKeyCode.end)
        #expect(HIDKeyMap.namedKey("pageup") == HIDKeyCode.pageUp)
        #expect(HIDKeyMap.namedKey("pagedown") == HIDKeyCode.pageDown)
    }

    @Test("Single character falls back to lookup")
    func singleCharFallback() {
        #expect(HIDKeyMap.namedKey("a") == HIDKeyCode.a)
        #expect(HIDKeyMap.namedKey("5") == HIDKeyCode.key5)
    }

    @Test("Invalid key names return nil")
    func invalidNames() {
        #expect(HIDKeyMap.namedKey("foobar") == nil)
        #expect(HIDKeyMap.namedKey("") == nil)
        #expect(HIDKeyMap.namedKey("ctrl") == nil)
    }
}

// MARK: - parseModifier()

@Suite("HIDKeyMap.parseModifier")
struct HIDKeyMapParseModifierTests {

    @Test("Command modifier aliases")
    func commandModifier() {
        #expect(HIDKeyMap.parseModifier("cmd") == .leftCommand)
        #expect(HIDKeyMap.parseModifier("command") == .leftCommand)
        #expect(HIDKeyMap.parseModifier("CMD") == .leftCommand)
        #expect(HIDKeyMap.parseModifier("Command") == .leftCommand)
    }

    @Test("Shift modifier")
    func shiftModifier() {
        #expect(HIDKeyMap.parseModifier("shift") == .leftShift)
        #expect(HIDKeyMap.parseModifier("SHIFT") == .leftShift)
    }

    @Test("Option/alt modifier aliases")
    func optionModifier() {
        #expect(HIDKeyMap.parseModifier("opt") == .leftOption)
        #expect(HIDKeyMap.parseModifier("option") == .leftOption)
        #expect(HIDKeyMap.parseModifier("alt") == .leftOption)
        #expect(HIDKeyMap.parseModifier("ALT") == .leftOption)
    }

    @Test("Control modifier aliases")
    func controlModifier() {
        #expect(HIDKeyMap.parseModifier("ctrl") == .leftControl)
        #expect(HIDKeyMap.parseModifier("control") == .leftControl)
    }

    @Test("Invalid modifier names return nil")
    func invalidModifiers() {
        #expect(HIDKeyMap.parseModifier("meta") == nil)
        #expect(HIDKeyMap.parseModifier("super") == nil)
        #expect(HIDKeyMap.parseModifier("") == nil)
    }
}
