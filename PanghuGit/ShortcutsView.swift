import SwiftUI

struct ShortcutsView: View {
    var body: some View {
        Table(rows) {
            TableColumn(L10n.s("help.shortcuts.view")) { row in
                Text(row.view).fontWeight(.semibold)
            }.width(100)
            TableColumn(L10n.s("help.shortcuts.key")) { row in
                Text(row.key).monospaced()
            }.width(120)
            TableColumn(L10n.s("help.shortcuts.action")) { row in
                Text(row.action)
            }
        }
        .tableStyle(.bordered)
        .padding(16)
        .frame(minWidth: 520, minHeight: 400)
    }

    private struct ShortcutRow: Identifiable {
        let id = UUID()
        let view: String
        let key: String
        let action: String
    }

    private var rows: [ShortcutRow] {
        [
            ShortcutRow(view: "Commit", key: "⌘↩", action: L10n.s("help.shortcuts.commit")),
            ShortcutRow(view: "Commit", key: "⌘⇧↩", action: L10n.s("help.shortcuts.commitPush")),
            ShortcutRow(view: "Commit", key: "⌘⇧S", action: L10n.s("help.shortcuts.stageSelected")),
            ShortcutRow(view: "Commit", key: "⌘⌥S", action: L10n.s("help.shortcuts.unstageSelected")),
            ShortcutRow(view: "Commit", key: "⌘⇧A", action: L10n.s("help.shortcuts.toggleAmend")),
            ShortcutRow(view: "Commit", key: "⌘/", action: L10n.s("help.shortcuts.toggleSkipHooks")),
            ShortcutRow(view: "Log", key: "⌘C", action: L10n.s("help.shortcuts.copySHA")),
            ShortcutRow(view: "Log", key: "⌘⌥C", action: L10n.s("help.shortcuts.copyCommitMsg")),
            ShortcutRow(view: "Sync", key: "⌘P", action: L10n.s("help.shortcuts.pull")),
            ShortcutRow(view: L10n.s("help.shortcuts.allViews"), key: "⌘R", action: L10n.s("help.shortcuts.refresh")),
        ]
    }
}
