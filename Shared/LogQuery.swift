import Foundation

/// 提交历史查询：`git log --pretty=tformat:` 解析。
public enum LogQuery {
    public struct Entry: Identifiable, Hashable, Sendable {
        public let id: String                       // SHA
        public let shortHash: String
        public let authorName: String
        public let authorDate: String
        public let subject: String
        public let refs: String                     // HEAD/branch tags etc.
    }

    public static func entries(root: URL,
                               branch: String? = nil,
                               author: String? = nil,
                               since: String? = nil,
                               before: String? = nil,
                               file: String? = nil,
                               maxCount: Int = 500,
                               skip: Int = 0,
                               follow: Bool = false) -> GitListResult<Entry> {
        var args = ["log", "--max-count=\(maxCount)",
                    "--skip=\(follow && file != nil ? 0 : skip)",
                    "--pretty=tformat:%H%x09%h%x09%an%x09%ad%x09%s%x09%D",
                    "--date=short",
                    "--no-color"]
        if follow, file != nil { args += ["--follow"] }
        if let author, !author.isEmpty { args += ["--author=\(author)"] }
        if let since, !since.isEmpty { args += ["--since=\(since)"] }
        if let before, !before.isEmpty { args += ["--before=\(before)"] }
        if let branch, !branch.isEmpty { args += [branch] }
        if let file, !file.isEmpty { args += ["--", file] }

        let r = try? GitRunner.configuredWithTimeout(30).run(args, in: root)
        guard let r, r.isSuccess else {
            let msg = r?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .failure(msg)
        }

        let items: [Entry] = r.stdout.split(whereSeparator: \.isNewline).compactMap { line in
            let cols = String(line).split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 5 else { return nil }
            let hash = String(cols[0])
            let refs = cols.count >= 6 ? String(cols[5]) : ""
            return Entry(
                id: hash,
                shortHash: String(cols[1]),
                authorName: String(cols[2]),
                authorDate: String(cols[3]),
                subject: String(cols[4]),
                refs: refs.isEmpty ? "" : refs
            )
        }
        return items.isEmpty ? .empty : .success(items)
    }

    /// 取某提交的改动文件清单。
    public static func changedFiles(root: URL, hash: String) -> [(path: String, status: String)] {
        let r = try? GitRunner.configuredWithTimeout(20).run(
            ["show", "--no-color", "--pretty=format:", "--name-status", hash],
            in: root)
        guard let r, r.isSuccess else { return [] }
        return r.stdout.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = String(line).split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            return (path: String(parts[1]), status: String(parts[0]))
        }
    }

    /// 两段（hash 或 ref）之间，某文件的 patch 文本。
    public static func diff(root: URL, _ aRef: String?, _ bRef: String?, file: String? = nil) -> String {
        var args = ["diff", "--no-color"]
        if let aRef, let bRef {
            args += ["\(aRef)..\(bRef)"]
        } else if let aRef {
            args += [aRef]
        } else {
            // 工作区 vs HEAD
            args += ["HEAD"]
        }
        args += ["--"]
        if let file, !file.isEmpty { args += [file] }
        let r = try? GitRunner.configuredWithTimeout(30).run(args, in: root)
        var output = r?.stdout ?? ""
        // 对初始提交（hash^ 无效）回退到 git show
        if output.isEmpty, let bRef, let aRef, aRef.hasSuffix("^") {
            let showArgs = ["show", "--no-color", "--pretty=format:", bRef, "--"] + (file.flatMap { [$0] } ?? [])
            let showR = try? GitRunner.configuredWithTimeout(30).run(showArgs, in: root)
            output = showR?.stdout ?? ""
        }
        return output
    }
}