import ArgumentParser
import IPhoneBaseCore
import Foundation

struct KeyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "key",
        abstract: "Press a single key with optional modifiers."
    )

    @Argument(help: "Key name: return, escape, backspace, tab, space, up, down, left, right, home, end, or a single character.")
    var key: String

    @Option(name: .long, help: "Modifier(s): cmd, shift, opt, ctrl. Comma-separated for multiple.")
    var modifier: String?

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        guard let keycode = HIDKeyMap.namedKey(key) else {
            print("Unknown key: \(key)")
            print("Valid keys: return, escape, backspace, tab, space, up, down, left, right, home, end, pageup, pagedown, or any single character")
            throw ExitCode.failure
        }

        var mods: HIDModifier = []
        if let modStr = modifier {
            for m in modStr.split(separator: ",") {
                let trimmed = m.trimmingCharacters(in: .whitespaces)
                guard let mod = HIDKeyMap.parseModifier(trimmed) else {
                    print("Unknown modifier: \(trimmed)")
                    print("Valid modifiers: cmd, shift, opt, ctrl")
                    throw ExitCode.failure
                }
                mods.insert(mod)
            }
        }

        let wm = WindowManager()
        try wm.bringToFront()

        let injector = InputInjector()
        try injector.connect()
        defer { injector.disconnect() }

        try injector.pressKey(keycode: keycode, modifiers: mods)

        if json {
            let result: [String: Any] = [
                "action": "key",
                "key": key,
                "modifier": modifier ?? "",
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            let modLabel = modifier.map { " (modifier: \($0))" } ?? ""
            print("Pressed key: \(key)\(modLabel)")
        }
    }
}
