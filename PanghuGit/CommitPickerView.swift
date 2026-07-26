import SwiftUI

struct CommitPickerView: View {
    let repoRoot: URL
    let onSelect: (String) -> Void

    @State private var entries: [LogQuery.Entry] = []
    @State private var selection: LogQuery.Entry?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            if loading {
                ProgressView().padding()
            } else {
                List(entries, id: \.id, selection: $selection) { e in
                    HStack(spacing: 8) {
                        Text(e.shortHash).monospaced().foregroundStyle(.tint)
                        Text(e.subject).lineLimit(1).truncationMode(.tail)
                        Spacer()
                        Text(e.authorDate).font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(e.id) }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { load() }
    }

    private func load() {
        Task {
            let result = await Task.detached { LogQuery.entries(root: self.repoRoot, maxCount: 100) }.value
            entries = result.values
            loading = false
        }
    }
}
