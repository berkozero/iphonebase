import ArgumentParser

@main
struct IPhoneBase: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "iphonebase",
        abstract: "Control your iPhone via macOS iPhone Mirroring.",
        version: "0.1.0",
        subcommands: [
            StatusCommand.self,
            ScreenshotCommand.self,
            DescribeCommand.self,
            TapCommand.self,
            SwipeCommand.self,
            TypeCommand.self,
            KeyCommand.self,
            HomeCommand.self,
            LaunchCommand.self,
        ],
        defaultSubcommand: StatusCommand.self
    )
}
