import AppKit
import SwiftUI
import os

private let log = Logger(subsystem: "com.lucy.panghugit", category: "ActionRouter")

@MainActor
enum ActionRouter {
    private static func rid(_ base: String, root: URL?) -> String {
        guard let root else { return base }
        let safe = root.path.replacingOccurrences(of: "/", with: "_")
        return "\(base)-\(safe)"
    }

    /// 由 SwiftUI `.onOpenURL` 调用。
    static func handle(_ url: URL, session: Session) {
        guard let invocation = PanghuGitURLScheme.parse(url) else {
            log.warning("cannot parse url: \(url.absoluteString)")
            return
        }
        session.ingest(invocation)
        present(invocation: invocation, session: session)
    }

    static func present(invocation: PanghuGitInvocation, session: Session) {
        bringAppFront()
        closeWelcomeIfNeeded()
        let target = invocation.target
        let root = session.resolvedRoot ?? target.flatMap(RepoProbe.root(at:))

        switch invocation.action {
        case .initRepo, .clone:
            let mode: InitCloneView.Mode = invocation.action == .clone ? .clone : .initRepo
            HostWindow.show(id: "init-clone", title: L10n.s("hostwindow.title.initClone")) {
                InitCloneView(initialMode: mode, proposedTarget: target)
            }
        case .commit:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("commit", root: root), title: L10n.s("hostwindow.title.commit")) {
                CommitView(repoRoot: root)
            }
        case .modifications:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("modifications", root: root), title: L10n.s("hostwindow.title.modifications")) {
                ModificationsView(repoRoot: root)
            }
        case .sync:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("sync", root: root), title: L10n.s("hostwindow.title.sync")) {
                SyncView(repoRoot: root)
            }
        case .switch:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("switch", root: root), title: L10n.s("hostwindow.title.switch")) {
                SwitchView(repoRoot: root)
            }
        case .log:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("log", root: root), title: L10n.s("hostwindow.title.log")) {
                LogView(repoRoot: root)
            }
        case .diff:
            guard let root else { showNoRepo(invocation, session); return }
            let firstPath = invocation.selected.first?.path
            HostWindow.show(id: rid("diff", root: root), title: L10n.s("hostwindow.title.diff")) {
                DiffView(repoRoot: root, file: firstPath)
            }
        case .branch:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("branch", root: root), title: L10n.s("hostwindow.title.branch")) {
                BranchManagerView(repoRoot: root)
            }
        case .ignore:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("ignore", root: root), title: L10n.s("hostwindow.title.ignore")) {
                IgnoreView(repoRoot: root, candidates: invocation.selected)
            }
        case .stash:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("stash", root: root), title: L10n.s("hostwindow.title.stash")) {
                StashView(repoRoot: root)
            }
        case .tag:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("tag", root: root), title: L10n.s("hostwindow.title.tag")) {
                TagView(repoRoot: root)
            }
        case .revert:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("revert", root: root), title: L10n.s("hostwindow.title.revert")) {
                RevertResetView(repoRoot: root)
            }
        case .settings:
            HostWindow.show(id: "settings", title: L10n.s("hostwindow.title.settings")) {
                SettingsView()
            }
        case .merge, .rebase:
            guard let root else { showNoRepo(invocation, session); return }
            // 若当前正处在冲突中，直接打开冲突解决面板；否则打开 merge/rebase 面板。
            if !MergeQuery.conflicts(root: root).isEmpty
                || MergeQuery.inMergeState(root: root)
                || MergeQuery.inRebaseState(root: root) {
                HostWindow.show(id: "conflict-\(root.path)", title: "PanghuGit · " + L10n.s("conflict.title")) {
                    ConflictResolverView(repoRoot: root)
                }
            } else {
                HostWindow.show(id: "merge-\(root.path)", title: L10n.s("hostwindow.title.mergeRebase")) {
                    MergeRebaseView(repoRoot: root)
                }
            }
        case .blame:
            guard let root else { showNoRepo(invocation, session); return }
            let rel = relativePath(of: invocation.selected.first?.path, from: root)
            HostWindow.show(id: rid("blame", root: root), title: L10n.s("hostwindow.title.blame")) {
                BlameView(repoRoot: root, initialFile: rel)
            }
        case .submodule:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("submodule", root: root), title: L10n.s("hostwindow.title.submodule")) {
                SubmoduleView(repoRoot: root)
            }
        case .repoSettings:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("reposettings", root: root), title: L10n.s("hostwindow.title.repoSettings")) {
                RepoSettingsView(repoRoot: root)
            }
        case .openTerminal:
            guard let root else { showNoRepo(invocation, session); return }
            let dir = invocation.selected.first ?? target ?? root
            let path = dir.path.replacingOccurrences(of: "'", with: "'\"'\"'")
            let terminalApp = SettingsStore.shared.terminalApp
            let script: String
            if terminalApp == "iTerm" {
                script = """
                tell application "iTerm"
                    activate
                    create window with default profile
                    tell current session of current window
                        write text "cd '\(path)'"
                    end tell
                end tell
                """
            } else if terminalApp == "Warp" {
                script = """
                tell application "Warp"
                    activate
                    open new window
                end tell
                do shell script "open -a Warp \(path)"
                """
            } else {
                script = """
                tell application "Terminal"
                    activate
                    do script "cd '\(path)'"
                end tell
                """
            }
            if let appleScript = NSAppleScript(source: script) {
                var errorDict: NSDictionary?
                appleScript.executeAndReturnError(&errorDict)
                if let err = errorDict {
                    fputs("Terminal AppleScript error: \(err)\n", stderr)
                }
            }
        case .fileLog:
            guard let root else { showNoRepo(invocation, session); return }
            let rel = relativePath(of: invocation.selected.first?.path, from: root)
            HostWindow.show(id: rid("filelog", root: root), title: L10n.s("hostwindow.title.fileLog")) {
                LogView(repoRoot: root, initialFile: rel)
            }
        case .reflog:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("reflog", root: root), title: L10n.s("hostwindow.title.reflog")) {
                ReflogView(repoRoot: root)
            }
        case .patch:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("patch", root: root), title: L10n.s("hostwindow.title.patch")) {
                PatchView(repoRoot: root)
            }
        case .export:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("export", root: root), title: L10n.s("hostwindow.title.export")) {
                ExportView(repoRoot: root)
            }
        case .cleanup:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("cleanup", root: root), title: L10n.s("hostwindow.title.cleanup")) {
                CleanupView(repoRoot: root)
            }
        case .bisect:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("bisect", root: root), title: L10n.s("hostwindow.title.bisect")) {
                BisectView(repoRoot: root)
            }
        case .worktree:
            guard let root else { showNoRepo(invocation, session); return }
            HostWindow.show(id: rid("worktree", root: root), title: L10n.s("hostwindow.title.worktree")) {
                WorktreeView(repoRoot: root)
            }
        }
    }

    static func showNoRepo(_ invocation: PanghuGitInvocation, _ session: Session) {
        let alert = NSAlert()
        alert.messageText = L10n.s("norepo.title")
        alert.informativeText = L10n.f("norepo.message", invocation.target?.path ?? L10n.s("common.noRepo"))
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.s("norepo.openInit"))
        alert.addButton(withTitle: L10n.s("norepo.cancel"))
        alert.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { response in
            if response == .alertFirstButtonReturn {
                present(invocation: PanghuGitInvocation(action: .initRepo,
                                                        target: invocation.target,
                                                        selected: invocation.selected),
                       session: session)
            }
        }
    }

    static func bringAppFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func closeWelcomeIfNeeded() {
        HostWindow.close(id: "welcome")
    }

    private static func relativePath(of file: String?, from root: URL) -> String? {
        guard let f = file else { return nil }
        let rootPath = root.standardizedFileURL.path
        let p = URL(fileURLWithPath: f).standardizedFileURL.path
        return p.hasPrefix(rootPath) ? String(p.dropFirst(rootPath.count + 1)) : f
    }
}