import Foundation

/// `git` 进程的轻量封装：统一 exec、错误处理与超时。

public struct GitCommandResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public var isSuccess: Bool { exitCode == 0 }
}

public enum GitListResult<T: Sendable>: Sendable {
    case success([T])
    case empty
    case failure(String)

    public var values: [T] {
        switch self {
        case .success(let items): return items
        case .empty: return []
        case .failure: return []
        }
    }

    public var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

public enum GitErrorMessage {
    public static func friendly(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return L10n.s("common.gitFailed") }

        if trimmed.contains("not a git repository") {
            return L10n.s("error.notGitRepo")
        }
        if trimmed.contains("merge conflict") || trimmed.contains("CONFLICT") {
            return L10n.s("error.mergeConflict")
        }
        if trimmed.contains("would be overwritten by merge") || trimmed.contains("local changes would be overwritten") {
            return L10n.s("error.dirtyOverwrite")
        }
        if trimmed.contains("fatal: not possible to fast-forward, aborting") {
            return L10n.s("error.noFastForward")
        }
        if trimmed.contains("fatal: remote error") || trimmed.contains("Could not read from remote") {
            return L10n.s("error.remoteAccess")
        }
        if trimmed.contains("Permission denied") || trimmed.contains("Authentication failed") {
            return L10n.s("error.authFailed")
        }
        if trimmed.contains("failed to push some refs") || trimmed.contains("Updates were rejected") {
            return L10n.s("error.pushRejected")
        }
        if trimmed.contains("no such remote") || (trimmed.contains("remote:") && trimmed.contains("not found")) {
            return L10n.s("error.remoteNotFound")
        }
        if trimmed.contains("already exists") {
            return L10n.s("error.alreadyExists")
        }
        if trimmed.contains("did not match any file") || (trimmed.contains("pathspec") && trimmed.contains("did not match")) {
            return L10n.s("error.pathNotFound")
        }
        return trimmed
    }
}

public enum GitRunnerError: Error, LocalizedError {
    case launchFailed(String)
    case gitNotFound

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let s): return L10n.s("gitrunner.launchFail") + ": \(s)"
        case .gitNotFound: return L10n.s("gitrunner.notFound")
        }
    }
}

public struct GitRunner: Sendable {
    public let gitURL: URL
    public let defaultTimeout: TimeInterval

    public init(gitURL: URL = URL(fileURLWithPath: "/usr/bin/git"), timeout: TimeInterval = 15) {
        self.gitURL = gitURL
        self.defaultTimeout = timeout
    }

    /// 在 `repo` 下执行 `git <args>`。
    public func run(
        _ args: [String],
        in repo: URL?,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) throws -> GitCommandResult {
        guard FileManager.default.isExecutableFile(atPath: gitURL.path) else {
            throw GitRunnerError.gitNotFound
        }

        let process = Process()
        process.executableURL = gitURL
        process.arguments = args

        if let repo, repo.isFileURL {
            process.currentDirectoryURL = repo
        }
        var env = ProcessInfo.processInfo.environment
        if let environment { env.merge(environment) { _, new in new } }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw GitRunnerError.launchFailed(error.localizedDescription)
        }

        let timeoutMs = Int((timeout ?? defaultTimeout) * 1000)
        let deadline = DispatchTime.now() + .milliseconds(timeoutMs)

        let waiter = DispatchQueue.global()
        let proc = process
        let timedOut = DispatchSemaphore(value: 0)
        waiter.asyncAfter(deadline: deadline) {
            if proc.isRunning { proc.terminate() }
            timedOut.signal()
        }

        process.waitUntilExit()
        timedOut.signal()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return GitCommandResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    /// 异步执行 `git <args>`，不阻塞调用线程。
    public func runAsync(
        _ args: [String],
        in repo: URL?,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async -> GitCommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let result: GitCommandResult
                do {
                    result = try self.run(args, in: repo, environment: environment, timeout: timeout)
                } catch {
                    let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    result = GitCommandResult(stdout: "", stderr: msg, exitCode: -1)
                }
                continuation.resume(returning: result)
            }
        }
    }
}