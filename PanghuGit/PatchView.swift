import SwiftUI
import AppKit

struct PatchView: View {
    let repoRoot: URL

    enum Mode: String, CaseIterable, Identifiable {
        case create = "create"
        case applyCommit = "applyCommit"
        case applyWorktree = "applyWorktree"
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .create: return L10n.s("patch.mode.create")
            case .applyCommit: return L10n.s("patch.mode.applyCommit")
            case .applyWorktree: return L10n.s("patch.mode.applyWorktree")
            }
        }
    }

    @State private var mode: Mode = .create
    @State private var fromRef: String = "HEAD"
    @State private var toRef: String = ""
    @State private var outputPath: String = ""
    @State private var patchPath: String = ""
    @State private var output: String = ""
    @State private var running = false
    @State private var error = false
    @State private var dryRunResult: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.localizedName).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(running)

            GroupBox(L10n.s("patch.params")) {
                switch mode {
                case .create: createForm
                default: applyForm
                }
            }

            if !output.isEmpty {
                GroupBox(L10n.s("patch.output")) {
                    ScrollView {
                        Text(output)
                            .font(.system(.callout, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(6)
                    }
                    .frame(maxHeight: .infinity)
                }
            }

            Divider()
            StatusBarView(text: output, isError: error, isLoading: running) {
                Button(L10n.s("common.execute")) { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || !canRun)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 400)
    }

    @ViewBuilder private var createForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.s("patch.from")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField("HEAD", text: $fromRef).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text(L10n.s("patch.to")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField(L10n.s("patch.toPlaceholder"), text: $toRef).textFieldStyle(.roundedBorder)
            }
            HStack {
                Text(L10n.s("patch.outputDir")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField(L10n.s("patch.outputDirPlaceholder"), text: $outputPath).textFieldStyle(.roundedBorder)
                Button(L10n.s("settings.choose")) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        outputPath = url.path
                    }
                }
                Button(L10n.s("patch.preview")) {
                    previewPatch()
                }.buttonStyle(.bordered).controlSize(.small)
                .disabled(running || fromRef.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text(L10n.s("patch.createHint")).font(.caption).foregroundStyle(.secondary)
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var applyForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.s("patch.patchFile")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField(L10n.s("patch.patchFilePlaceholder"), text: $patchPath).textFieldStyle(.roundedBorder)
                Button(L10n.s("settings.choose")) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [.init(filenameExtension: "patch") ?? .item]
                    if panel.runModal() == .OK, let url = panel.url {
                        patchPath = url.path
                    }
                }
            }
            HStack {
                Button(L10n.s("patch.dryRun")) { dryRun() }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(running || patchPath.trimmingCharacters(in: .whitespaces).isEmpty)
                if !dryRunResult.isEmpty {
                    Text(dryRunResult).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Text(mode == .applyCommit ? L10n.s("patch.applyCommitHint") : L10n.s("patch.applyWorktreeHint"))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canRun: Bool {
        switch mode {
        case .create: return !fromRef.trimmingCharacters(in: .whitespaces).isEmpty
        case .applyCommit, .applyWorktree: return !patchPath.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func run() {
        running = true; error = false; output = ""; dryRunResult = ""
        switch mode {
        case .create:
            let from = fromRef.trimmingCharacters(in: .whitespaces)
            let to = toRef.trimmingCharacters(in: .whitespaces)
            let out = outputPath.trimmingCharacters(in: .whitespaces).isEmpty
                ? repoRoot.path
                : outputPath.trimmingCharacters(in: .whitespaces)
            var args = ["format-patch", "-o", out]
            if to.isEmpty {
                args += ["-1", from]
            } else {
                args += ["\(from)..\(to)"]
            }
            Task {
                let r = await GitTaskHelper.runOptional(args, in: repoRoot)
                if let r, r.isSuccess {
                    output = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    error = true
                    output = GitErrorMessage.friendly(r?.stderr ?? "")
                }
                running = false
            }
        case .applyCommit:
            let path = patchPath.trimmingCharacters(in: .whitespaces)
            Task {
                let r = await GitTaskHelper.runOptional(["am", "--", path], in: repoRoot)
                if let r, r.isSuccess {
                    output = L10n.s("patch.applyOk")
                    SettingsStore.postBadgeRefresh()
                } else {
                    error = true
                    output = GitErrorMessage.friendly(r?.stderr ?? "")
                }
                running = false
            }
        case .applyWorktree:
            let path = patchPath.trimmingCharacters(in: .whitespaces)
            Task {
                let r = await GitTaskHelper.runOptional(["apply", "--", path], in: repoRoot)
                if let r, r.isSuccess {
                    output = L10n.s("patch.applyOk")
                    SettingsStore.postBadgeRefresh()
                } else {
                    error = true
                    output = GitErrorMessage.friendly(r?.stderr ?? "")
                }
                running = false
            }
        }
    }

    private func dryRun() {
        let path = patchPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        running = true; dryRunResult = L10n.s("common.running")
        let args: [String]
        if mode == .applyCommit {
            args = ["apply", "--check", "--", path]
        } else {
            args = ["apply", "--check", "--", path]
        }
        Task {
            let r = await GitTaskHelper.runOptional(args, in: repoRoot)
            if let r, r.isSuccess {
                dryRunResult = L10n.s("patch.dryRunOk")
            } else {
                dryRunResult = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func previewPatch() {
        let from = fromRef.trimmingCharacters(in: .whitespaces)
        let to = toRef.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty else { return }
        running = true; output = ""
        var args = ["format-patch", "--stdout"]
        if to.isEmpty {
            args += ["-1", from]
        } else {
            args += ["\(from)..\(to)"]
        }
        Task {
            let r = await GitTaskHelper.runOptional(args, in: repoRoot)
            if let r, r.isSuccess {
                output = r.stdout
            } else {
                error = true
                output = GitErrorMessage.friendly(r?.stderr ?? "")
            }
            running = false
        }
    }
}
