import AppKit
import SwiftUI
import os

private let log = Logger(subsystem: "com.lucy.panghugit", category: "Session")

@MainActor
final class Session: ObservableObject {
    @Published var lastInvocation: PanghuGitInvocation?
    @Published var history: [PanghuGitInvocation] = []
    @Published var resolvedRoot: URL?
    /// 安装环境自检快照（启动时一次性填入，WelcomeView 用于引导用户）。
    @Published var diagnostics: BundleDiagnostics.Snapshot?

    func ingest(_ invocation: PanghuGitInvocation) {
        lastInvocation = invocation
        history.insert(invocation, at: 0)
        if history.count > 50 { history.removeLast() }

        if let target = invocation.target {
            resolvedRoot = RepoProbe.root(at: target)
        } else {
            resolvedRoot = nil
        }

        log.info("invocation: \(invocation.action.rawValue) target=\(invocation.target?.path ?? "nil") items=\(invocation.selected.count) root=\(self.resolvedRoot?.path ?? "none")")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let session = Session()
    static var shared: AppDelegate!

    func applicationWillFinishLaunching(_ notification: Notification) {
        CLI.handleArgsIfPresent()
        NSAppleEventManager.shared().setEventHandler(self,
            andSelector: #selector(handleAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        SettingsStore.shared.applyLanguage()
        SettingsStore.startObservingCrossProcessChanges()
        session.diagnostics = BundleDiagnostics.snapshot()
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
                let closing = note.object as? NSWindow
                let otherVisible = NSApp.windows.contains { w in
                    w !== closing && w.isVisible && !w.isSheet && !(w is NSPanel)
                }
                if !otherVisible {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
    }

    @objc func showWelcome() {
        HostWindow.show(id: "welcome", title: L10n.s("app.name"), size: NSSize(width: 720, height: 720)) {
            WelcomeView().environmentObject(session)
        }
    }

    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc func showShortcuts() {
        HostWindow.show(id: "shortcuts", title: L10n.s("help.shortcuts")) {
            ShortcutsView()
        }
    }

    @objc func openDocumentation() {
        if let url = URL(string: "https://github.com/lucycoding/PanghuGit/wiki") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func reportIssue() {
        if let url = URL(string: "https://github.com/lucycoding/PanghuGit/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showAboutPanel() {
        NSApp.sendAction(Selector(("orderFrontStandardAboutPanel:")), to: nil, from: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlStr = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlStr) else { return }
        log.info("handleAppleEvent: \(urlStr)")
        ActionRouter.handle(url, session: session)
    }
}