import SwiftUI
import AppKit

struct ReflogView: View {
    let repoRoot: URL

    struct Entry: Identifiable, Hashable {
        let id: String
        let hash: String
        let shortHash: String
        let ref: String
        let subject: String
    }

    @State private var entries: [Entry] = []
    @State private var selection: Entry?
    @State private var loading = false
    @State private var statusLine: String = ""
    @State private var error = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.f("reflog.title", entries.count)).font(.headline)
                Spacer()
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
            }.padding(10)

            if loading {
                ProgressView().padding()
            } else if entries.isEmpty {
                EmptyStateView(message: L10n.s("reflog.empty"), systemImage: "clock.arrow.circlepath")
            } else {
                List(selection: $selection) {
                    ForEach(entries) { e in
                        HStack(spacing: 8) {
                            Text(e.shortHash).monospaced().foregroundStyle(.tint)
                            Text(e.ref).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(e.subject).lineLimit(1).truncationMode(.tail).foregroundStyle(.secondary)
                        }
                        .tag(e)
                    }
                }
                .onChange(of: selection) { _ in }
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) { StatusBarView(text: statusLine, isError: error, isLoading: loading) }
        .frame(minWidth: 560, minHeight: 400)
        .onAppear { reload() }
    }

    private func reload() {
        loading = true
        Task {
            let r = await GitTaskHelper.runOptional(
                ["reflog", "--pretty=tformat:%H%x09%h%x09%gd%x09%gs"], in: repoRoot, timeout: 15)
            loading = false
            guard let r, r.isSuccess else {
                error = true
                statusLine = GitErrorMessage.friendly(r?.stderr ?? "")
                return
            }
            entries = r.stdout.split(whereSeparator: \.isNewline).compactMap { line in
                let cols = String(line).split(separator: "\t", omittingEmptySubsequences: false)
                guard cols.count >= 4 else { return nil }
                return Entry(
                    id: String(cols[0]),
                    hash: String(cols[0]),
                    shortHash: String(cols[1]),
                    ref: String(cols[2]),
                    subject: String(cols[3])
                )
            }
        }
    }
}
