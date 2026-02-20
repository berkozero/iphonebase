import XCTest
@testable import IPhoneBaseCore

final class HIDKeyMapTests: XCTestCase {

    // MARK: - lookup()

    func testLookupLowercaseLetters() {
        let a = HIDKeyMap.lookup("a")
        XCTAssertEqual(a?.keycode, HIDKeyCode.a)
        XCTAssertEqual(a?.modifiers, HIDModifier([]))

        let z = HIDKeyMap.lookup("z")
        XCTAssertEqual(z?.keycode, HIDKeyCode.z)
        XCTAssertEqual(z?.modifiers, HIDModifier([]))
    }

    func testLookupUppercaseLetters() {
        let A = HIDKeyMap.lookup("A")
        XCTAssertEqual(A?.keycode, HIDKeyCode.a)
        XCTAssertEqual(A?.modifiers, .leftShift)

        let Z = HIDKeyMap.lookup("Z")
        XCTAssertEqual(Z?.keycode, HIDKeyCode.z)
        XCTAssertEqual(Z?.modifiers, .leftShift)
    }

    func testLookupDigits() {
        XCTAssertEqual(HIDKeyMap.lookup("0")?.keycode, HIDKeyCode.key0)
        XCTAssertEqual(HIDKeyMap.lookup("1")?.keycode, HIDKeyCode.key1)
        XCTAssertEqual(HIDKeyMap.lookup("9")?.keycode, HIDKeyCode.key9)
        XCTAssertEqual(HIDKeyMap.lookup("5")?.modifiers, HIDModifier([]))
    }

    func testLookupShiftedSymbols() {
        XCTAssertEqual(HIDKeyMap.lookup("!")?.keycode, HIDKeyCode.key1)
        XCTAssertEqual(HIDKeyMap.lookup("!")?.modifiers, .leftShift)
        XCTAssertEqual(HIDKeyMap.lookup("@")?.keycode, HIDKeyCode.key2)
        XCTAssertEqual(HIDKeyMap.lookup("#")?.keycode, HIDKeyCode.key3)
        XCTAssertEqual(HIDKeyMap.lookup("$")?.keycode, HIDKeyCode.key4)
        XCTAssertEqual(HIDKeyMap.lookup("%")?.keycode, HIDKeyCode.key5)
        XCTAssertEqual(HIDKeyMap.lookup("^")?.keycode, HIDKeyCode.key6)
        XCTAssertEqual(HIDKeyMap.lookup("&")?.keycode, HIDKeyCode.key7)
        XCTAssertEqual(HIDKeyMap.lookup("*")?.keycode, HIDKeyCode.key8)
        XCTAssertEqual(HIDKeyMap.lookup("(")?.keycode, HIDKeyCode.key9)
        XCTAssertEqual(HIDKeyMap.lookup(")")?.keycode, HIDKeyCode.key0)
    }

    func testLookupUnshiftedPunctuation() {
        XCTAssertEqual(HIDKeyMap.lookup(" ")?.keycode, HIDKeyCode.space)
        XCTAssertEqual(HIDKeyMap.lookup("-")?.keycode, HIDKeyCode.minus)
        XCTAssertEqual(HIDKeyMap.lookup("-")?.modifiers, HIDModifier([]))
        XCTAssertEqual(HIDKeyMap.lookup("=")?.keycode, HIDKeyCode.equal)
        XCTAssertEqual(HIDKeyMap.lookup("[")?.keycode, HIDKeyCode.leftBracket)
        XCTAssertEqual(HIDKeyMap.lookup("]")?.keycode, HIDKeyCode.rightBracket)
        XCTAssertEqual(HIDKeyMap.lookup("\\")?.keycode, HIDKeyCode.backslash)
        XCTAssertEqual(HIDKeyMap.lookup(";")?.keycode, HIDKeyCode.semicolon)
        XCTAssertEqual(HIDKeyMap.lookup("'")?.keycode, HIDKeyCode.quote)
        XCTAssertEqual(HIDKeyMap.lookup("`")?.keycode, HIDKeyCode.graveAccent)
        XCTAssertEqual(HIDKeyMap.lookup(",")?.keycode, HIDKeyCode.comma)
        XCTAssertEqual(HIDKeyMap.lookup(".")?.keycode, HIDKeyCode.period)
        XCTAssertEqual(HIDKeyMap.lookup("/")?.keycode, HIDKeyCode.slash)
    }

    func testLookupShiftedPunctuation() {
        XCTAssertEqual(HIDKeyMap.lookup("_")?.keycode, HIDKeyCode.minus)
        XCTAssertEqual(HIDKeyMap.lookup("_")?.modifiers, .leftShift)
        XCTAssertEqual(HIDKeyMap.lookup("+")?.keycode, HIDKeyCode.equal)
        XCTAssertEqual(HIDKeyMap.lookup("{")?.keycode, HIDKeyCode.leftBracket)
        XCTAssertEqual(HIDKeyMap.lookup("}")?.keycode, HIDKeyCode.rightBracket)
        XCTAssertEqual(HIDKeyMap.lookup("|")?.keycode, HIDKeyCode.backslash)
        XCTAssertEqual(HIDKeyMap.lookup(":")?.keycode, HIDKeyCode.semicolon)
        XCTAssertEqual(HIDKeyMap.lookup("\"")?.keycode, HIDKeyCode.quote)
        XCTAssertEqual(HIDKeyMap.lookup("~")?.keycode, HIDKeyCode.graveAccent)
        XCTAssertEqual(HIDKeyMap.lookup("<")?.keycode, HIDKeyCode.comma)
        XCTAssertEqual(HIDKeyMap.lookup(">")?.keycode, HIDKeyCode.period)
        XCTAssertEqual(HIDKeyMap.lookup("?")?.keycode, HIDKeyCode.slash)
    }

    func testLookupSpecialCharacters() {
        XCTAssertEqual(HIDKeyMap.lookup("\n")?.keycode, HIDKeyCode.returnKey)
        XCTAssertEqual(HIDKeyMap.lookup("\n")?.modifiers, HIDModifier([]))
        XCTAssertEqual(HIDKeyMap.lookup("\t")?.keycode, HIDKeyCode.tab)
    }

    func testLookupUnknownCharacters() {
        XCTAssertNil(HIDKeyMap.lookup("\u{00E9}"))  // e-acute
        XCTAssertNil(HIDKeyMap.lookup("\u{1F600}"))  // emoji
    }

    // MARK: - namedKey()

    func testNamedKeyReturn() {
        XCTAssertEqual(HIDKeyMap.namedKey("return"), HIDKeyCode.returnKey)
        XCTAssertEqual(HIDKeyMap.namedKey("enter"), HIDKeyCode.returnKey)
        XCTAssertEqual(HIDKeyMap.namedKey("Return"), HIDKeyCode.returnKey)
        XCTAssertEqual(HIDKeyMap.namedKey("ENTER"), HIDKeyCode.returnKey)
    }

    func testNamedKeyEscape() {
        XCTAssertEqual(HIDKeyMap.namedKey("escape"), HIDKeyCode.escape)
        XCTAssertEqual(HIDKeyMap.namedKey("esc"), HIDKeyCode.escape)
        XCTAssertEqual(HIDKeyMap.namedKey("ESC"), HIDKeyCode.escape)
    }

    func testNamedKeyBackspace() {
        XCTAssertEqual(HIDKeyMap.namedKey("backspace"), HIDKeyCode.backspace)
        XCTAssertEqual(HIDKeyMap.namedKey("delete"), HIDKeyCode.backspace)
    }

    func testNamedKeyTabAndSpace() {
        XCTAssertEqual(HIDKeyMap.namedKey("tab"), HIDKeyCode.tab)
        XCTAssertEqual(HIDKeyMap.namedKey("space"), HIDKeyCode.space)
    }

    func testNamedKeyArrows() {
        XCTAssertEqual(HIDKeyMap.namedKey("up"), HIDKeyCode.upArrow)
        XCTAssertEqual(HIDKeyMap.namedKey("down"), HIDKeyCode.downArrow)
        XCTAssertEqual(HIDKeyMap.namedKey("left"), HIDKeyCode.leftArrow)
        XCTAssertEqual(HIDKeyMap.namedKey("right"), HIDKeyCode.rightArrow)
    }

    func testNamedKeyNavigation() {
        XCTAssertEqual(HIDKeyMap.namedKey("home"), HIDKeyCode.home)
        XCTAssertEqual(HIDKeyMap.namedKey("end"), HIDKeyCode.end)
        XCTAssertEqual(HIDKeyMap.namedKey("pageup"), HIDKeyCode.pageUp)
        XCTAssertEqual(HIDKeyMap.namedKey("pagedown"), HIDKeyCode.pageDown)
    }

    func testNamedKeySingleCharFallback() {
        XCTAssertEqual(HIDKeyMap.namedKey("a"), HIDKeyCode.a)
        XCTAssertEqual(HIDKeyMap.namedKey("5"), HIDKeyCode.key5)
    }

    func testNamedKeyInvalid() {
        XCTAssertNil(HIDKeyMap.namedKey("foobar"))
        XCTAssertNil(HIDKeyMap.namedKey(""))
        XCTAssertNil(HIDKeyMap.namedKey("ctrl"))
    }

    // MARK: - parseModifier()

    func testParseModifierCommand() {
        XCTAssertEqual(HIDKeyMap.parseModifier("cmd"), .leftCommand)
        XCTAssertEqual(HIDKeyMap.parseModifier("command"), .leftCommand)
        XCTAssertEqual(HIDKeyMap.parseModifier("CMD"), .leftCommand)
        XCTAssertEqual(HIDKeyMap.parseModifier("Command"), .leftCommand)
    }

    func testParseModifierShift() {
        XCTAssertEqual(HIDKeyMap.parseModifier("shift"), .leftShift)
        XCTAssertEqual(HIDKeyMap.parseModifier("SHIFT"), .leftShift)
    }

    func testParseModifierOption() {
        XCTAssertEqual(HIDKeyMap.parseModifier("opt"), .leftOption)
        XCTAssertEqual(HIDKeyMap.parseModifier("option"), .leftOption)
        XCTAssertEqual(HIDKeyMap.parseModifier("alt"), .leftOption)
        XCTAssertEqual(HIDKeyMap.parseModifier("ALT"), .leftOption)
    }

    func testParseModifierControl() {
        XCTAssertEqual(HIDKeyMap.parseModifier("ctrl"), .leftControl)
        XCTAssertEqual(HIDKeyMap.parseModifier("control"), .leftControl)
    }

    func testParseModifierInvalid() {
        XCTAssertNil(HIDKeyMap.parseModifier("meta"))
        XCTAssertNil(HIDKeyMap.parseModifier("super"))
        XCTAssertNil(HIDKeyMap.parseModifier(""))
    }
}
