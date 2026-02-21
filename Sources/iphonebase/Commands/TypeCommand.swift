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

        let injector = InputInjector()
        injector.windowManager = wm
        try injector.connect()
        defer { injector.disconnect() }

        try injector.typeText(text)

        if json {
            let data = TypeData(text: text, length: text.count)
            let result = ActionResult.ok(action: "type", data: data)
            result.printJSON()
        } else {
            print("Typed \(text.count) character(s)")
        }
    }
}

private struct TypeData: Encodable {
    let text: String
    let length: Int
}
