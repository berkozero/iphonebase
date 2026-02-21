import Foundation

/// Shared JSON response envelope for all CLI commands.
/// Provides consistent structure for agent parsing.
public struct ActionResult<T: Encodable>: Encodable {
    public let success: Bool
    public let action: String
    public let data: T?
    public let error: String?
    public let durationMs: Int

    public init(success: Bool, action: String, data: T? = nil, error: String? = nil, durationMs: Int = 0) {
        self.success = success
        self.action = action
        self.data = data
        self.error = error
        self.durationMs = durationMs
    }

    /// Convenience: successful result
    public static func ok(action: String, data: T, durationMs: Int = 0) -> ActionResult {
        ActionResult(success: true, action: action, data: data, durationMs: durationMs)
    }

    /// Print this result as pretty-printed JSON to stdout
    public func printJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let jsonData = try? encoder.encode(self),
           let str = String(data: jsonData, encoding: .utf8) {
            print(str)
        }
    }
}

/// For commands that have no meaningful payload beyond the action name
public struct EmptyData: Encodable {
    public init() {}
}

/// Measures wall-clock time in milliseconds for an async throwing block
public func measureMs(_ block: () async throws -> Void) async rethrows -> Int {
    let start = ContinuousClock.now
    try await block()
    let elapsed = ContinuousClock.now - start
    return Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
}

/// Measures wall-clock time in milliseconds for an async non-throwing block
public func measureMs(_ block: () async -> Void) async -> Int {
    let start = ContinuousClock.now
    await block()
    let elapsed = ContinuousClock.now - start
    return Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
}

/// Synchronous version of measureMs
public func measureMs(_ block: () throws -> Void) rethrows -> Int {
    let start = ContinuousClock.now
    try block()
    let elapsed = ContinuousClock.now - start
    return Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
}
