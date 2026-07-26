import Foundation

/// 全局可共享设置：用 App Group container 的 UserDefaults suite
/// （主 App 与 Finder Sync 通过 App Group 共享）。
public final class SettingsStore: ObservableObject, @unchecked Sendable {
    public static let shared = SettingsStore()

    private let defaults: UserDefaults
    private let lock = NSLock()

    public static let suiteName = "com.lucy.panghugit"

    public enum Key: String {
        case gitPath
        case diffTool
        case refreshInterval
        case gitDefaultBranch
        case ignoreAutoCommit
        case commitTemplates
        case conventionalEnabled
        case language
        case menuStyle
        case terminalApp
    }

    public enum MenuStyle: String, CaseIterable, Identifiable {
        case flat = "flat"
        case submenu = "submenu"
        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .flat: return NSLocalizedString("settings.menuStyle.flat", comment: "")
            case .submenu: return NSLocalizedString("settings.menuStyle.submenu", comment: "")
            }
        }
    }

    /// 语言选项。空串表示跟随系统。
    public enum Language: String, CaseIterable, Identifiable {
        case followSystem = ""
        case zh = "zh-Hans"
        case en = "en"
        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .followSystem: return NSLocalizedString("settings.language.followSystem", comment: "")
            case .zh: return "简体中文"
            case .en: return "English"
            }
        }
    }

    public static let defaultConventionalTypes = ["feat","fix","docs","style","refactor","perf","test","chore","build","ci","revert"]

    @Published public var gitPath: String { didSet { defaults.set(gitPath, forKey: Key.gitPath.rawValue); notifyIfMainApp() } }
    public var gitPathLocked: String { lock.lock(); defer { lock.unlock() }; return gitPath }
    @Published public var diffTool: String { didSet { defaults.set(diffTool, forKey: Key.diffTool.rawValue); notifyIfMainApp() } }
    @Published public var refreshInterval: Double { didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval.rawValue); notifyIfMainApp() } }
    @Published public var gitDefaultBranch: String { didSet { defaults.set(gitDefaultBranch, forKey: Key.gitDefaultBranch.rawValue); notifyIfMainApp() } }
    @Published public var ignoreAutoCommit: Bool { didSet { defaults.set(ignoreAutoCommit, forKey: Key.ignoreAutoCommit.rawValue); notifyIfMainApp() } }
    @Published public var commitTemplates: [String] { didSet { persistTemplates(); notifyIfMainApp() } }
    @Published public var conventionalEnabled: Bool { didSet { defaults.set(conventionalEnabled, forKey: Key.conventionalEnabled.rawValue); notifyIfMainApp() } }
    @Published public var language: String { didSet { defaults.set(language, forKey: Key.language.rawValue); notifyIfMainApp() } }
    @Published public var menuStyle: String { didSet { defaults.set(menuStyle, forKey: Key.menuStyle.rawValue); notifyIfMainApp() } }
    @Published public var terminalApp: String { didSet { defaults.set(terminalApp, forKey: Key.terminalApp.rawValue); notifyIfMainApp() } }

    public enum TerminalApp: String, CaseIterable, Identifiable {
        case terminal = "Terminal"
        case iterm = "iTerm"
        case warp = "Warp"
        public var id: String { rawValue }
        public var displayName: String { rawValue }
        public var bundleIdentifier: String {
            switch self {
            case .terminal: return "com.apple.Terminal"
            case .iterm: return "com.googlecode.iterm2"
            case .warp: return "dev.warp.Warp-Stable"
            }
        }
    }

    private var initialized = false
    private var syncing = false

    private func notifyIfMainApp() {
        guard initialized, !syncing, !Bundle.main.bundlePath.hasSuffix(".appex") else { return }
        DistributedNotificationCenter.default().postNotificationName(
            .init("com.lucy.panghugit.settingsChanged"), object: nil,
            userInfo: nil, deliverImmediately: true)
    }

    private init() {
        let d = UserDefaults(suiteName: SettingsStore.suiteName) ?? .standard
        self.defaults = d
        self.gitPath = d.object(forKey: Key.gitPath.rawValue) as? String ?? "/usr/bin/git"
        self.diffTool = d.string(forKey: Key.diffTool.rawValue) ?? ""
        self.refreshInterval = (d.object(forKey: Key.refreshInterval.rawValue) as? Double) ?? 2.0
        self.gitDefaultBranch = d.string(forKey: Key.gitDefaultBranch.rawValue) ?? "main"
        self.ignoreAutoCommit = (d.object(forKey: Key.ignoreAutoCommit.rawValue) as? Bool) ?? true
        self.commitTemplates = Self.decodeTemplates(from: d.string(forKey: Key.commitTemplates.rawValue)) ?? []
        self.conventionalEnabled = (d.object(forKey: Key.conventionalEnabled.rawValue) as? Bool) ?? true
        self.language = d.string(forKey: Key.language.rawValue) ?? ""
        self.menuStyle = d.string(forKey: Key.menuStyle.rawValue) ?? MenuStyle.submenu.rawValue
        self.terminalApp = d.string(forKey: Key.terminalApp.rawValue) ?? TerminalApp.terminal.rawValue
        initialized = true
    }

    /// 主 App 监听跨进程设置变更（如从 CLI 修改）；扩展端不监听，避免死锁。
    public static func startObservingCrossProcessChanges() {
        DistributedNotificationCenter.default().addObserver(
            forName: .init("com.lucy.panghugit.settingsChanged"), object: nil, queue: .main) { _ in
            shared.syncFromDefaults()
        }
    }

    /// 主 App 通知 Finder Sync 扩展立即刷新角标（commit/push/merge 等操作后调用）。
    public static func postBadgeRefresh() {
        DistributedNotificationCenter.default().post(
            name: .init("com.lucy.panghugit.refreshBadges"), object: nil)
    }

    public func syncFromDefaults() {
        syncing = true
        let newGitPath = defaults.object(forKey: Key.gitPath.rawValue) as? String ?? "/usr/bin/git"
        let newDiffTool = defaults.string(forKey: Key.diffTool.rawValue) ?? ""
        let newRefreshInterval = (defaults.object(forKey: Key.refreshInterval.rawValue) as? Double) ?? 2.0
        let newGitDefaultBranch = defaults.string(forKey: Key.gitDefaultBranch.rawValue) ?? "main"
        let newIgnoreAutoCommit = (defaults.object(forKey: Key.ignoreAutoCommit.rawValue) as? Bool) ?? true
        let newCommitTemplates = Self.decodeTemplates(from: defaults.string(forKey: Key.commitTemplates.rawValue)) ?? []
        let newConventionalEnabled = (defaults.object(forKey: Key.conventionalEnabled.rawValue) as? Bool) ?? true
        let newLanguage = defaults.string(forKey: Key.language.rawValue) ?? ""
        let newMenuStyle = defaults.string(forKey: Key.menuStyle.rawValue) ?? MenuStyle.submenu.rawValue
        let newTerminalApp = defaults.string(forKey: Key.terminalApp.rawValue) ?? TerminalApp.terminal.rawValue
        gitPath = newGitPath
        diffTool = newDiffTool
        refreshInterval = newRefreshInterval
        gitDefaultBranch = newGitDefaultBranch
        ignoreAutoCommit = newIgnoreAutoCommit
        commitTemplates = newCommitTemplates
        conventionalEnabled = newConventionalEnabled
        language = newLanguage
        menuStyle = newMenuStyle
        terminalApp = newTerminalApp
        syncing = false
    }

    /// 构造 GitRunner：优先使用 SettingsStore.gitPath；若不可用则由 GitLocator 解析回退。
    public func makeRunner(timeout: TimeInterval = 15) -> GitRunner {
        lock.lock()
        let path = gitPath
        lock.unlock()
        let userURL = URL(fileURLWithPath: path)
        if GitLocator.isExecutable(at: userURL) {
            return GitRunner(gitURL: userURL, timeout: timeout)
        }
        if let resolved = GitLocator.resolved() {
            return GitRunner(gitURL: resolved, timeout: timeout)
        }
        // 全部失败：仍返回用户指定的（执行时会抛 gitNotFound）
        return GitRunner(gitURL: userURL, timeout: timeout)
    }

    /// 强制把 published 推回 defaults（手动调整后调用，防止 didSet 在 init 期被吞）。
    public func persist() {
        defaults.set(gitPath, forKey: Key.gitPath.rawValue)
        defaults.set(diffTool, forKey: Key.diffTool.rawValue)
        defaults.set(refreshInterval, forKey: Key.refreshInterval.rawValue)
        defaults.set(gitDefaultBranch, forKey: Key.gitDefaultBranch.rawValue)
        defaults.set(ignoreAutoCommit, forKey: Key.ignoreAutoCommit.rawValue)
        defaults.set(conventionalEnabled, forKey: Key.conventionalEnabled.rawValue)
        defaults.set(language, forKey: Key.language.rawValue)
        defaults.set(menuStyle, forKey: Key.menuStyle.rawValue)
        persistTemplates()
    }

    /// 应用当前 language 设置到 `AppleLanguages`，立即影响 Bundle.main 的本地化加载。
    /// 需要重启主 App 才能让 SwiftUI 已构建视图完全切换；CLI/扩展端读取不影响。
    public func applyLanguage() {
        let preferred: [String]
        switch Language(rawValue: language) {
        case .zh: preferred = ["zh-Hans"]
        case .en: preferred = ["en"]
        default:  preferred = []   // 跟随系统：清除覆盖
        }
        if preferred.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set(preferred, forKey: "AppleLanguages")
        }
    }

    private func persistTemplates() {
        if let data = try? JSONEncoder().encode(commitTemplates),
           let s = String(data: data, encoding: .utf8) {
            defaults.set(s, forKey: Key.commitTemplates.rawValue)
        }
    }

    private static func decodeTemplates(from raw: String?) -> [String]? {
        guard let s = raw, let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: d)
    }
}

public extension GitRunner {
    /// 从 SettingsStore 默认创建（git 路径走用户配置）。
    static var configured: GitRunner { SettingsStore.shared.makeRunner() }

    /// 从 SettingsStore 创建并指定超时。
    static func configuredWithTimeout(_ timeout: TimeInterval) -> GitRunner {
        SettingsStore.shared.makeRunner(timeout: timeout)
    }
}

/// Conventional Commits 类型常量入口（CommitView 与 SettingsView 共用）。
public enum PanghuConventional {
    public static let types = SettingsStore.defaultConventionalTypes
}