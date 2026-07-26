import Cocoa
import FinderSync
import os.log

@objc(FinderSync)
final class FinderSync: FIFinderSync {

    private let watcher = BadgeWatcher()
    private let log = OSLog(subsystem: "com.lucy.panghugit.finder-sync", category: "FinderSync")

    override init() {
        super.init()
        let realHome = URL(fileURLWithPath: NSUserName().isEmpty
            ? "/Users"
            : "/Users/\(NSUserName())")
        let ctrl = FIFinderSyncController.default()
        let urls = watchURLs(seed: realHome)
        ctrl.directoryURLs.formUnion(urls)
        registerBadges(in: ctrl)
        watcher.startListeningForRefreshRequests()
        os_log("init, watching %ld directories, home=%{public}@", log: log, type: .info, ctrl.directoryURLs.count, realHome.path)
    }

    private func registerBadges(in ctrl: FIFinderSyncController) {
        let b: Bundle = {
            let main = Bundle.main
            if main.bundlePath.hasSuffix(".appex") {
                let appURL = main.bundleURL
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                if let appBundle = Bundle(url: appURL) { return appBundle }
            }
            return main
        }()
        let labels: [(String, String, String)] = [
            ("modified",   b.localizedString(forKey: "badge.modified", value: nil, table: nil),   "exclamationmark"),
            ("staged",      b.localizedString(forKey: "badge.staged", value: nil, table: nil),     "plus"),
            ("added",       b.localizedString(forKey: "badge.added", value: nil, table: nil),      "plus"),
            ("untracked",   b.localizedString(forKey: "badge.untracked", value: nil, table: nil),   "questionmark"),
            ("conflict",    b.localizedString(forKey: "badge.conflict", value: nil, table: nil),    "xmark"),
            ("ignored",     b.localizedString(forKey: "badge.ignored", value: nil, table: nil),     "nosign"),
            ("deleted",     b.localizedString(forKey: "badge.deleted", value: nil, table: nil),     "minus"),
        ]
        for (id, label, symbol) in labels {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
            ctrl.setBadgeImage(image ?? NSImage(), label: label, forBadgeIdentifier: id)
        }
    }

    private func watchURLs(seed home: URL) -> Set<URL> {
        var urls: Set<URL> = [home]

        // 用户在 SettingsStore 中自定义的额外目录（App Group 共享）
        if let extra = UserDefaults(suiteName: SettingsStore.suiteName)?
            .stringArray(forKey: "watchDirsExtra") {
            urls.formUnion(extra.compactMap { URL(string: $0) })
        }

        // /Volumes 下的一级挂载点（不递归到内部，FinderSync 仍只观察一级；
        // 这里仅是为了让 FinderSyncController 知道可以去观察这些分支）
        if let volumes = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes", isDirectory: true),
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles]) {
            for v in volumes { urls.insert(v) }
        }
        return urls
    }

    // MARK: - 观察目录

    override func beginObservingDirectory(at url: URL) {
        os_log("beginObservingDirectory", log: log, type: .debug)
        watcher.startObserving(url)
        watcher.refresh(at: url)
    }

    override func endObservingDirectory(at url: URL) {
        os_log("endObservingDirectory", log: log, type: .debug)
        watcher.clear(at: url)
    }

    override func requestBadgeIdentifier(for url: URL) {
        // 优雅策略：先返回缓存快照（如有），后台再补算
        if let cached = watcher.badge(for: url) {
            FIFinderSyncController.default().setBadgeIdentifier(cached, for: url)
        } else {
            FIFinderSyncController.default().setBadgeIdentifier("", for: url)
        }
    }

    // MARK: - 右键菜单

    /// 菜单项分组：仓库内操作 / 仓库管理操作 / 非仓库操作
    private enum MenuGroup {
        case repoOnly      // 仅在仓库内显示
        case repoManage    // 仓库管理操作（仓库内显示）
        case nonRepo       // 非仓库或任何时候
        case fileOnly      // 需要选中文件
        case anywhere      // 任何时候
    }

    private struct MenuItemDef {
        let title: String
        let action: PanghuGitAction
        let selector: Selector
        let group: MenuGroup
    }

    private let allMenuItems: [MenuItemDef] = [
        .init(title: L10n.s("finder.commit"), action: .commit, selector: #selector(invokeCommit), group: .repoOnly),
        .init(title: L10n.s("finder.modifications"), action: .modifications, selector: #selector(invokeModifications), group: .repoOnly),
        .init(title: L10n.s("finder.sync"), action: .sync, selector: #selector(invokeSync), group: .repoOnly),
        .init(title: L10n.s("finder.log"), action: .log, selector: #selector(invokeLog), group: .repoOnly),
        .init(title: L10n.s("finder.diff"), action: .diff, selector: #selector(invokeDiff), group: .repoOnly),
        .init(title: L10n.s("finder.switch"), action: .switch, selector: #selector(invokeSwitch), group: .repoOnly),
        .init(title: L10n.s("finder.branch"), action: .branch, selector: #selector(invokeBranch), group: .repoManage),
        .init(title: L10n.s("finder.stash"), action: .stash, selector: #selector(invokeStash), group: .repoManage),
        .init(title: L10n.s("finder.tag"), action: .tag, selector: #selector(invokeTag), group: .repoManage),
        .init(title: L10n.s("finder.merge"), action: .merge, selector: #selector(invokeMerge), group: .repoOnly),
        .init(title: L10n.s("finder.revert"), action: .revert, selector: #selector(invokeRevert), group: .repoOnly),
        .init(title: L10n.s("finder.init"), action: .initRepo, selector: #selector(invokeInit), group: .nonRepo),
        .init(title: L10n.s("finder.clone"), action: .clone, selector: #selector(invokeClone), group: .nonRepo),
        .init(title: L10n.s("finder.ignore"), action: .ignore, selector: #selector(invokeIgnore), group: .fileOnly),
        .init(title: L10n.s("finder.blame"), action: .blame, selector: #selector(invokeBlame), group: .fileOnly),
        .init(title: L10n.s("finder.submodule"), action: .submodule, selector: #selector(invokeSubmodule), group: .repoManage),
        .init(title: L10n.s("finder.repoSettings"), action: .repoSettings, selector: #selector(invokeRepoSettings), group: .repoManage),
        .init(title: L10n.s("finder.fileLog"), action: .fileLog, selector: #selector(invokeFileLog), group: .fileOnly),
        .init(title: L10n.s("finder.reflog"), action: .reflog, selector: #selector(invokeReflog), group: .repoManage),
        .init(title: L10n.s("finder.patch"), action: .patch, selector: #selector(invokePatch), group: .repoManage),
        .init(title: L10n.s("finder.export"), action: .export, selector: #selector(invokeExport), group: .repoManage),
        .init(title: L10n.s("finder.cleanup"), action: .cleanup, selector: #selector(invokeCleanup), group: .repoManage),
        .init(title: L10n.s("finder.bisect"), action: .bisect, selector: #selector(invokeBisect), group: .repoManage),
        .init(title: L10n.s("finder.worktree"), action: .worktree, selector: #selector(invokeWorktree), group: .repoManage),
        .init(title: L10n.s("finder.settings"), action: .settings, selector: #selector(invokeSettings), group: .anywhere),
    ]

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "PanghuGit")
        let ctrl = FIFinderSyncController.default()
        let target = ctrl.targetedURL()
        let selected = ctrl.selectedItemURLs() ?? []
        let hasSelection = !selected.isEmpty
        let isRepo = (target.flatMap { RepoProbe.root(at: $0) }) != nil

        let visible = allMenuItems.filter { def in
            switch def.group {
            case .repoOnly, .repoManage:
                return isRepo
            case .nonRepo:
                return !isRepo
            case .fileOnly:
                return isRepo && hasSelection
            case .anywhere:
                return true
            }
        }

        guard !visible.isEmpty else { return menu }

        let style = UserDefaults(suiteName: SettingsStore.suiteName)?
            .string(forKey: SettingsStore.Key.menuStyle.rawValue)
            ?? SettingsStore.MenuStyle.submenu.rawValue

        if style == SettingsStore.MenuStyle.flat.rawValue {
            menu.addItem(.separator())
            for def in visible {
                menu.addItem(withTitle: def.title, action: def.selector, keyEquivalent: "")
            }
        } else {
            let submenu = NSMenu(title: "PanghuGit")
            for def in visible {
                submenu.addItem(withTitle: def.title, action: def.selector, keyEquivalent: "")
            }
            let parentItem = NSMenuItem(title: "PanghuGit", action: nil, keyEquivalent: "")
            parentItem.submenu = submenu
            menu.addItem(.separator())
            menu.addItem(parentItem)
        }
        return menu
    }

    @objc private func invokeCommit()  { invoke(.commit) }
    @objc private func invokeModifications() { invoke(.modifications) }
    @objc private func invokeSync()   { invoke(.sync) }
    @objc private func invokeLog()     { invoke(.log) }
    @objc private func invokeDiff()    { invoke(.diff) }
    @objc private func invokeSwitch()  { invoke(.switch) }
    @objc private func invokeBranch()  { invoke(.branch) }
    @objc private func invokeStash()   { invoke(.stash) }
    @objc private func invokeTag()     { invoke(.tag) }
    @objc private func invokeRevert()  { invoke(.revert) }
    @objc private func invokeMerge()   { invoke(.merge) }
    @objc private func invokeBlame()    { invoke(.blame) }
    @objc private func invokeSubmodule() { invoke(.submodule) }
    @objc private func invokeRepoSettings() { invoke(.repoSettings) }
    @objc private func invokeFileLog() { invoke(.fileLog) }
    @objc private func invokeReflog() { invoke(.reflog) }
    @objc private func invokePatch()   { invoke(.patch) }
    @objc private func invokeExport()  { invoke(.export) }
    @objc private func invokeCleanup() { invoke(.cleanup) }
    @objc private func invokeBisect() { invoke(.bisect) }
    @objc private func invokeWorktree() { invoke(.worktree) }
    @objc private func invokeSettings() { invoke(.settings) }
    @objc private func invokeInit()    { invoke(.initRepo) }
    @objc private func invokeClone()   { invoke(.clone) }
    @objc private func invokeIgnore()  { invoke(.ignore) }

    private func invoke(_ action: PanghuGitAction) {
        let ctrl = FIFinderSyncController.default()
        let target = ctrl.targetedURL()
        let selected = ctrl.selectedItemURLs() ?? []
        let invocation = PanghuGitInvocation(action: action, target: target, selected: selected)

        guard let url = PanghuGitURLScheme.makeURL(for: invocation) else {
            os_log("failed to build URL for %{public}@", log: log, type: .error, action.rawValue)
            return
        }
        os_log("opening action: %{public}@", log: log, type: .info, action.rawValue)
        NSWorkspace.shared.open(url)
    }
}