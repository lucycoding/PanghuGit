import Foundation

/// Stash 查询与操作。
public enum StashQuery {
    public struct Entry: Identifiable, Hashable, Sendable {
        public let id: String       // stash@{n}
        public let index: Int
        public let ref: String
        public let message: String
    }

    /// `git stash list --pretty=tformat:` 解析。
    public static func list(root: URL) -> GitListResult<Entry> {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(
                ["stash", "list", "--pretty=tformat:%gd%x09%gs"],
                in: root)
        } catch {
            return .failure(error.localizedDescription)
        }
        guard r.isSuccess else {
            let msg = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(msg)
        }
        let items: [Entry] = r.stdout.split(whereSeparator: \.isNewline).enumerated().compactMap { _, line in
            let s = String(line)
            guard let tab = s.firstIndex(of: "\t") else { return nil }
            let ref = String(s[..<tab])
            let msg = String(s[s.index(after: tab)...])
            let idx = ref
                .components(separatedBy: CharacterSet.decimalDigits)
                .compactMap(Int.init)
                .first ?? 0
            return Entry(id: msg + "@" + ref, index: idx, ref: ref, message: msg)
        }
        return items.isEmpty ? .empty : .success(items)
    }

    public static func push(root: URL, message: String?, includeUntracked: Bool, keepIndex: Bool = false) -> GitCommandResult? {
        var args = ["stash", "push"]
        if let m = message, !m.isEmpty { args += ["-m", m] }
        if includeUntracked { args += ["-u"] }
        if keepIndex { args += ["--keep-index"] }
        let r: GitCommandResult
        do {
            r = try GitRunner.configuredWithTimeout(60).run(args, in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func apply(root: URL, ref: String) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configuredWithTimeout(60).run(["stash", "apply", "--", ref], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func pop(root: URL, ref: String) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configuredWithTimeout(60).run(["stash", "pop", "--", ref], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func drop(root: URL, ref: String) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configuredWithTimeout(30).run(["stash", "drop", "--", ref], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    /// 取某次 stash 与其父提交之间的 patch（用于查看）。
    public static func diff(root: URL, ref: String) -> String {
        let r = try? GitRunner.configuredWithTimeout(30).run(
            ["stash", "show", "-p", "--no-color", ref], in: root)
        return r?.stdout ?? ""
    }

    public static func fileList(root: URL, ref: String) -> [String] {
        let r = try? GitRunner.configuredWithTimeout(15).run(
            ["stash", "show", "--name-only", ref], in: root)
        guard let r, r.isSuccess else { return [] }
        return r.stdout.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    }

    public static func fileDiff(root: URL, ref: String, file: String) -> String {
        let r = try? GitRunner.configuredWithTimeout(30).run(
            ["stash", "show", "-p", "--no-color", ref, "--", file], in: root)
        return r?.stdout ?? ""
    }
}

/// Tag 查询与操作。
public enum TagQuery {
    public struct Entry: Identifiable, Hashable, Sendable {
        public let id: String       // tag name
        public let name: String
        public let target: String   // 指向的提交短 hash
        public let annotation: String?
        public let date: String?
    }

    public static func list(root: URL) -> GitListResult<Entry> {
        let fmt = "%(refname:short)\t%(objectname:short)\t%(contents:subject)\t%(creatordate:short)"
        let r: GitCommandResult
        do {
            r = try GitRunner.configuredWithTimeout(20).run(
                ["for-each-ref", "--format=\(fmt)", "refs/tags"], in: root)
        } catch {
            return .failure(error.localizedDescription)
        }
        guard r.isSuccess else {
            let msg = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(msg)
        }
        let items: [Entry] = r.stdout.split(whereSeparator: \.isNewline).compactMap { line in
            let cols = String(line).split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 2 else { return nil }
            return Entry(
                id: String(cols[0]),
                name: String(cols[0]),
                target: String(cols[1]),
                annotation: cols.count >= 3 && !String(cols[2]).isEmpty ? String(cols[2]) : nil,
                date: cols.count >= 4 && !String(cols[3]).isEmpty ? String(cols[3]) : nil
            )
        }
        return items.isEmpty ? .empty : .success(items)
    }

    public static func create(root: URL, name: String, message: String?, annotated: Bool, targetRef: String?) -> GitCommandResult? {
        var args = ["tag"]
        if annotated || message != nil { args += ["-a", "-m", message ?? name] }
        args += [name]
        if let t = targetRef, !t.isEmpty { args += [t] }
        let r: GitCommandResult
        do {
            r = try GitRunner.configuredWithTimeout(30).run(args, in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func delete(root: URL, name: String) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configuredWithTimeout(20).run(["tag", "-d", "--", name], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }
}