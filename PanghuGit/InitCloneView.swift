import SwiftUI
import AppKit

struct InitCloneView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case initRepo = "init"
        case clone    = "clone"
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .initRepo: return L10n.s("init.mode.initRepo")
            case .clone:    return L10n.s("init.mode.clone")
            }
        }
    }

    let initialMode: Mode
    let proposedTarget: URL?

    @State private var mode: Mode
    @State private var targetPath: String = ""
    @State private var remoteURL: String = "https://"
    @State private var branch: String = ""
    @State private var running = false
    @State private var result: String = ""
    @State private var error = false

    init(initialMode: Mode, proposedTarget: URL?) {
        self.initialMode = initialMode
        self.proposedTarget = proposedTarget
        var m = initialMode
        if m == .initRepo,
           let proposedTarget,
           let _ = RepoProbe.root(at: proposedTarget) {
            // 已在仓库内，默认切到 clone 避免误操作
            m = .clone
        }
        _mode = State(initialValue: m)
        _targetPath = State(initialValue: proposedTarget?.path ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(L10n.s("init.modePicker"), selection: $mode) {
                ForEach(Mode.allCases) { Text($0.localizedName).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(running)

            Group {
                switch mode {
                case .initRepo: initForm
                case .clone:    cloneForm
                }
            }

            Divider()
            HStack {
                if running { ProgressView().scaleEffect(0.7) }
                if !result.isEmpty {
                    Text(result)
                        .foregroundStyle(error ? .red : .green)
                        .font(.callout)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                Button(running ? L10n.s("common.running") : L10n.s("common.execute")) { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || targetPath.isEmpty || (mode == .clone && !isValidRemote))
            }
        }
        .padding(16)
        .frame(minWidth: 540, minHeight: 360, alignment: .top)
    }

    @ViewBuilder private var initForm: some View {
        GroupBox(Mode.initRepo.localizedName) {
            VStack(alignment: .leading, spacing: 8) {
                fileField(label: L10n.s("init.targetDir"), placeholder: "/path/to/folder", selection: $targetPath, canPickDirectory: true)
                Text(L10n.s("init.hint")).font(.caption).foregroundStyle(.secondary)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var cloneForm: some View {
        GroupBox(Mode.clone.localizedName) {
            VStack(alignment: .leading, spacing: 8) {
                labeledField(label: L10n.s("init.remoteURL"), placeholder: "https://github.com/...", selection: $remoteURL)
                fileField(label: L10n.s("init.targetParent"), placeholder: "/path/to/parent", selection: $targetPath, canPickDirectory: true)
                labeledField(label: L10n.s("init.branchHint"), placeholder: "main", selection: $branch)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isValidRemote: Bool {
        guard let u = URL(string: remoteURL) else { return false }
        return u.scheme != nil || remoteURL.hasPrefix("git@")
    }

    private func run() {
        running = true
        let capturedMode = mode
        let tPath = targetPath
        let remote = remoteURL
        let br = branch
        Task {
            do {
                let outcome: String
                switch capturedMode {
                case .initRepo: outcome = try await Self.performInit(at: tPath)
                case .clone:    outcome = try await Self.performClone(remote: remote, branch: br, target: tPath)
                }
                error = false
                result = outcome
                SettingsStore.postBadgeRefresh()
            } catch {
                let msg = error.localizedDescription
                self.error = true
                result = L10n.f("common.failed", msg)
            }
            running = false
        }
    }

    private static func performInit(at path: String) async throws -> String {
        let url = URL(fileURLWithPath: (path as NSString).standardizingPath)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let defaultBranch = SettingsStore.shared.gitDefaultBranch.trimmingCharacters(in: .whitespaces)
        let branchArg = defaultBranch.isEmpty ? "main" : defaultBranch
        let r = try await GitTaskHelper.run(["init", "-b", branchArg], in: url)
        if !r.isSuccess { throw RuntimeError(r.stderr) }
        return L10n.f("init.initSuccess", url.path, branchArg)
    }

    private static func performClone(remote: String, branch: String, target: String) async throws -> String {
        guard URL(string: remote) != nil || remote.hasPrefix("git@") else { throw RuntimeError(L10n.s("init.invalidRemote")) }
        let parent = URL(fileURLWithPath: (target as NSString).standardizingPath)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        var args = ["clone", remote]
        if !branch.isEmpty { args += ["--branch", branch] }
        args += ["--", parent.path]
        let r = try await GitTaskHelper.run(args, in: parent, timeout: 120)
        if !r.isSuccess { throw RuntimeError(r.stderr) }
        return L10n.f("init.cloneSuccess", parent.path)
    }

    // MARK: - 小组件

    @ViewBuilder
    private func labeledField(label: String, placeholder: String, selection: Binding<String>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
            TextField(placeholder, text: selection).textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func fileField(label: String, placeholder: String, selection: Binding<String>, canPickDirectory: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
            TextField(placeholder, text: selection).textFieldStyle(.roundedBorder)
            Button(L10n.s("settings.choose")) {
                let panel = NSOpenPanel()
                panel.canChooseFiles = !canPickDirectory
                panel.canChooseDirectories = canPickDirectory
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    selection.wrappedValue = url.path
                }
            }
        }
    }
}

private struct RuntimeError: LocalizedError {
    let message: String
    init(_ m: String) { self.message = m }
    var errorDescription: String? { message }
}
