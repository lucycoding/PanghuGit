import Foundation

public enum RepoProbe {
    public static func root(at url: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if isSandboxed {
            return findGitRoot(from: url)
        }
        let runner = GitRunner.configured
        let result = try? runner.run(["rev-parse", "--show-toplevel"], in: url)
        guard let result, result.isSuccess,
              let line = result.stdout.split(whereSeparator: \.isNewline).first
        else { return nil }
        return URL(fileURLWithPath: String(line).trimmingCharacters(in: .whitespaces))
    }

    private static var isSandboxed: Bool {
        FileManager.default.homeDirectoryForCurrentUser.path.contains("/Containers/")
    }

    private static func findGitRoot(from url: URL) -> URL? {
        var current = url.standardizedFileURL
        while current.path != "/" {
            let dotGit = current.appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dotGit.path, isDirectory: &isDir),
               isDir.boolValue || FileManager.default.fileExists(atPath: dotGit.path) {
                return current
            }
            current.deleteLastPathComponent()
        }
        return nil
    }
}