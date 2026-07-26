import SwiftUI
import AppKit

/// Submodule 视图（F-16）
struct SubmoduleView: View {
    let repoRoot: URL

    @State private var entries: [SubmoduleQuery.Entry] = []
    @State private var selection: SubmoduleQuery.Entry?
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showDeinitConfirm = false
    @State private var pendingDeinitPath: String?

    // 新增
    @State private var newURL: String = "https://"
    @State private var newPath: String = ""
    @State private var newBranch: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                list.frame(minWidth: 280)
                detail.frame(minWidth: 320, idealWidth: 440)
            }
            Divider()
            createRow
        }
        .padding(16)
        .overlay(alignment: .bottom) { StatusBarView(text: status, isError: error, isLoading: running) }
        .frame(minWidth: 760, minHeight: 540)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("submodule.deinitConfirm"), isPresented: $showDeinitConfirm, titleVisibility: .visible) {
            Button(L10n.s("submodule.deinit"), role: .destructive) {
                if let path = pendingDeinitPath {
                    run { SubmoduleQuery.deinitialize(root: repoRoot, path: path) }
                }
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            if let p = pendingDeinitPath {
                Text(L10n.f("submodule.deinitMessage", p))
            }
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.f("submodule.titleCount", entries.count)).font(.headline)
            Spacer()
            Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
            Button(L10n.s("submodule.sync")) { syncSubmodules() }.buttonStyle(.bordered)
                .disabled(running)
            Button(L10n.s("submodule.updateAll")) { updateAll() }.buttonStyle(.bordered)
                .disabled(running)
            Button(L10n.s("submodule.updateInit")) { update() }.buttonStyle(.bordered)
                .disabled(running)
            Button(L10n.s("submodule.updateRecursive")) { update(recursive: true) }.buttonStyle(.bordered)
                .disabled(running)
        }.padding(10)
    }

    private var list: some View {
        VStack(spacing: 0) {
            if entries.isEmpty && !running {
                EmptyStateView(message: L10n.s("submodule.empty"), systemImage: "square.stack")
            }
            List(entries, id: \.id, selection: $selection) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.path).monospaced()
                    Text(e.sha).font(.caption).foregroundStyle(.tint)
                    Text(e.url).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                }.padding(.vertical, 2).tag(e)
                .contextMenu {
                    Button(L10n.s("common.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(e.path, forType: .string)
                    }
                }
                .onCopyCommand { [NSItemProvider(object: NSString(string: e.path))] }
            }
            .onChange(of: selection) { _ in status = "" }
        }
    }

    @ViewBuilder private var detail: some View {
        if let e = selection {
            VStack(alignment: .leading, spacing: 8) {
                GroupBox(L10n.s("submodule.detail")) {
                    VStack(alignment: .leading, spacing: 6) {
                        row(L10n.s("submodule.col.path"), e.path)
                        row(L10n.s("submodule.col.sha"), e.sha)
                        row(L10n.s("submodule.col.branch"), e.branch ?? L10n.s("submodule.defaultBranch"))
                        row(L10n.s("submodule.col.url"), e.url)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button(L10n.s("submodule.deinit")) { pendingDeinitPath = e.path; showDeinitConfirm = true }
                        .tint(.red)
                        .disabled(running)
                }
                Spacer()
            }.padding(12)
        } else {
            EmptyStateView(message: L10n.s("submodule.selectHint"))
        }
    }

    private var createRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(L10n.s("submodule.newURL")).foregroundStyle(.secondary)
                TextField("https://...", text: $newURL).textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                Text(L10n.s("submodule.newPath")).foregroundStyle(.secondary)
                TextField("modules/foo", text: $newPath).textFieldStyle(.roundedBorder)
                Text(L10n.s("submodule.branchOptional")).foregroundStyle(.secondary)
                TextField("main", text: $newBranch).textFieldStyle(.roundedBorder)
                Button(L10n.s("submodule.add")) { add() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || newURL.trimmingCharacters(in: .whitespaces).isEmpty
                               || newPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(l).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
            Text(v).monospaced().lineLimit(1).truncationMode(.middle)
            Spacer()
        }
    }

    // MARK: - 行为

    private func reload() {
        Task {
            let list = await Task.detached { SubmoduleQuery.list(root: self.repoRoot) }.value
            entries = list
            status = ""; error = false
            if let s = selection, !list.contains(where: { $0.path == s.path }) {
                selection = list.first
            } else if let s = selection, let updated = list.first(where: { $0.path == s.path }) {
                selection = updated
            }
        }
    }

    private func add() {
        let url = newURL.trimmingCharacters(in: .whitespaces)
        let path = newPath.trimmingCharacters(in: .whitespaces)
        let branch = newBranch.trimmingCharacters(in: .whitespaces)
        run { SubmoduleQuery.add(root: repoRoot, url: url, path: path, branch: branch.isEmpty ? nil : branch) }
    }

    private func update(recursive: Bool = false) {
        run { SubmoduleQuery.update(root: repoRoot, initIfNeeded: true, recursive: recursive) }
    }

    private func syncSubmodules() {
        run { SubmoduleQuery.sync(root: repoRoot) }
    }

    private func updateAll() {
        run { SubmoduleQuery.update(root: repoRoot, initIfNeeded: true, recursive: true) }
    }

    private func run(_ block: @escaping () -> GitCommandResult?) {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await Task.detached { block() }.value
            if let r, r.isSuccess {
                status = L10n.s("common.done")
                newURL = "https://"; newPath = ""; newBranch = ""
                SettingsStore.postBadgeRefresh()
                reload()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
                running = false
            }
        }
    }
}