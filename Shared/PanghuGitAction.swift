import Foundation

/// PanghuGit 跨进程通信协议
///
/// Finder Sync 扩展通过自定义 URL Scheme 唤起主 App：
///   panghugit://<action>?target=<URL-encoded path>&paths=<comma-sep encoded>
///
/// 主 App 在 `.onOpenURL` 中解析并分发到对应窗口。

public enum PanghuGitAction: String, CaseIterable, Sendable {
    case commit
    case sync
    case log
    case diff
    case `switch`
    case initRepo = "init"
    case clone
    case ignore
    case stash
    case merge
    case rebase
    case revert
    case settings
    case branch    // F-08 分支管理
    case tag       // F-13 Tag 管理
    case blame     // F-15 Blame
    case submodule // F-16 Submodule
    case repoSettings = "reposettings" // F-18 仓库设置
    case openTerminal = "openterminal" // Open in Terminal
    case fileLog = "filelog" // Single file history
    case modifications = "modifications" // Check for Modifications
    case reflog = "reflog" // Reflog
    case patch = "patch" // Create / Apply Patch
    case export = "export" // Export (git archive)
    case cleanup = "cleanup" // Cleanup (git clean)
    case bisect // G-25 Git Bisect
    case worktree // G-26 Git Worktree
}

public struct PanghuGitInvocation: Equatable, Sendable {
    public let action: PanghuGitAction
    /// 操作所在目录（仓库根或右键目标文件夹）
    public let target: URL?
    /// 选中的文件 / 文件夹列表
    public let selected: [URL]

    public init(action: PanghuGitAction, target: URL?, selected: [URL]) {
        self.action = action
        self.target = target
        self.selected = selected
    }
}

public enum PanghuGitURLScheme {
    public static let scheme = "panghugit"

    public static func makeURL(for invocation: PanghuGitInvocation) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = invocation.action.rawValue
        var items: [URLQueryItem] = []
        if let target = invocation.target?.absoluteString {
            items.append(.init(name: "target", value: target))
        }
        if !invocation.selected.isEmpty {
            // 用 NUL 分隔，避免逗号路径被错误分割
            items.append(.init(
                name: "paths",
                value: invocation.selected.map(\.absoluteString).joined(separator: "\u{0}")
            ))
        }
        if !items.isEmpty { components.queryItems = items }
        return components.url
    }

    public static func parse(_ url: URL) -> PanghuGitInvocation? {
        guard url.scheme == scheme,
              let raw = url.host,
              let action = PanghuGitAction(rawValue: raw)
        else { return nil }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let target: URL? = comps?.queryItems?
            .first(where: { $0.name == "target" })?
            .value
            .flatMap { URL(string: $0) ?? URL(fileURLWithPath: $0) }
            .flatMap { $0.isFileURL ? $0 : nil }

        let pathsRaw = comps?.queryItems?
            .first(where: { $0.name == "paths" })?
            .value ?? ""
        // 新格式用 NUL 分隔，旧格式用逗号分隔：优先按 NUL 分，无 NUL 时再按逗号分。
        let selected: [URL]
        if pathsRaw.contains("\u{0}") {
            selected = pathsRaw
                .split(separator: "\u{0}")
                .compactMap { URL(string: String($0)) ?? URL(fileURLWithPath: String($0)) }
                .filter(\.isFileURL)
        } else {
            selected = pathsRaw
                .split(separator: ",")
                .compactMap { URL(string: String($0)) ?? URL(fileURLWithPath: String($0)) }
                .filter(\.isFileURL)
        }

        return PanghuGitInvocation(action: action, target: target, selected: selected)
    }
}