import SwiftUI
import AppKit

struct ModificationsView: View {
    let repoRoot: URL

    @ObservedObject private var store = SettingsStore.shared

    @State private var entries: [GitStatusEntry] = []
    @State private var selection: String?
    @State private var diffText: String = ""
    @State private var loading = false
    @State private var errorMessage: String = ""
    @State private var showRestoreConfirm = false
    @State private var pendingRestorePath: String = ""
    @State private var showDeleteConfirm = false
    @State private var pendingDeletePath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                listPane.frame(minWidth: 320)
                diffPane.frame(minWidth: 300, idealWidth: 500)
            }
        }
        .padding(16)
        .frame(minWidth: 800, minHeight: 500)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("commit.restore.confirmTitle"), isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button(L10n.s("commit.restore.execute"), role: .destructive) {
                actuallyRestore(pendingRestorePath)
            }
            Button(L10n.s("common.cancel"), role: .cancel) { pendingRestorePath = "" }
        } message: {
            Text(L10n.s("modifications.restore.confirmMsg"))
        }
        .confirmationDialog(L10n.s("commit.delete.confirmTitle"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.s("commit.delete.confirmAction"), role: .destructive) {
                actuallyDeleteUntracked(pendingDeletePath)
            }
            Button(L10n.s("common.cancel"), role: .cancel) { pendingDeletePath = "" }
        } message: {
            Text(L10n.f("commit.delete.confirmMsg", 1))
        }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.f("modifications.title", entries.count)).font(.headline)
                Spacer()
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
            }.padding(10)

            if entries.isEmpty && !loading {
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundStyle(.red).padding()
                } else {
                    Text(L10n.s("modifications.clean")).foregroundStyle(.green).padding()
                }
                Spacer()
            } else {
                List(entries, id: \.path, selection: $selection) { entry in
                    HStack(spacing: 8) {
                        StatusBadge(entry: entry)
                        Text(entry.path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        openFile(entry.path)
                    }
                    .onTapGesture {
                        selection = entry.path
                    }
                    .contextMenu {
                        Button(L10n.s("ctx.open")) {
                            openFile(entry.path)
                        }
                        Button(L10n.s("ctx.openWith")) {
                            openFileWith(entry.path)
                        }
                        Button(L10n.s("ctx.showInFinder")) {
                            showInFinder(entry.path)
                        }
                        Divider()
                        if entry.isUntracked {
                            Button(L10n.s("modifications.ctx.stage")) {
                                stageFile(entry.path)
                            }
                            Button(L10n.s("modifications.ctx.delete")) {
                                deleteUntracked(entry.path)
                            }
                        } else {
                            if entry.staged == .unmodified {
                                Button(L10n.s("modifications.ctx.stage")) {
                                    stageFile(entry.path)
                                }
                            } else {
                                Button(L10n.s("modifications.ctx.unstage")) {
                                    unstageFile(entry.path)
                                }
                            }
                            if entry.worktree != .unmodified {
                                Button(L10n.s("commit.ctx.restoreFile")) {
                                    pendingRestorePath = entry.path
                                    showRestoreConfirm = true
                                }
                            }
                        }
                        Divider()
                        Button(L10n.s("diff.openInDifftool")) {
                            openDifftool(for: entry.path)
                        }
                    }
                }
                .onChange(of: selection) { newPath in
                    if let newPath { loadDiff(for: newPath, root: repoRoot) }
                }
            }
        }
    }

    private var diffPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(selection ?? L10n.s("modifications.selectHint")).font(.headline).lineLimit(1)
                Spacer()
                if selection != nil {
                    Button(L10n.s("diff.openInDifftool")) { if let s = selection { openDifftool(for: s) } }.buttonStyle(.bordered)
                }
            }.padding(10)
            ScrollView {
                if diffText.isEmpty {
                    Text(L10n.s("diff.noDiff"))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(DiffLineRenderer.parse(diffText), id: \.id) { line in
                            DiffLineRenderer(line: line)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func reload() {
        loading = true
        Task {
            let r = await GitTaskHelper.runOptional(
                ["status", "--porcelain=v1", "-z", "--untracked-files=all"], in: repoRoot, timeout: 15)
            guard let r, r.isSuccess else {
                loading = false
                errorMessage = GitErrorMessage.friendly(r?.stderr ?? "")
                return
            }
            let parsed = GitStatusParser().parse(r.stdout)
            entries = parsed
            loading = false
            errorMessage = ""
            if let s = selection, !parsed.contains(where: { $0.path == s }) {
                selection = parsed.first?.path
                diffText = ""
            } else if selection == nil {
                selection = parsed.first?.path
            }
            if let first = selection ?? parsed.first?.path {
                loadDiff(for: first, root: repoRoot)
            }
        }
    }

    private func loadDiff(for path: String, root: URL) {
        Task {
            let r = await GitTaskHelper.runOptional(
                ["diff", "--no-color", "--", path], in: root, timeout: 15)
            let staged = await GitTaskHelper.runOptional(
                ["diff", "--cached", "--no-color", "--", path], in: root, timeout: 15)
            var combined = ""
            if let s = staged, s.isSuccess, !s.stdout.isEmpty {
                combined += s.stdout
            }
            if let r, r.isSuccess, !r.stdout.isEmpty {
                if !combined.isEmpty { combined += "\n" }
                combined += r.stdout
            }
            diffText = combined
        }
    }

    private func openDifftool(for path: String) {
        let tool = store.diffTool
        Task {
            _ = await GitTaskHelper.runOptional(
                ["difftool", "--tool=\(tool)", "--no-prompt", "--", path], in: repoRoot, timeout: 30)
        }
    }

    private func openFile(_ path: String) {
        let url = repoRoot.appendingPathComponent(path)
        NSWorkspace.shared.open(url)
    }

    private func openFileWith(_ path: String) {
        let url = repoRoot.appendingPathComponent(path)
        let panel = NSOpenPanel()
        panel.title = L10n.s("ctx.openWith")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L10n.s("ctx.open")
        panel.begin { response in
            guard response == .OK, let appURL = panel.url else { return }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
        }
    }

    private func showInFinder(_ path: String) {
        let url = repoRoot.appendingPathComponent(path)
        NSWorkspace.shared.selectFile(url.standardizedFileURL.path, inFileViewerRootedAtPath: "")
    }

    private func stageFile(_ path: String) {
        Task {
            _ = await GitTaskHelper.runOptional(["add", "--", path], in: repoRoot)
            reload()
        }
    }

    private func unstageFile(_ path: String) {
        Task {
            _ = await GitTaskHelper.runOptional(["reset", "HEAD", "--", path], in: repoRoot)
            reload()
        }
    }

    private func actuallyRestore(_ path: String) {
        Task {
            let r = await GitTaskHelper.runOptional(["restore", "--", path], in: repoRoot)
            if let r, !r.isSuccess {
                errorMessage = GitErrorMessage.friendly(r.stderr)
            }
            if let r, r.isSuccess {
                SettingsStore.postBadgeRefresh()
            }
            reload()
        }
    }

    private func deleteUntracked(_ path: String) {
        pendingDeletePath = path
        showDeleteConfirm = true
    }

    private func actuallyDeleteUntracked(_ path: String) {
        Task {
            let r = await GitTaskHelper.runOptional(["clean", "-f", "--", path], in: repoRoot)
            if let r, !r.isSuccess {
                errorMessage = GitErrorMessage.friendly(r.stderr)
            }
            if let r, r.isSuccess {
                SettingsStore.postBadgeRefresh()
            }
            reload()
        }
    }

}
