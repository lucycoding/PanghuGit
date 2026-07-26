import Foundation

/// 解析"实际使用哪个 git 可执行文件"。
///
/// 优先级：
/// 1. `SettingsStore.gitPath`（用户在 Settings 显式指定）—— 若存在且可执行
/// 2. `which git` 探测的 PATH 中的 git（通过 /usr/bin/env）
/// 3. `/usr/bin/git`（macOS 自带或 Xcode CLT 提供）
/// 4. App bundle 内 `Resources/git/bin/git`（可选内置；由 fetch_git.sh 注入）
///
/// 任一可用即返回；全部失败返回 nil（调用方应给出明确错误引导）。
public enum GitLocator {
    /// 候选路径列表（按优先级），用于在 Settings 面板展示。
    public static func candidates() -> [URL] {
        var list: [URL] = []
        let userPath = SettingsStore.shared.gitPathLocked
        if !userPath.isEmpty {
            let u = URL(fileURLWithPath: userPath)
            list.append(u)
        }
        if let probed = probePATH() { list.append(probed) }
        list.append(URL(fileURLWithPath: "/usr/bin/git"))
        if let bundled = bundledGit() { list.append(bundled) }
        // 去重（按标准化路径）
        var seen = Set<String>()
        return list.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    /// 返回首个可执行的候选，否则 nil。
    public static func resolved() -> URL? {
        for c in candidates() {
            if isExecutable(at: c) { return c }
        }
        return nil
    }

    /// 探测 PATH 中的 git（不依赖 /usr/bin/git 是否存在）。
    private static func probePATH() -> URL? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["git"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let s = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !s.isEmpty { return URL(fileURLWithPath: s) }
            }
        } catch {
            return nil
        }
        return nil
    }

    /// App bundle 内置 git：`PanghuGit.app/Contents/Resources/git/bin/git`。
    public static func bundledGit() -> URL? {
        guard let resourcesURL = Bundle.main.resourceURL else { return nil }
        let candidate = resourcesURL.appendingPathComponent("git/bin/git")
        return candidate
    }

    /// 是否存在并可执行。
    public static func isExecutable(at url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) && fm.isExecutableFile(atPath: url.path)
    }

    /// 调用 `git --version`，返回版本字符串或 nil。
    public static func versionString(at url: URL) -> String? {
        guard isExecutable(at: url) else { return nil }
        let r = try? GitRunner(gitURL: url, timeout: 5).run(["--version"], in: nil)
        guard let r, r.isSuccess else { return nil }
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 来源描述（用于 Settings 面板显示）。
    public static func sourceLabel(for url: URL) -> String {
        let p = url.standardizedFileURL.path
        if let bundled = bundledGit(), bundled.standardizedFileURL.path == p {
            return L10n.s("gitlocator.bundled")
        } else if p == "/usr/bin/git" {
            return L10n.s("gitlocator.system")
        } else if SettingsStore.shared.gitPathLocked == p {
            return L10n.s("gitlocator.user")
        } else {
            return L10n.s("gitlocator.path")
        }
    }
}