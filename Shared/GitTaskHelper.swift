import Foundation

enum GitTaskHelper {
    @discardableResult
    public static func run(
        _ args: [String],
        in root: URL,
        timeout: TimeInterval = 30
    ) async throws -> GitCommandResult {
        try await Task.detached {
            try GitRunner.configuredWithTimeout(timeout).run(args, in: root)
        }.value
    }

    @discardableResult
    public static func runOptional(
        _ args: [String],
        in root: URL,
        timeout: TimeInterval = 30
    ) async -> GitCommandResult? {
        do {
            return try await Task.detached {
                try GitRunner.configuredWithTimeout(timeout).run(args, in: root)
            }.value
        } catch {
            fputs("GitTaskHelper: \(error)\n", stderr)
            return nil
        }
    }
}
