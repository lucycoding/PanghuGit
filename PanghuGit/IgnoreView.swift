import SwiftUI
import AppKit

/// 将选中文件 / 文件夹加入 `.gitignore`。
/// PRD F-14：右键 -> Git Add to .gitignore
struct IgnoreView: View {
    let repoRoot: URL
    let candidates: [URL]   // 来自 Finder Sync selected 列表

    @State private var rules: [Rule] = []
    @State private var recursive = false
    @State private var status: String = ""
    @State private var error = false
    @State private var running = false
    @State private var existingContent: String = ""

    struct Rule: Identifiable {
        let id = UUID()
        let path: String           // 候选相对仓库根的路径
        var enabled: Bool = true
        var pattern: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.s("ignore.title")).font(.headline)

            GroupBox(L10n.s("ignore.candidates")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L10n.s("ignore.recursive"), isOn: $recursive)
                        .onChange(of: recursive) { _ in rebuildPatterns() }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach($rules) { $rule in
                                HStack {
                                    Toggle("", isOn: $rule.enabled).labelsHidden()
                                    Text(rule.path).font(.system(.body, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Text(rule.pattern).font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary)
                                }
                            }
                        }.padding(6)
                    }.frame(maxHeight: 200)
                }.padding(8)
            }

            GroupBox(L10n.s("ignore.existingPreview")) {
                ScrollView {
                    Text(previewContent)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }.frame(maxHeight: .infinity)
            }

            StatusBarView(text: status, isError: error, isLoading: running) {
                Button(L10n.s("ignore.cancel")) { NSApp.keyWindow?.close() }
                Button(L10n.s("ignore.writeAndStage")) { write() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || rules.allSatisfy { !$0.enabled })
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 520)
        .onAppear { prepare(); loadExistingContent() }
    }

    private func loadExistingContent() {
        let fileURL = repoRoot.appendingPathComponent(".gitignore")
        existingContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    private var previewContent: String {
        let addition = rules.filter(\.enabled).map(\.pattern).joined(separator: "\n")
        let sep = existingContent.isEmpty || existingContent.hasSuffix("\n") ? "" : "\n"
        return existingContent + sep + addition + "\n"
    }

    // MARK: - 准备

    private func prepare() {
        rules = candidates.compactMap { candidate in
            guard let rel = relativePath(of: candidate) else { return nil }
            return Rule(path: rel, enabled: true, pattern: pattern(for: rel))
        }
        if rules.isEmpty {
            status = L10n.s("ignore.noCandidates")
            error = true
        }
    }

    private func rebuildPatterns() {
        rules = rules.map { item in
            var copy = item
            copy.pattern = pattern(for: item.path)
            return copy
        }
    }

    private func relativePath(of url: URL) -> String? {
        let root = repoRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root) else { return nil }
        var rel = String(path.dropFirst(root.count))
        if rel.hasPrefix("/") { rel.removeFirst() }
        return rel.isEmpty ? nil : rel
    }

    private func pattern(for rel: String) -> String {
        let isDir = (try? url(forPath: rel).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        var p = rel
        // 转义空格以便 .gitignore 安全
        if p.contains(" ") { p = "\\ " + p.split(separator: " ").joined(separator: "\\ ") }
        if recursive && isDir {
            // 文件夹整体忽略：自动加 /*
            if !p.hasSuffix("/*") { p += "/*" }
        }
        return p
    }

    private func url(forPath rel: String) -> URL {
        repoRoot.appendingPathComponent(rel)
    }

    // MARK: - 写入

    private func write() {
        running = true; error = false; status = L10n.s("common.running")
        let toAdd = rules.filter(\.enabled).map(\.pattern)
        guard !toAdd.isEmpty else { running = false; return }
        let fileURL = repoRoot.appendingPathComponent(".gitignore")
        let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let sep = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
        let newContent = existing + sep + toAdd.joined(separator: "\n") + "\n"
        Task {
            do {
                try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                self.error = true; status = L10n.f("common.failed", error.localizedDescription); running = false
                return
            }
            _ = await GitTaskHelper.runOptional(["add", "--", ".gitignore"], in: repoRoot)
            status = L10n.s("common.done")
            running = false
            existingContent = newContent
        }
    }
}