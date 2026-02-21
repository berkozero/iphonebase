import ArgumentParser
import IPhoneBaseCore
import Foundation

struct ScrollCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scroll",
        abstract: "Scroll up or down on the iPhone screen."
    )

    @Argument(help: "Scroll direction: up or down.")
    var direction: ScrollDirection

    @Option(name: .long, help: "Number of scroll clicks (default: 3).")
    var clicks: Int = 3

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    @Flag(name: [.short, .long], help: "Verbose debug output.")
    var verbose = false

    func run() async throws {
        var wm = WindowManager()
        wm.verbose = verbose

        let injector = InputInjector()
        injector.verbose = verbose
        injector.windowManager = wm
        try injector.connect()
        defer { injector.disconnect() }

        // scroll() internally uses swipe from window center
        try injector.scroll(direction: direction, clicks: clicks)

        if json {
            let data = ScrollData(direction: direction.rawValue, clicks: clicks)
            let result = ActionResult.ok(action: "scroll", data: data)
            result.printJSON()
        } else {
            print("Scrolled \(direction.rawValue) (\(clicks) clicks)")
        }
    }
}

extension ScrollDirection: ExpressibleByArgument {}

private struct ScrollData: Encodable {
    let direction: String
    let clicks: Int
}
