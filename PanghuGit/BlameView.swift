import SwiftUI
import AppKit

/// Blame 视图（F-15）：输入文件 → 显示逐行 SHA / 作者 / 时间 / 内容。
struct BlameView: View {
    let repoRoot: URL
    var initialFile: String? = nil

    @State private var filePath: String = ""
    @State private var lines: [BlameQuery.Line] = []
    @State private var running = false
    @State private var status: String = ""
    @State private var blameStack: [(sha: String, file: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            breadcrumb
            HStack(spacing: 8) {
                Text(L10n.s("blame.file")).foregroundStyle(.secondary)
                TextField(L10n.s("blame.filePlaceholder"), text: $filePath).textFieldStyle(.roundedBorder)
                Button(L10n.s("settings.choose")) { pickFile() }
                Button(L10n.s("blame.trace")) { reload() }.buttonStyle(.borderedProminent)
                    .disabled(running)
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
            }
            Divider()
            Table(lines) {
                TableColumn(L10n.s("blame.col.line")) { l in Text(String(l.id)).monospaced().foregroundStyle(.tertiary) }.width(50)
                TableColumn(L10n.s("blame.col.commit")) { l in
                    HStack(spacing: 4) {
                        Text(l.sourceSha).monospaced().foregroundStyle(.tint)
                        Button {
                            blamePreviousRevision(line: l)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }.width(110)
                TableColumn(L10n.s("blame.col.author")) { l in Text(l.author).lineLimit(1).truncationMode(.tail) }.width(120)
                TableColumn(L10n.s("blame.col.date")) { l in Text(l.authorTime.prefix(10)).monospaced() }.width(90)
                TableColumn(L10n.s("blame.col.content")) { l in
                    Text(l.content).contextMenu {
                        Button(L10n.s("blame.prevRevision")) {
                            blamePreviousRevision(line: l)
                        }
                        Button(L10n.s("blame.ctx.copyLine")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(l.content, forType: .string)
                        }
                    }
                }
            }
        }
        .padding(16)
        .overlay(alignment: .bottom) { StatusBarView(text: status, isLoading: running) }
        .frame(minWidth: 880, minHeight: 560)
        .onAppear { if let f = initialFile, !f.isEmpty { filePath = f; reload() } }
    }

    @ViewBuilder private var breadcrumb: some View {
        if !blameStack.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<blameStack.count, id: \.self) { i in
                        let item = blameStack[i]
                        Button {
                            let dropCount = blameStack.count - i
                            if dropCount > 0 {
                                blameStack.removeLast(dropCount)
                            }
                            filePath = item.file
                            reload(at: item.sha)
                        } label: {
                            Text(L10n.f("blame.backTo", String(item.sha.prefix(7))))
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        if i < blameStack.count - 1 {
                            Text("→").foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            let root = repoRoot.standardizedFileURL.path
            let p = url.standardizedFileURL.path
            if p.hasPrefix(root) {
                filePath = String(p.dropFirst(root.count + 1))
            } else {
                filePath = p
            }
        }
    }

    private func reload() {
        let f = filePath.trimmingCharacters(in: .whitespaces)
        guard !f.isEmpty else { status = L10n.s("blame.fillPath"); return }
        running = true; status = L10n.s("blame.tracing")
        Task {
            let result = await Task.detached { BlameQuery.blame(root: self.repoRoot, file: f) }.value
            lines = result
            status = result.isEmpty ? L10n.s("blame.empty") : L10n.f("blame.numLines", result.count)
            running = false
        }
    }

    private func reload(at sha: String) {
        running = true; status = L10n.s("blame.tracing")
        let f = filePath
        Task {
            let result = await Task.detached { BlameQuery.blame(root: self.repoRoot, file: f, revision: sha) }.value
            lines = result
            status = result.isEmpty ? L10n.s("blame.empty") : L10n.f("blame.numLines", result.count)
            running = false
        }
    }

    private func blamePreviousRevision(line: BlameQuery.Line) {
        guard blameStack.count < 20 else {
            status = L10n.s("blame.maxDepth")
            return
        }
        let sha = line.sourceSha
        Task {
            let parentSHA = await GitTaskHelper.runOptional(
                ["rev-parse", "\(sha)^"], in: repoRoot, timeout: 15)
            guard let parentSHA, parentSHA.isSuccess else {
                status = L10n.s("blame.noParent")
                return
            }
            let parent = parentSHA.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            blameStack.append((sha: sha, file: filePath))
            reload(at: parent)
        }
    }
}