import SwiftUI
import AppKit

/// 撤销 / 重置面板（F-12）：
/// - Revert HEAD：`git revert HEAD --no-edit`
/// - Reset HEAD 到指定提交：可选 --soft / --mixed / --hard
/// - 还可撤销单文件工作区改动：`git restore -- <path>`（带确认）
struct RevertResetView: View {
    let repoRoot: URL

    @State private var mode: Mode = .revert
    @State private var targetRef: String = "HEAD"
    @State private var revertTarget: String = "HEAD"
    @State private var resetMode: ResetMode = .mixed
    @State private var filePath: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var currentBranchName: String?
    @State private var showHardConfirm = false
    @State private var pendingArgs: [String]?

    enum Mode: String, CaseIterable, Identifiable {
        case revert = "revert"
        case reset  = "reset"
        case discardFile = "discardFile"
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .revert:      return L10n.s("revert.revertHEAD")
            case .reset:       return L10n.s("revert.resetToCommit")
            case .discardFile: return L10n.s("revert.discardFile")
            }
        }
    }

    enum ResetMode: String, CaseIterable, Identifiable {
        case soft = "soft"
        case mixed = "mixed"
        case hard = "hard"
        var id: String { rawValue }
        var flag: String {
            switch self {
            case .soft:  return "--soft"
            case .mixed: return "--mixed"
            case .hard:  return "--hard"
            }
        }
        var localizedName: String {
            switch self {
            case .soft:  return L10n.s("revert.reset.soft")
            case .mixed: return L10n.s("revert.reset.mixed")
            case .hard:  return L10n.s("revert.reset.hard")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.localizedName).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(running)

            GroupBox(L10n.s("revert.params")) {
                switch mode {
                case .revert: revertForm
                case .reset:  resetForm
                case .discardFile: discardForm
                }
            }

            Divider()
            StatusBarView(text: status, isError: error, isLoading: running) {
                Button(L10n.s("revert.execute")) { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || !canRun)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
        .onAppear { loadCurrentBranch() }
        .confirmationDialog(L10n.s("revert.confirmHigh"), isPresented: $showHardConfirm, titleVisibility: .visible) {
            Button(L10n.s("revert.execute"), role: .destructive) {
                if let args = pendingArgs { actuallyRun(args) }
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            if let args = pendingArgs {
                Text("$ git " + args.joined(separator: " "))
            }
        }
    }

    private func loadCurrentBranch() {
        Task {
            let cur = await Task.detached { BranchQuery.currentBranch(at: self.repoRoot) }.value
            currentBranchName = cur
        }
    }

    private func browseCommit(field: String) {
        HostWindow.show(id: "revert-browse-\(field)", title: L10n.s("revert.browseTitle")) {
            CommitPickerView(repoRoot: repoRoot) { sha in
                if field == "revert" { revertTarget = sha }
                else { targetRef = sha }
            }
        }
    }

    @ViewBuilder private var revertForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.s("revert.revertTarget")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField("HEAD", text: $revertTarget).textFieldStyle(.roundedBorder)
                Button(L10n.s("revert.useHEAD")) { revertTarget = "HEAD" }
                Button(L10n.s("revert.browse")) { browseCommit(field: "revert") }
            }
            Text(L10n.s("revert.revertHint")).font(.caption).foregroundStyle(.secondary)
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var resetForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.s("revert.target")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField(L10n.s("revert.targetPlaceholder"), text: $targetRef).textFieldStyle(.roundedBorder)
                Button(L10n.s("revert.useHEAD")) { targetRef = "HEAD" }
                Button(L10n.s("revert.browse")) { browseCommit(field: "reset") }
            }
            Picker(L10n.s("revert.resetMode"), selection: $resetMode) {
                ForEach(ResetMode.allCases) { Text($0.localizedName).tag($0) }
            }
            .pickerStyle(.radioGroup)
            if resetMode == .hard {
                Text(L10n.s("revert.hardWarning")).foregroundStyle(.orange).font(.callout)
            }
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var discardForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.s("revert.file")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField(L10n.s("revert.filePathPlaceholder"), text: $filePath).textFieldStyle(.roundedBorder)
                Button(L10n.s("settings.choose")) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        let root = repoRoot.standardizedFileURL.path
                        let p = url.standardizedFileURL.path
                        if p.hasPrefix(root) {
                            filePath = String(p.dropFirst(root.count + 1))
                        }
                    }
                }
            }
            Text(L10n.s("revert.discardHint")).font(.caption).foregroundStyle(.secondary)
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 执行

    private var canRun: Bool {
        switch mode {
        case .revert: return !revertTarget.trimmingCharacters(in: .whitespaces).isEmpty
        case .reset:  return !targetRef.trimmingCharacters(in: .whitespaces).isEmpty
        case .discardFile: return !filePath.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func run() {
        switch mode {
        case .revert: actuallyRun(["revert", revertTarget.trimmingCharacters(in: .whitespaces), "--no-edit"])
        case .reset:
            let args = ["reset", resetMode.flag, "--", targetRef.trimmingCharacters(in: .whitespaces)]
            if resetMode == .hard {
                pendingArgs = args; showHardConfirm = true
            } else {
                actuallyRun(args)
            }
        case .discardFile:
            let args = ["restore", "--", filePath.trimmingCharacters(in: .whitespaces)]
            pendingArgs = args; showHardConfirm = true
        }
    }

    private func actuallyRun(_ args: [String]) {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(args, in: repoRoot)
            if let r, r.isSuccess {
                status = L10n.f("common.doneWithCmd", args.joined(separator: " "))
                SettingsStore.postBadgeRefresh()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }
}