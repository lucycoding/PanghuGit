import SwiftUI
import AppKit

struct ConflictResolverView: View {
    let repoRoot: URL

    @State private var conflicts: [String] = []
    @State private var done: Set<String> = []
    @State private var inMerge = false
    @State private var inRebase = false
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showAbortConfirm = false
    @State private var selectedConflict: String?
    @State private var conflictFile: ConflictFile?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            mainContent
            Divider()
            bottomBar
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 560)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("conflict.abortConfirm"), isPresented: $showAbortConfirm, titleVisibility: .visible) {
            Button(L10n.s("conflict.abortAction"), role: .destructive) { performAbort() }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.s("conflict.abortMessage"))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.s("conflict.title")).font(.headline)
                Text(stateDescription()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
        }.padding(10)
    }

    @ViewBuilder private var mainContent: some View {
        if conflicts.isEmpty && !running {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text(L10n.s("conflict.noConflict")).foregroundStyle(.tertiary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                fileList.frame(minWidth: 240)
                detailPanel.frame(minWidth: 500, idealWidth: 640)
            }
        }
    }

    private var fileList: some View {
        List(conflicts, id: \.self, selection: $selectedConflict) { path in
            HStack {
                if done.contains(path) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                Text(path).monospaced().lineLimit(1).truncationMode(.middle)
            }
            .contextMenu {
                Button(L10n.s("conflict.markResolved")) { markResolved(path) }
                    .disabled(running || done.contains(path))
                Button(L10n.s("conflict.openEditor")) { openEditor(path) }
                Button(L10n.s("conflict.viewDiff")) { openDiff(path) }
            }
        }
        .onChange(of: selectedConflict) { newPath in
            if let newPath {
                loadConflictDetail(newPath)
            } else {
                conflictFile = nil
            }
        }
    }

    @ViewBuilder private var detailPanel: some View {
        if let path = selectedConflict {
            ConflictDetailView(
                repoRoot: repoRoot,
                filePath: path,
                conflictFile: $conflictFile
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "arrow.left.circle").foregroundStyle(.secondary)
                Text(L10n.s("conflict.selectFileHint")).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var bottomBar: some View {
        StatusBarView(text: status, isError: error, isLoading: running) {
            Button(L10n.s("conflict.abort")) { showAbortConfirm = true }
                .tint(.red)
                .disabled(running)
            Button(L10n.s("conflict.continue")) { `continue`() }
                .buttonStyle(.borderedProminent)
                .disabled(running || !allResolved)
        }
    }

    private var allResolved: Bool {
        !conflicts.isEmpty && conflicts.allSatisfy { done.contains($0) }
    }

    private func stateDescription() -> String {
        let kind: String = {
            if inRebase { return L10n.s("conflict.stateRebase") }
            if inMerge { return L10n.s("conflict.stateMerge") }
            return L10n.s("conflict.stateIdle")
        }()
        return L10n.f("conflict.stateFormat", kind, done.count, conflicts.count)
    }

    private func reload() {
        Task {
            let conflictList = await Task.detached { MergeQuery.conflicts(root: self.repoRoot) }.value
            let r = await GitTaskHelper.runOptional(
                ["status", "--porcelain=v1", "-z"], in: repoRoot)
            let allEntries = r.map { GitStatusParser().parse($0.stdout) } ?? []
            let entryMap = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.path, $0) })
            let resolvedSet = Set(conflictList.filter { path in
                guard let e = entryMap[path] else { return false }
                return !MergeQuery.isConflictXY(e.xy)
            })
            let mergeState = await Task.detached { MergeQuery.inMergeState(root: self.repoRoot) }.value
            let rebaseState = await Task.detached { MergeQuery.inRebaseState(root: self.repoRoot) }.value
            conflicts = conflictList
            done = resolvedSet
            inMerge = mergeState
            inRebase = rebaseState
            status = ""; error = false
            if let sel = selectedConflict, !conflictList.contains(sel) {
                selectedConflict = conflictList.first
            } else if selectedConflict == nil {
                selectedConflict = conflictList.first
            }
        }
    }

    private func loadConflictDetail(_ path: String) {
        Task {
            let fullPath = repoRoot.appendingPathComponent(path).path
            let rawContent = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
            let file = ConflictParser.parse(content: rawContent, path: path)
            conflictFile = file
        }
    }

    private func markResolved(_ path: String) {
        running = true; error = false
        Task {
            let r = await Task.detached { MergeQuery.markResolved(root: self.repoRoot, path: path) }.value
            if let r, r.isSuccess {
                done.insert(path)
                status = L10n.f("conflict.markedResolved", path)
                SettingsStore.postBadgeRefresh()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func openEditor(_ path: String) {
        let url = repoRoot.appendingPathComponent(path)
        NSWorkspace.shared.open(url)
    }

    private func openDiff(_ path: String) {
        HostWindow.show(id: "conflict-diff-\(path)", title: L10n.f("hostwindow.title.conflictDiff", path)) {
            DiffView(repoRoot: repoRoot, file: path)
        }
    }

    private func `continue`() {
        guard allResolved else { return }
        running = true; error = false
        status = L10n.s("conflict.continuing")
        let capturedInRebase = inRebase
        let capturedInMerge = inMerge
        Task {
            let r: GitCommandResult?
            if capturedInRebase {
                r = await Task.detached { MergeQuery.rebaseContinue(root: self.repoRoot) }.value
            } else if capturedInMerge {
                r = await Task.detached { MergeQuery.mergeContinue(root: self.repoRoot) }.value
            } else {
                r = nil
            }
            if let r, r.isSuccess {
                status = L10n.s("conflict.mergedDone")
                SettingsStore.postBadgeRefresh()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
            reload()
        }
    }

    private func performAbort() {
        running = true; error = false; status = L10n.s("conflict.aborting")
        let capturedInRebase = inRebase
        Task {
            let r: GitCommandResult?
            if capturedInRebase {
                r = await Task.detached { MergeQuery.rebaseAbort(root: self.repoRoot) }.value
            } else {
                r = await Task.detached { MergeQuery.mergeAbort(root: self.repoRoot) }.value
            }
            if let r, r.isSuccess {
                status = L10n.s("conflict.aborted")
                SettingsStore.postBadgeRefresh()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
            reload()
        }
    }
}
