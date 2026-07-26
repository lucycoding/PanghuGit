import SwiftUI
import AppKit

struct StashView: View {
    let repoRoot: URL

    @State private var entries: [StashQuery.Entry] = []
    @State private var selection: StashQuery.Entry?
    @State private var newMessage: String = ""
    @State private var includeUntracked = false
    @State private var keepIndex = false
    @State private var patch: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showDropConfirm = false
    @State private var showStashBranch = false
    @State private var stashBranchName = ""
    @State private var stashBranchRef = ""
    @State private var stashFiles: [String] = []
    @State private var stashFileDiff: String = ""
    @State private var selectedStashFile: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.f("stash.title", entries.count)).font(.headline)
                Spacer()
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
            }.padding(10)
            Divider()
            HSplitView {
                list.frame(minWidth: 260)
                detail.frame(minWidth: 360, idealWidth: 520)
            }
            bottomBar
        }
        .padding(16)
        .frame(minWidth: 880, minHeight: 560)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("stash.dropConfirm"), isPresented: $showDropConfirm, titleVisibility: .visible) {
            Button(L10n.s("common.delete"), role: .destructive) {
                if let e = selection { runWrap { StashQuery.drop(root: repoRoot, ref: e.ref) } }
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            if let e = selection {
                Text(L10n.f("stash.dropMessage", e.ref, e.message))
            }
        }
        .alert(L10n.s("stash.createBranch"), isPresented: $showStashBranch) {
            TextField(L10n.s("stash.branchName"), text: $stashBranchName)
            Button(L10n.s("stash.createBranch")) {
                let name = stashBranchName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let ref = stashBranchRef
                running = true; error = false; status = L10n.s("common.running")
                Task {
                    let r = await GitTaskHelper.runOptional(
                        ["stash", "branch", "--", name, ref], in: repoRoot, timeout: 30)
                    if let r, r.isSuccess {
                        status = L10n.s("common.done")
                        SettingsStore.postBadgeRefresh()
                        reload()
                    } else {
                        error = true
                        status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
                        running = false
                    }
                }
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - 列表

    private var list: some View {
        VStack(spacing: 0) {
            if entries.isEmpty && !running {
                EmptyStateView(message: L10n.s("stash.empty"), systemImage: "tray")
            }
            List(entries, id: \.id, selection: $selection) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.ref).monospaced().font(.caption).foregroundStyle(.tint)
                    Text(e.message).lineLimit(1).truncationMode(.tail)
                }
                .padding(.vertical, 2)
                .tag(e)
                .contextMenu {
                    Button(L10n.s("common.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(e.ref, forType: .string)
                    }
                    Button(L10n.s("stash.createBranch")) {
                        stashBranchName = ""
                        stashBranchRef = e.ref
                        showStashBranch = true
                    }
                }
                .onCopyCommand { [NSItemProvider(object: NSString(string: e.ref))] }
            }
            .onChange(of: selection) { _ in loadPatch() }
            .onChange(of: selectedStashFile) { _ in loadStashFileDiff() }
        }
    }

    @ViewBuilder private var detail: some View {
        if selection != nil {
            VStack(alignment: .leading, spacing: 10) {
                HSplitView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.s("stash.files")).font(.headline)
                        List(stashFiles, id: \.self, selection: $selectedStashFile) { file in
                            Text(file).monospaced().lineLimit(1).truncationMode(.middle)
                        }
                        .frame(minWidth: 180)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        if let f = selectedStashFile {
                            Text(f).font(.caption).foregroundStyle(.secondary)
                            ScrollView {
                                Text(stashFileDiff.isEmpty ? L10n.s("stash.noPatch") : stashFileDiff)
                                    .font(.system(.callout, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(6)
                            }
                        } else {
                            EmptyStateView(message: L10n.s("stash.selectFileHint"))
                        }
                    }
                }
            }.padding(12)
        } else {
            VStack(spacing: 12) {
                GroupBox(L10n.s("stash.newStashTitle")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(L10n.s("stash.messagePlaceholder"), text: $newMessage).textFieldStyle(.roundedBorder)
                        Toggle(L10n.s("stash.includeUntracked"), isOn: $includeUntracked)
                        Toggle(L10n.s("stash.keepIndex"), isOn: $keepIndex)
                        Button(L10n.s("stash.push")) { push() }
                            .buttonStyle(.borderedProminent)
                            .disabled(running)
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                EmptyStateView(message: L10n.s("stash.selectHint"))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 底栏

    private var bottomBar: some View {
        StatusBarView(text: status, isError: error, isLoading: running) {
            Button(L10n.s("stash.apply")) { apply() }
                .disabled(selection == nil || running)
            Button(L10n.s("stash.pop")) { pop() }
                .disabled(selection == nil || running)
            Button(L10n.s("stash.drop")) { showDropConfirm = true }
                .tint(.red)
                .disabled(selection == nil || running)
            Button(L10n.s("stash.pushNew")) { push() }
                .buttonStyle(.borderedProminent)
                .disabled(running)
        }
    }

    // MARK: - 行为

    private func reload() {
        Task {
            let result = await Task.detached { StashQuery.list(root: self.repoRoot) }.value
            entries = result.values
            if case .failure(let msg) = result {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(msg))
            } else {
                error = false
                status = ""
            }
            if let first = result.values.first {
                selection = first
            } else {
                selection = nil
                patch = ""
            }
        }
    }

    private func loadPatch() {
        guard let e = selection else { patch = ""; return }
        stashFileDiff = ""
        selectedStashFile = nil
        let ref = e.ref
        Task {
            let files = await Task.detached { StashQuery.fileList(root: self.repoRoot, ref: ref) }.value
            let p = await Task.detached { StashQuery.diff(root: self.repoRoot, ref: ref) }.value
            guard selection?.ref == ref else { return }
            stashFiles = files
            patch = p
        }
    }

    private func loadStashFileDiff() {
        guard let e = selection, let f = selectedStashFile else { stashFileDiff = ""; return }
        let ref = e.ref
        let file = f
        Task {
            let d = await Task.detached { StashQuery.fileDiff(root: self.repoRoot, ref: ref, file: file) }.value
            stashFileDiff = d
        }
    }

    private func push() {
        let msg = newMessage.isEmpty ? nil : newMessage
        let untracked = includeUntracked
        let keep = keepIndex
        runWrap {
            StashQuery.push(root: repoRoot, message: msg,
                            includeUntracked: untracked, keepIndex: keep)
        }
    }

    private func apply() {
        guard let e = selection else { return }
        runWrap { StashQuery.apply(root: repoRoot, ref: e.ref) }
    }

    private func pop() {
        guard let e = selection else { return }
        runWrap { StashQuery.pop(root: repoRoot, ref: e.ref) }
    }

    private func runWrap(_ block: @escaping () -> GitCommandResult?) {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let result = await Task.detached { block() }.value
            if let r = result, r.isSuccess {
                status = L10n.s("common.done")
                newMessage = ""
                SettingsStore.postBadgeRefresh()
                reload()
            } else {
                let conflicts = await Task.detached { MergeQuery.conflicts(root: self.repoRoot) }.value
                if !conflicts.isEmpty {
                    error = true
                    status = L10n.f("merge.failedWithConflicts", conflicts.count)
                    showConflict()
                } else {
                    error = true
                    status = L10n.f("common.failed", GitErrorMessage.friendly(result?.stderr ?? ""))
                }
                running = false
            }
        }
    }

    private func showConflict() {
        HostWindow.show(id: "conflict-\(repoRoot.path)", title: "PanghuGit · " + L10n.s("conflict.title")) {
            ConflictResolverView(repoRoot: repoRoot)
        }
    }
}