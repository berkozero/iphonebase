import ArgumentParser
import IPhoneBaseCore
import Foundation

struct TypeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text on the iPhone via virtual keyboard."
    )

    @Argument(help: "The text to type.")
    var text: String

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        let wm = WindowManager()
        try wm.bringToFront()

        let injector = InputInjector()
        try injector.connect()
        defer { injector.disconnect() }

        try injector.typeText(text)

        if json {
            let result: [String: Any] = [
                "action": "type",
                "text": text,
                "length": text.count,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("Typed \(text.count) character(s)")
        }
    }
}
