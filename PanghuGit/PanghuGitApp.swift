import SwiftUI

@main
struct PanghuGitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.s("app.name")) { appDelegate.showWelcome() }
            }
            CommandGroup(replacing: .help) {
                Button(L10n.s("help.shortcuts")) { appDelegate.showShortcuts() }
                Button(L10n.s("help.documentation")) { appDelegate.openDocumentation() }
                Divider()
                Button(L10n.s("help.reportIssue")) { appDelegate.reportIssue() }
                Divider()
                Button(L10n.s("help.about")) { appDelegate.showAboutPanel() }
            }
        }
    }
}