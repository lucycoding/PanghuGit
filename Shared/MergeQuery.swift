import Foundation

/// Merge / Rebase / 冲突处理相关命令。
public enum MergeQuery {
    /// 冲突中的文件（从 `git status --porcelain=v1 -z` 中筛出 U* / *U / DD / AA 等组合）。
    public static func conflicts(root: URL) -> [String] {
        let r = try? GitRunner.configured.run(
            ["status", "--porcelain=v1", "-z"], in: root)
        guard let r, r.isSuccess else { return [] }
        let entries = GitStatusParser().parse(r.stdout)
        return entries
            .filter { isConflictXY($0.xy) }
            .map(\.path)
    }

    public static func isConflictXY(_ xy: String) -> Bool {
        // 两列任一为 U，或 DD/AA/AU/UA 等都算冲突
        let x = xy.first.map { String($0) } ?? " "
        let y = xy.last.map { String($0) } ?? " "
        if x == "U" || y == "U" { return true }
        if (x == "D" && y == "D") { return true }
        if (x == "A" && y == "A") { return true }
        return false
    }

    // MARK: - Merge / Rebase

    public static func merge(root: URL, source: String) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(["merge", "--no-edit", "--", source], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func rebase(root: URL, source: String) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(["rebase", "--", source], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func mergeAbort(root: URL) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(["merge", "--abort"], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func rebaseAbort(root: URL) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(["rebase", "--abort"], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    public static func rebaseContinue(root: URL) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(["rebase", "--continue"], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    /// 标记某文件为已解决（add 该文件）。
    public static func markResolved(root: URL, path: String) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(["add", "--", path], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    /// 继续被冲突打断的 merge：等所有 conflict 标记 resolved 后调用。
    public static func mergeContinue(root: URL) -> GitCommandResult? {
        let r: GitCommandResult
        do {
            r = try GitRunner.configured.run(["commit", "--no-edit"], in: root)
        } catch {
            return GitCommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        return r
    }

    /// 探测当前是否处于 rebase 进行中状态。
    public static func inRebaseState(root: URL) -> Bool {
        let gitDir = resolveGitDir(root)
        let p1 = gitDir.appendingPathComponent("rebase-merge")
        let p2 = gitDir.appendingPathComponent("rebase-apply")
        return FileManager.default.fileExists(atPath: p1.path)
            || FileManager.default.fileExists(atPath: p2.path)
    }

    public static func inMergeState(root: URL) -> Bool {
        let f = resolveGitDir(root).appendingPathComponent("MERGE_HEAD")
        return FileManager.default.fileExists(atPath: f.path)
    }

    private static func resolveGitDir(_ root: URL) -> URL {
        GitDirResolver.resolve(root: root)
    }
}