import Foundation

/// 解析 `git status --porcelain=v1 -z` 输出，得到每个条目的状态。

public enum GitFileStatus: String, Sendable, CaseIterable {
    case unmodified = " "
    case modified = "M"
    case added = "A"      // staged new
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case unmergedU = "U"
    case unmergedBothDeleted = "AD" // worktree deleted, staged added => conflict-ish
    case untracked = "??"
    case ignored = "!!"

    /// 用于 Finder 角标的标识符（与角标资源对应）
    public var badgeIdentifier: String {
        switch self {
        case .modified: return "modified"
        case .added:   return "added"
        case .deleted: return "deleted"
        case .renamed, .copied: return "modified"
        case .unmergedU, .unmergedBothDeleted: return "conflict"
        case .untracked: return "untracked"
        case .ignored:  return "ignored"
        case .unmodified: return ""
        }
    }
}

public struct GitStatusEntry: Sendable, Equatable {
    public let path: String        // 相对仓库根
    public let xy: String          // 原始两字符 "XY"
    public let staged: GitFileStatus
    public let worktree: GitFileStatus
    public let isUntracked: Bool

    public var primaryBadge: String {
        if isUntracked { return GitFileStatus.untracked.badgeIdentifier }
        if worktree != .unmodified { return worktree.badgeIdentifier }
        if staged != .unmodified { return staged.badgeIdentifier }
        return ""
    }
}

public struct GitStatusParser {
    public init() {}

    /// 解析 `git status --porcelain=v1 -z -b` 输出。
    /// - 注意：入参应为原始字节按 NUL 分隔的字符串（首段为 branch 行，可选）。
    public func parse(_ raw: String) -> [GitStatusEntry] {
        var entries: [GitStatusEntry] = []
        let parts = raw.split(separator: "\0", omittingEmptySubsequences: false)
        var i = 0
        while i < parts.count {
            let s = String(parts[i])
            if i == 0, s.hasPrefix("# ") || s.isEmpty {
                i += 1; continue // 分支行
            }
            guard s.count >= 3 else { i += 1; continue }
            let xy = s.prefix(2)
            let x = String(xy.prefix(1))
            let y = String(xy.suffix(1))
            // 路径在 index 2 之后，跳过一个空格
            let path = String(s.dropFirst(3))

            // rename/copy 格式：XY NEW_PATH\0OLD_PATH\0 — 需要消费下一个 NUL 段
            let isRenameOrCopy = x == "R" || x == "C" || y == "R" || y == "C"
            if isRenameOrCopy && i + 1 < parts.count {
                i += 1 // 跳过 OLD_PATH（当前实现不使用旧路径）
            }

            if xy == "??" {
                entries.append(GitStatusEntry(path: path, xy: "??",
                                              staged: .unmodified, worktree: .untracked,
                                              isUntracked: true))
            } else if xy == "!!" {
                entries.append(GitStatusEntry(path: path, xy: "!!",
                                              staged: .unmodified, worktree: .ignored,
                                              isUntracked: false))
            } else {
                entries.append(GitStatusEntry(
                    path: path, xy: String(xy),
                    staged: GitFileStatus(rawValue: x) ?? .modified,
                    worktree: GitFileStatus(rawValue: y) ?? .unmodified,
                    isUntracked: false))
            }
            i += 1
        }
        return entries
    }
}