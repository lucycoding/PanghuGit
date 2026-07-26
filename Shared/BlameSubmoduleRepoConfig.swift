import Foundation

/// `git blame --line-porcelain` 的轻量解析。
public enum BlameQuery {
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public struct Line: Identifiable, Hashable, Sendable {
        public let id: Int                // line number in source file (1-based)
        public let sourceSha: String       // 提交短 hash（10 位左右）
        public let author: String
        public let authorTime: String      // ISO 日期
        public let summary: String          // commit subject
        public let content: String          // 该行内容
    }

    public static func blame(root: URL, file: String, revision: String? = nil) -> [Line] {
        var args = ["blame", "--line-porcelain"]
        if let rev = revision { args += [rev] }
        args += ["--", file]
        let r = try? GitRunner.configured.run(args, in: root)
        guard let r, r.isSuccess else { return [] }

        struct Pending {
            var sha: String
            var lineNum: Int
            var author: String?
            var date: String?
            var summary: String?
        }

        var lines: [Line] = []
        var pending: Pending? = nil
        let raw = r.stdout
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(line)
            if s.hasPrefix("\t") {
                if let p = pending {
                    lines.append(Line(
                        id: p.lineNum,
                        sourceSha: shortSha(p.sha),
                        author: p.author ?? "",
                        authorTime: p.date ?? "",
                        summary: p.summary ?? "",
                        content: String(s.dropFirst())   // 去掉前导 \t
                    ))
                }
                pending = nil
                continue
            }
            // header 行
            if pending == nil {
                let parts = s.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                if parts.count >= 2 {
                    pending = Pending(sha: String(parts[0]),
                                      lineNum: Int(parts[1]) ?? 0,
                                      author: nil, date: nil, summary: nil)
                }
            } else {
                if s.hasPrefix("author ") {
                    pending?.author = String(s.dropFirst("author ".count))
                } else if s.hasPrefix("author-time ") {
                    let val = String(s.dropFirst("author-time ".count))
                    if let secs = TimeInterval(val) {
                        pending?.date = dateFormatter.string(from: Date(timeIntervalSince1970: secs))
                    } else {
                        pending?.date = val
                    }
                } else if s.hasPrefix("summary ") {
                    pending?.summary = String(s.dropFirst("summary ".count))
                }
            }
        }
        return lines
    }

    private static func shortSha(_ s: String) -> String {
        s.count > 10 ? String(s.prefix(10)) : s
    }
}

/// 子模块查询与操作。
public enum SubmoduleQuery {
    public struct Entry: Identifiable, Hashable, Sendable {
        public let id: String          // path
        public let path: String
        public let sha: String
        public let branch: String?
        public let url: String
    }

    public static func list(root: URL) -> [Entry] {
        // `git submodule status` 提供当前 sha+path，仓库信息需从 .gitmodules 读
        let r = try? GitRunner.configured.run(
            ["submodule", "status"], in: root)
        var list: [Entry] = []
        let modulesRoot = root.appendingPathComponent(".gitmodules")
        let cfg = (try? String(contentsOf: modulesRoot, encoding: .utf8)) ?? ""
        var pathMap: [String: String] = [:]   // section key -> path
        var urlMap: [String: String] = [:]    // section key -> url
        var branchMap: [String: String] = [:] // section key -> branch
        var currentKey = ""
        for line in cfg.split(whereSeparator: \.isNewline) {
            let s = String(line).trimmingCharacters(in: .whitespaces)
            // 跳过注释行
            if s.hasPrefix("#") || s.hasPrefix(";") || s.isEmpty { continue }
            if s.hasPrefix("[submodule \"") {
                let start = s.index(s.startIndex, offsetBy: "[submodule \"".count)
                if let end = s.range(of: "\"]") {
                    currentKey = String(s[start..<end.lowerBound])
                }
            } else if s.hasPrefix("path = ") {
                let val = String(s.dropFirst("path = ".count)).trimmingCharacters(in: .whitespaces)
                pathMap[currentKey] = val
            } else if s.hasPrefix("url = ") {
                let val = String(s.dropFirst("url = ".count)).trimmingCharacters(in: .whitespaces)
                urlMap[currentKey] = val
            } else if s.hasPrefix("branch = ") {
                let val = String(s.dropFirst("branch = ".count)).trimmingCharacters(in: .whitespaces)
                branchMap[currentKey] = val
            }
        }
        if let r, r.isSuccess {
            for line in r.stdout.split(whereSeparator: \.isNewline) {
                let s = String(line)
                let trimmed = s.trimmingCharacters(in: .whitespaces)
                // 形如 "<sha> <path>" 前缀可能有 +/-
                let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { continue }
                let sha = String(parts[0]).trimmingCharacters(in: CharacterSet(charactersIn: "+-~"))
                let path = String(parts[1])
                // 按 path 值查找 section 信息
                let key = pathMap.first(where: { $0.value == path })?.key ?? path
                list.append(Entry(
                    id: path, path: path, sha: sha,
                    branch: branchMap[key],
                    url: urlMap[key] ?? ""
                ))
            }
        }
        return list
    }

    public static func add(root: URL, url: String, path: String, branch: String?) -> GitCommandResult? {
        var args = ["submodule", "add"]
        if let b = branch, !b.isEmpty { args += ["-b", b] }
        args += ["--", url, path]
        return try? GitRunner.configured.run(args, in: root)
    }

    public static func update(root: URL, initIfNeeded: Bool = true, recursive: Bool = false) -> GitCommandResult? {
        var args = ["submodule", "update"]
        if initIfNeeded { args += ["--init"] }
        if recursive { args += ["--recursive"] }
        return try? GitRunner.configured.run(args, in: root)
    }

    public static func sync(root: URL) -> GitCommandResult? {
        try? GitRunner.configured.run(["submodule", "sync"], in: root)
    }

    public static func deinitialize(root: URL, path: String) -> GitCommandResult? {
        try? GitRunner.configured.run(
            ["submodule", "deinit", "-f", "--", path], in: root)
    }
}

/// 仓库设置查询（F-18）。
public enum RepoConfigQuery {
    public struct Remote: Identifiable, Hashable, Sendable {
        public var id: String { name }
        public let name: String
        public let fetchURL: String?
        public let pushURL: String?
    }

    public struct UserInfo: Sendable, Equatable {
        public let name: String
        public let email: String
    }

    public static func remotes(root: URL) -> [Remote] {
        let r = try? GitRunner.configured.run(
            ["remote", "-v"], in: root)
        guard let r, r.isSuccess else { return [] }
        var map: [String: Remote] = [:]
        for line in r.stdout.split(whereSeparator: \.isNewline) {
            let parts = String(line).split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let name = String(parts[0])
            let url = String(parts[1])
            let suffix = String(parts[2]).trimmingCharacters(in: .whitespaces)
            let isPush = suffix.contains("(push)")
            let existing = map[name] ?? Remote(name: name, fetchURL: nil, pushURL: nil)
            if isPush {
                map[name] = Remote(name: name, fetchURL: existing.fetchURL, pushURL: url)
            } else {
                map[name] = Remote(name: name, fetchURL: url, pushURL: existing.pushURL)
            }
        }
        return map.values.sorted { $0.name < $1.name }
    }

    public static func user(root: URL) -> UserInfo {
        let nameR = try? GitRunner.configured.run(["config", "user.name"], in: root)
        let emailR = try? GitRunner.configured.run(["config", "user.email"], in: root)
        return UserInfo(
            name: nameR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            email: emailR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    public static func setUser(root: URL, name: String?, email: String?) -> (success: Bool, message: String) {
        var errors: [String] = []
        if let n = name, !n.isEmpty {
            let r = try? GitRunner.configured.run(["config", "user.name", n], in: root)
            if let r, !r.isSuccess { errors.append("user.name: \(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))") }
        }
        if let e = email, !e.isEmpty {
            let r = try? GitRunner.configured.run(["config", "user.email", e], in: root)
            if let r, !r.isSuccess { errors.append("user.email: \(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))") }
        }
        if errors.isEmpty {
            return (true, L10n.s("reposettings.savedDefault"))
        }
        return (false, L10n.s("reposettings.saveFailed") + ": " + errors.joined(separator: "; "))
    }

    public static func globalUser() -> UserInfo {
        let nameR = try? GitRunner.configured.run(["config", "--global", "user.name"], in: nil)
        let emailR = try? GitRunner.configured.run(["config", "--global", "user.email"], in: nil)
        return UserInfo(
            name: nameR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            email: emailR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    public static func setGlobalUser(name: String?, email: String?) -> (success: Bool, message: String) {
        var errors: [String] = []
        if let n = name, !n.isEmpty {
            let r = try? GitRunner.configured.run(["config", "--global", "user.name", n], in: nil)
            if let r, !r.isSuccess { errors.append("user.name: \(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))") }
        }
        if let e = email, !e.isEmpty {
            let r = try? GitRunner.configured.run(["config", "--global", "user.email", e], in: nil)
            if let r, !r.isSuccess { errors.append("user.email: \(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines))") }
        }
        if errors.isEmpty {
            return (true, L10n.s("reposettings.savedDefault"))
        }
        return (false, L10n.s("reposettings.saveFailed") + ": " + errors.joined(separator: "; "))
    }

    public static func addRemote(root: URL, name: String, url: String) -> GitCommandResult? {
        try? GitRunner.configuredWithTimeout(15).run(
            ["remote", "add", "--", name, url], in: root)
    }

    public static func removeRemote(root: URL, name: String) -> GitCommandResult? {
        try? GitRunner.configuredWithTimeout(15).run(
            ["remote", "remove", "--", name], in: root)
    }

    /// 读取 .git/config 原文（供查看）。
    public static func configFile(root: URL) -> String {
        let gitDir = GitDirResolver.resolve(root: root)
        let configPath = gitDir.appendingPathComponent("config").path
        return (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
    }

    public static func configList(root: URL) -> [(key: String, value: String)] {
        let r = try? GitRunner.configured.run(
            ["config", "--list", "--local"], in: root)
        guard let r, r.isSuccess else { return [] }
        return r.stdout.split(whereSeparator: \.isNewline).compactMap { line in
            let s = String(line)
            guard let eq = s.firstIndex(of: "=") else { return nil }
            return (key: String(s[..<eq]), value: String(s[s.index(after: eq)...]))
        }
    }

    public static func setConfig(root: URL, key: String, value: String) -> GitCommandResult? {
        try? GitRunner.configuredWithTimeout(15).run(
            ["config", "--local", "--", key, value], in: root)
    }

    public static func unsetConfig(root: URL, key: String) -> GitCommandResult? {
        try? GitRunner.configuredWithTimeout(15).run(
            ["config", "--local", "--unset", "--", key], in: root)
    }

    public static func authors(root: URL) -> [String] {
        let r = try? GitRunner.configured.run(
            ["log", "--format=%an <%ae>", "--all"], in: root)
        guard let r, r.isSuccess else { return [] }
        let unique = Set(r.stdout.split(whereSeparator: \.isNewline).map(String.init))
        return unique.sorted()
    }
}