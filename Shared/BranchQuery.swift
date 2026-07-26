import Foundation

/// 仓库元信息助手（轻量只读查询：当前分支、本地/远程分支列表）。
public enum BranchQuery {
    public struct Branch: Hashable, Sendable {
        public let name: String
        public let isRemote: Bool
        public let isHEAD: Bool
    }

    public static func currentBranch(at root: URL) -> String? {
        let r = try? GitRunner.configured.run(["symbolic-ref", "--short", "HEAD"], in: root)
        guard let r, r.isSuccess else { return nil }
        let line = r.stdout.split(whereSeparator: \.isNewline).first
        return line.map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    /// `--list` 出本地与远程分支（含 HEAD 标记）。
    public static func list(root: URL) -> GitListResult<Branch> {
        let args = ["branch", "--list", "--all",
                    "--format=%(HEAD):%(refname):%(refname:short)"]
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(args, in: root)
        } catch {
            return .failure(error.localizedDescription)
        }
        guard r.isSuccess else {
            let msg = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(msg)
        }
        let items = r.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> Branch? in
                let s = String(line)
                let parts = s.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                guard parts.count == 3 else { return nil }
                let headMark = String(parts[0])
                let fullRef = String(parts[1])
                let shortRef = String(parts[2])
                let isHEAD = headMark.contains("*")
                let isRemote = fullRef.hasPrefix("refs/remotes/")
                guard !shortRef.isEmpty else { return nil }
                return Branch(name: shortRef, isRemote: isRemote, isHEAD: isHEAD)
            }
        return items.isEmpty ? .empty : .success(items)
    }
}