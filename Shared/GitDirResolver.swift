import Foundation

public enum GitDirResolver {
    public static func resolve(root: URL) -> URL {
        let dotGit = root.appendingPathComponent(".git")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: dotGit.path, isDirectory: &isDir), isDir.boolValue {
            return dotGit
        }
        if let content = try? String(contentsOf: dotGit, encoding: .utf8) {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("gitdir:") {
                let path = String(trimmed.dropFirst("gitdir:".count)).trimmingCharacters(in: .whitespaces)
                if path.hasPrefix("/") {
                    return URL(fileURLWithPath: path)
                }
                return root.appendingPathComponent(path).standardizedFileURL
            }
        }
        return dotGit
    }
}
