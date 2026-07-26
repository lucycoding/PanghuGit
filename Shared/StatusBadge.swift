import SwiftUI

struct StatusBadge: View {
    let entry: GitStatusEntry

    var body: some View {
        Text(StatusBadge.label(entry))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(StatusBadge.color(entry), in: RoundedRectangle(cornerRadius: 4))
    }

    static func label(_ e: GitStatusEntry) -> String {
        if e.isUntracked { return L10n.s("commit.role.untracked") }
        if e.staged != .unmodified && e.staged != .untracked { return L10n.s("commit.role.staged") }
        if e.worktree != .unmodified { return L10n.s("commit.role.modified") }
        return L10n.s("commit.role.none")
    }

    static func color(_ e: GitStatusEntry) -> Color {
        if e.isUntracked { return .orange }
        if e.staged != .unmodified && e.staged != .untracked { return .green }
        if e.worktree != .unmodified { return .orange }
        return .secondary
    }
}
