import SwiftUI
import AppKit

/// Pull / Push / Fetch 合并面板。
struct SyncView: View {
    let repoRoot: URL

    @State private var remote: String = "origin"
    @State private var branch: String = ""
    @State private var currentBranchName: String?
    @State private var running = false
    @State private var output: String = ""
    @State private var error = false
    @State private var elapsedSeconds: Int = 0
    @State private var elapsedTimer: Timer?
    @State private var skipHooks = false
    @State private var forceMode: ForceMode = .none
    @State private var showForceConfirm = false
    @State private var forceOverwriteCount: Int = 0
    @State private var prune = false
    @State private var pushTags = false
    @State private var pullRebase = false
    @State private var knownRemoteBranches: Set<String> = []
    @State private var newRemoteBranches: [String] = []

    enum ForceMode: String, CaseIterable {
        case none, force, forceWithLease
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.s("sync.titleRepo")).font(.caption).foregroundStyle(.secondary)
                    Text(repoRoot.path).font(.system(.callout, design: .monospaced)).lineLimit(1).truncationMode(.head)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.s("sync.currentBranchLabel")).font(.caption).foregroundStyle(.secondary)
                    Text(currentBranchName ?? "—").monospaced()
                }
            }

            GroupBox(L10n.s("sync.remoteAndBranch")) {
                HStack(spacing: 8) {
                    TextField(L10n.s("sync.remotePlaceholder"), text: $remote).textFieldStyle(.roundedBorder)
                    Text("/").foregroundStyle(.secondary)
                    TextField(L10n.s("sync.branchPlaceholder"), text: $branch).textFieldStyle(.roundedBorder)
                    if let cur = currentBranchName, branch != cur {
                        Button(L10n.s("sync.useCurrent")) { branch = cur }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        var args = ["pull", remote] + extra
                        if pullRebase { args.append("--rebase") }
                        let shouldPersist = pullRebase
                        run(args, afterSuccess: {
                            Task {
                                _ = await GitTaskHelper.runOptional(
                                    ["config", "--local", "pull.rebase", shouldPersist ? "true" : "false"],
                                    in: self.repoRoot, timeout: 10)
                            }
                        })
                    } label: {
                        Label(L10n.s("sync.pull"), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(running)
                    .accessibilityLabel(L10n.s("sync.pull"))

                    Picker("", selection: $pullRebase) {
                        Text(L10n.s("sync.pullMode.merge")).tag(false)
                        Text(L10n.s("sync.pullMode.rebase")).tag(true)
                    }
                    .frame(width: 90)

                    Button {
                        if forceMode != .none {
                            checkForcePush()
                        } else {
                            performPush()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                            Text(L10n.s("sync.push"))
                        }
                        .foregroundStyle(forceMode != .none ? .white : .primary)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(forceMode != .none ? .red : .accentColor)
                    .disabled(running)
                    .accessibilityLabel(L10n.s("sync.push"))

                    Button {
                        fetchWithBranchDetection()
                    } label: {
                        Label(L10n.s("sync.fetch"), systemImage: "arrow.triangle.2.circlecircle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(running)
                    .accessibilityLabel(L10n.s("sync.fetch"))

                    Spacer()
                    Button(L10n.s("common.refresh")) { loadCurrentBranch() }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
                    if running {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.7)
                            Text(L10n.f("sync.elapsed", elapsedSeconds)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Toggle(isOn: $pushTags) {
                        Text(L10n.s("sync.pushTags"))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .foregroundStyle(pushTags ? .orange : .primary)
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $prune) {
                        Text(L10n.s("sync.prune"))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .foregroundStyle(prune ? .orange : .primary)
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $skipHooks) {
                        Text(L10n.s("sync.skipHooks"))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .foregroundStyle(skipHooks ? .orange : .primary)
                    }
                    .toggleStyle(.checkbox)

                    Picker("", selection: $forceMode) {
                        Text(L10n.s("sync.forceMode.none")).tag(ForceMode.none)
                        Text(L10n.s("sync.forceMode.force")).tag(ForceMode.force)
                        Text(L10n.s("sync.forceMode.forceWithLease")).tag(ForceMode.forceWithLease)
                    }
                    .frame(width: 140)

                    Spacer()
                }
            }

            if !newRemoteBranches.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.s("sync.newRemoteBranchesHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(newRemoteBranches, id: \.self) { name in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .foregroundStyle(.green)
                                Text(name)
                                    .font(.system(.callout, design: .monospaced))
                                    .textSelection(.enabled)
                                Spacer()
                                Button(L10n.s("sync.checkoutBranch")) {
                                    checkoutRemoteBranch(name)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(running)
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    HStack {
                        Text(L10n.s("sync.newRemoteBranches"))
                            .font(.callout).fontWeight(.medium)
                        Spacer()
                        Button {
                            newRemoteBranches = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.s("common.close"))
                    }
                }
            }

            GroupBox(L10n.s("sync.output")) {
                ScrollView {
                    Text(output.isEmpty ? L10n.s("sync.outputEmpty") : output)
                        .font(.system(.callout, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(6)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(minWidth: 780, minHeight: 460)
        .onAppear { loadCurrentBranch(); loadPullRebaseDefault() }
        .onDisappear {
            elapsedTimer?.invalidate()
            elapsedTimer = nil
        }
        .confirmationDialog(L10n.s("sync.forceConfirm.title"), isPresented: $showForceConfirm, titleVisibility: .visible) {
            Button(L10n.s("sync.forceConfirm.action"), role: .destructive) {
                performPush()
            }
            Button(L10n.s("common.cancel"), role: .cancel) {
                forceMode = .none
            }
        } message: {
            Text(L10n.f("sync.forceConfirm.msg", forceOverwriteCount))
        }
    }

    private func loadCurrentBranch() {
        Task {
            let cur = await Task.detached { BranchQuery.currentBranch(at: self.repoRoot) }.value
            currentBranchName = cur
            if branch.isEmpty, let cur { branch = cur }
        }
    }

    private var extra: [String] {
        let b = branch.trimmingCharacters(in: .whitespaces)
        guard !b.isEmpty else { return [] }
        return b.hasPrefix("-") ? ["--", b] : [b]
    }

    private func checkForcePush() {
        Task {
            let countR = await GitTaskHelper.runOptional(
                ["rev-list", "@{u}..HEAD", "--count"], in: repoRoot, timeout: 10)
            let count = Int(countR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
            forceOverwriteCount = count
            showForceConfirm = true
        }
    }

    private func performPush() {
        var args = ["push", remote] + extra
        switch forceMode {
        case .force: args.append("--force")
        case .forceWithLease: args.append("--force-with-lease")
        case .none: break
        }
        if pushTags { args.append("--tags") }
        if skipHooks { args.append("--no-verify") }
        let shouldResetFlags = forceMode != .none || pushTags || skipHooks
        run(args, onSuccess: shouldResetFlags ? { self.skipHooks = false; self.pushTags = false; self.forceMode = .none } : nil)
    }

    private func loadPullRebaseDefault() {
        Task {
            let r = await GitTaskHelper.runOptional(
                ["config", "--local", "pull.rebase"], in: repoRoot, timeout: 10)
            let val = r?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            pullRebase = (val == "true")
        }
    }

    // MARK: - Fetch 新分支检测与远程分支检出

    private nonisolated func remoteBranchNames() -> Set<String> {
        Set(BranchQuery.list(root: repoRoot).values
            .filter { $0.isRemote }
            .map { $0.name })
    }

    /// Fetch 前后对比远程分支列表，标记新增分支供用户一键检出。
    private func fetchWithBranchDetection() {
        Task {
            let before = await Task.detached { self.remoteBranchNames() }.value
            knownRemoteBranches = before
            var args = ["fetch", remote] + extra
            if prune { args.append("--prune") }
            let shouldResetPrune = prune
            run(args,
                onSuccess: shouldResetPrune ? { self.prune = false } : nil,
                afterSuccess: { self.detectNewRemoteBranches() })
        }
    }

    private func detectNewRemoteBranches() {
        Task {
            let now = await Task.detached { self.remoteBranchNames() }.value
            let added = now.subtracting(knownRemoteBranches).sorted()
            knownRemoteBranches = now
            newRemoteBranches = added
        }
    }

    /// 检出远程分支为本地跟踪分支并切换；已有同名本地分支则直接切换。
    private func checkoutRemoteBranch(_ fullName: String) {
        guard let localName = BranchQuery.Branch.localTrackingName(forRemote: fullName) else { return }
        Task {
            let locals = await Task.detached {
                Set(BranchQuery.list(root: self.repoRoot).values
                    .filter { !$0.isRemote }
                    .map { $0.name })
            }.value
            if locals.contains(localName) {
                performCheckout(args: ["checkout", localName],
                                display: localName, remoteFullName: fullName)
            } else {
                performCheckout(args: ["checkout", "-b", localName, "--track", fullName],
                                display: localName, remoteFullName: fullName)
            }
        }
    }

    private func performCheckout(args: [String], display: String, remoteFullName: String) {
        running = true; error = false
        output += "\n$ git \(args.joined(separator: " "))\n"
        Task {
            let r = await GitTaskHelper.runOptional(args, in: repoRoot, timeout: 60)
            if let r {
                let stdout = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let stderr = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                if !stdout.isEmpty { output += stdout }
                if !stderr.isEmpty { output += (stdout.isEmpty ? "" : "\n") + stderr }
                error = !r.isSuccess
                if r.isSuccess {
                    output += "\n\n" + L10n.f("switch.checkedOutRemote", display)
                    newRemoteBranches.removeAll { $0 == remoteFullName }
                    SettingsStore.postBadgeRefresh()
                }
            } else {
                error = true
                output += "\n" + L10n.s("common.gitFailed")
            }
            running = false
        }
    }

    /// 在 remote / branch 与潜在 pathspec 之间插入 `--`，避免 ref/path 歧义。
    private func run(_ args: [String], onSuccess: (() -> Void)? = nil, afterSuccess: (() -> Void)? = nil) {
        let safe: [String]
        if args.contains("--") {
            safe = args
        } else {
            safe = args + ["--"]
        }
        running = true; error = false; output = "$ git \(safe.joined(separator: " "))\n"
        elapsedSeconds = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedSeconds += 1
        }
        Task {
            let r = await GitTaskHelper.runOptional(safe, in: repoRoot, timeout: 120)
            if let r {
                output += r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if !r.stderr.isEmpty {
                    output += "\n" + r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                error = !r.isSuccess
                if r.isSuccess {
                    output += "\n\n" + L10n.s("sync.done")
                    onSuccess?()
                    afterSuccess?()
                    SettingsStore.postBadgeRefresh()
                }
            } else {
                error = true
                output += "\n" + L10n.s("common.gitFailed")
            }
            running = false
            elapsedTimer?.invalidate()
            elapsedTimer = nil
        }
    }
}