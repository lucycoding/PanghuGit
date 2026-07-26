import SwiftUI
import AppKit

struct MergeRebaseView: View {
    let repoRoot: URL

    @State private var mode: Mode = .merge
    @State private var sourceBranch: String = ""
    @State private var branches: [BranchQuery.Branch] = []
    @State private var currentBranchName: String?
    @State private var inProgress = false
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showConflict = false

    enum Mode: String, CaseIterable, Identifiable {
        case merge = "merge"
        case rebase = "rebase"
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .merge:  return L10n.s("merge.mode.merge")
            case .rebase: return L10n.s("merge.mode.rebase")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.s("merge.currentBranch")).foregroundStyle(.secondary)
                Text(currentBranchName ?? L10n.s("switch.detached")).monospaced()
                Spacer()
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
            }

            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.localizedName).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(running)
            .onChange(of: mode) { _ in status = "" }

            GroupBox(L10n.s("merge.source")) {
                HStack(spacing: 8) {
                    Text(L10n.s("merge.targetRef")).foregroundStyle(.secondary)
                    TextField(L10n.s("merge.branchOrCommitPlaceholder"), text: $sourceBranch).textFieldStyle(.roundedBorder)
                    Menu(L10n.s("merge.selectBranch")) {
                        ForEach(branches.filter { $0.isRemote }, id: \.name) { b in
                            Button(b.name) { sourceBranch = b.name }
                        }
                        ForEach(branches.filter { !$0.isRemote && !$0.isHEAD }, id: \.name) { b in
                            Button(b.name) { sourceBranch = b.name }
                        }
                    }
                }
                .padding(8)
            }

            Divider()
            HStack(spacing: 12) {
                Spacer()
                if inProgress {
                    Button(L10n.s("merge.handleConflict")) { openConflict() }
                }
                Button(L10n.s("merge.execute")) { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || sourceBranch.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 540, minHeight: 360)
        .overlay(alignment: .bottom) {
            StatusBarView(text: status, isError: error, isLoading: running)
        }
        .onAppear { reload() }
    }

    // MARK: - 行为

    private func reload() {
        Task {
            let list = await Task.detached { BranchQuery.list(root: self.repoRoot) }.value
            let cur = await Task.detached { BranchQuery.currentBranch(at: self.repoRoot) }.value
            let inMerge = await Task.detached { MergeQuery.inMergeState(root: self.repoRoot) }.value
            let inRebase = await Task.detached { MergeQuery.inRebaseState(root: self.repoRoot) }.value
            branches = list.values
            currentBranchName = cur
            inProgress = inMerge || inRebase
            if case .failure(let msg) = list {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(msg))
            } else if inMerge || inRebase {
                error = false
                status = L10n.f("merge.inProgressHint", inRebase ? L10n.s("merge.rebaseMode") : L10n.s("merge.mergeMode"))
            } else {
                error = false
                status = ""
            }
        }
    }

    private func run() {
        running = true; error = false
        let src = sourceBranch.trimmingCharacters(in: .whitespaces)
        let capturedMode = mode
        status = L10n.f("merge.executing", mode.rawValue.lowercased(), src)
        Task {
            let result: GitCommandResult?
            switch capturedMode {
            case .merge:  result = await Task.detached { MergeQuery.merge(root: self.repoRoot, source: src) }.value
            case .rebase: result = await Task.detached { MergeQuery.rebase(root: self.repoRoot, source: src) }.value
            }
            if let r = result, r.isSuccess {
                status = L10n.f("merge.completed", capturedMode.localizedName)
                SettingsStore.postBadgeRefresh()
                reload()
            } else {
                error = true
                let stderr = result?.stderr ?? ""
                let stdout = result?.stdout ?? ""
                let conflicts = await Task.detached { MergeQuery.conflicts(root: self.repoRoot) }.value
                if conflicts.count > 0 {
                    status = L10n.f("merge.failedWithConflicts", conflicts.count)
                } else {
                    status = GitErrorMessage.friendly(stderr.isEmpty ? stdout : stderr)
                }
                running = false
                if !conflicts.isEmpty {
                    openConflict()
                }
            }
        }
    }

    private func openConflict() {
        HostWindow.show(id: "conflict-\(repoRoot.path)", title: "PanghuGit · " + L10n.s("conflict.title")) {
            ConflictResolverView(repoRoot: repoRoot)
        }
    }
}