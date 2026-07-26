import SwiftUI
import AppKit

extension CommitView {

    // MARK: - 行为

    func reload() {
        Task {
            running = true
            let rawResult = await GitTaskHelper.runOptional(
                ["status", "--porcelain=v1", "-z", "--untracked-files=all"], in: repoRoot, timeout: 30)
            let logR = await GitTaskHelper.runOptional(
                ["log", "-n", "20", "--pretty=format:%s"], in: repoRoot)
            let lastMsgR = await GitTaskHelper.runOptional(
                ["log", "-1", "--pretty=format:%B"], in: repoRoot, timeout: 10)
            if !authorsLoaded {
                let authors = await Task.detached { RepoConfigQuery.authors(root: self.repoRoot) }.value
                allAuthors = authors
                authorsLoaded = true
            }
            if repoAuthorPlaceholder.isEmpty {
                let nameR = await GitTaskHelper.runOptional(["config", "user.name"], in: repoRoot)
                let emailR = await GitTaskHelper.runOptional(["config", "user.email"], in: repoRoot)
                let name = nameR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let email = emailR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !name.isEmpty || !email.isEmpty {
                    repoAuthorPlaceholder = "\(name) <\(email)>"
                } else {
                    let gNameR = await GitTaskHelper.runOptional(["config", "--global", "user.name"], in: repoRoot)
                    let gEmailR = await GitTaskHelper.runOptional(["config", "--global", "user.email"], in: repoRoot)
                    let gName = gNameR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let gEmail = gEmailR?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !gName.isEmpty || !gEmail.isEmpty {
                        repoAuthorPlaceholder = "\(gName) <\(gEmail)>"
                    }
                }
            }
            running = false
            guard let rawResult, rawResult.isSuccess else {
                error = true
                statusLine = L10n.s("commit.cannotReadStatus")
                return
            }
            entries = parser.parse(rawResult.stdout)
            selection = Set(entries.filter { $0.staged != .unmodified && $0.staged != .untracked }.map(\.path))
            if let ds = diffSelection {
                if entries.contains(where: { $0.path == ds }) {
                    loadDiff(for: ds)
                } else {
                    diffSelection = entries.first?.path
                    diffText = ""
                    if let p = diffSelection { loadDiff(for: p) }
                }
            }
            if let logR, logR.isSuccess {
                recentMessages = logR.stdout.split(whereSeparator: \.isNewline)
                    .map { String($0) }
                    .filter { !$0.isEmpty }
            }
            if let lastMsgR, lastMsgR.isSuccess {
                lastCommitMessage = lastMsgR.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    func commit(pushToo: Bool, forceWithLease: Bool = false) {
        guard !running else { return }
        running = true
        error = false
        statusLine = L10n.s("commit.committing")
        let toAdd = Array(selection)
        let stagedPaths = Set(entries.filter { $0.staged != .unmodified && $0.staged != .untracked }.map(\.path))
        let toUnstage = Array(stagedPaths.subtracting(selection))
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldSkipHooks = skipHooks
        let shouldAmend = amendMode
        let shouldSignoff = signoff
        let shouldAuthor = customAuthor
        let capturedStagedHunks = stagedHunks
        let capturedDiffFileGroups = diffFileGroups
        Task {
            if !toUnstage.isEmpty {
                _ = await GitTaskHelper.runOptional(["reset", "HEAD", "--"] + toUnstage, in: repoRoot, timeout: 60)
            }
            if !toAdd.isEmpty {
                let hunkPaths = Set(capturedStagedHunks.compactMap { key -> String? in
                    let parts = key.split(separator: ":")
                    guard parts.count == 2, let idx = Int(parts[0]),
                          idx < capturedDiffFileGroups.count else { return nil }
                    return capturedDiffFileGroups[idx].filePath
                })
                let bulkAddPaths = toAdd.filter { !hunkPaths.contains($0) }
                if !bulkAddPaths.isEmpty {
                    let addResult = await GitTaskHelper.runOptional(["add", "--"] + bulkAddPaths, in: repoRoot, timeout: 60)
                    if let addResult, !addResult.isSuccess {
                        error = true; statusLine = GitErrorMessage.friendly(addResult.stderr)
                        running = false; return
                    }
                }
                for key in capturedStagedHunks {
                    let parts = key.split(separator: ":")
                    guard parts.count == 2,
                          let fileIdx = Int(parts[0]),
                          let hunkIdx = Int(parts[1]),
                          fileIdx < capturedDiffFileGroups.count,
                          hunkIdx < capturedDiffFileGroups[fileIdx].hunks.count else { continue }
                    let group = capturedDiffFileGroups[fileIdx]
                    let hunk = group.hunks[hunkIdx]
                    let patch = HunkParser.buildPatch(header: group.header, hunk: hunk)
                    let tempDir = NSTemporaryDirectory()
                    let tempPath = tempDir + UUID().uuidString + ".patch"
                    let tempURL = URL(fileURLWithPath: tempPath)
                    try? patch.write(to: tempURL, atomically: true, encoding: .utf8)
                    let r = await GitTaskHelper.runOptional(["apply", "--cached", tempPath], in: repoRoot, timeout: 30)
                    try? FileManager.default.removeItem(at: tempURL)
                    if let r, !r.isSuccess {
                        error = true; statusLine = GitErrorMessage.friendly(r.stderr)
                        running = false; return
                    }
                }
            }
            let commitArgs = buildCommitArgs(message: trimmed, amend: shouldAmend, skipHooks: shouldSkipHooks, signoff: shouldSignoff, customAuthor: shouldAuthor)
            let commitResult = await GitTaskHelper.runOptional(commitArgs, in: repoRoot, timeout: 60)
            if let cr = commitResult, !cr.isSuccess {
                error = true
                statusLine = cr.stderr.isEmpty ? L10n.s("commit.failedPure") : GitErrorMessage.friendly(cr.stderr)
                running = false; return
            }
            if pushToo {
                if shouldAmend && !forceWithLease {
                    let upstreamCheck = await GitTaskHelper.runOptional(
                        ["rev-parse", "--verify", "@{u}"], in: repoRoot, timeout: 60)
                    if upstreamCheck?.isSuccess == true {
                        let ancestorCheck = await GitTaskHelper.runOptional(
                            ["merge-base", "--is-ancestor", "HEAD@{1}", "@{u}"], in: repoRoot, timeout: 60)
                        if ancestorCheck?.isSuccess == true {
                            pendingPushWithForce = true
                            running = false
                            showAmendForceConfirm = true
                            return
                        }
                    }
                }
                var pushArgs = ["push"]
                if forceWithLease { pushArgs.append("--force-with-lease") }
                let pushResult = await GitTaskHelper.runOptional(pushArgs, in: repoRoot, timeout: 60)
                if let pr = pushResult, !pr.isSuccess {
                    error = true
                    statusLine = L10n.f("commit.commitOkPushFail", GitErrorMessage.friendly(pr.stderr))
                    running = false; return
                }
            }
            statusLine = pushToo ? L10n.s("commit.commitOkPush") : L10n.s("commit.commitOk")
            message = ""
            skipHooks = false
            amendMode = false
            signoff = false
            customAuthor = ""
            running = false
            SettingsStore.postBadgeRefresh()
            reload()
        }
    }

    func pushPending(forceWithLease: Bool) {
        running = true
        statusLine = L10n.s("common.running")
        Task {
            var pushArgs = ["push"]
            if forceWithLease { pushArgs.append("--force-with-lease") }
            let pushResult = await GitTaskHelper.runOptional(pushArgs, in: repoRoot, timeout: 60)
            if let pr = pushResult, !pr.isSuccess {
                error = true
                statusLine = L10n.f("commit.commitOkPushFail", GitErrorMessage.friendly(pr.stderr))
            } else {
                statusLine = L10n.s("commit.commitOkPush")
                message = ""
                skipHooks = false
                amendMode = false
                signoff = false
                customAuthor = ""
                SettingsStore.postBadgeRefresh()
                reload()
            }
            running = false
        }
    }

    func buildCommitArgs(message: String, amend: Bool, skipHooks: Bool, signoff: Bool, customAuthor: String) -> [String] {
        CommitArgsBuilder.build(message: message, amend: amend, skipHooks: skipHooks, signoff: signoff, customAuthor: customAuthor)
    }

    // MARK: - 显示辅助

    func openDiff(_ entry: GitStatusEntry) {
        let isStaged = entry.staged != .unmodified && entry.staged != .untracked
        let mode: DiffView.Mode = isStaged ? .stagedVsHEAD : .worktreeVsHEAD
        HostWindow.show(id: "commit-diff-\(entry.path)", title: L10n.f("hostwindow.title.diffFile", entry.path)) {
            DiffView(repoRoot: repoRoot, file: entry.path, initialMode: mode)
        }
    }

    func openFile(_ path: String) {
        let url = repoRoot.appendingPathComponent(path)
        NSWorkspace.shared.open(url)
    }

    func openFileWith(_ path: String) {
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

    func showInFinder(_ path: String) {
        let url = repoRoot.appendingPathComponent(path)
        NSWorkspace.shared.selectFile(url.standardizedFileURL.path, inFileViewerRootedAtPath: "")
    }

    func restoreFiles(_ paths: [String]) {
        pendingRestorePaths = paths
        showRestoreConfirm = true
    }

    func actuallyRestore(_ paths: [String]) {
        Task {
            let r = await GitTaskHelper.runOptional(["restore", "--"] + paths, in: repoRoot, timeout: 30)
            if let r, !r.isSuccess {
                error = true
                statusLine = GitErrorMessage.friendly(r.stderr)
            }
            if r?.isSuccess == true {
                SettingsStore.postBadgeRefresh()
            }
            reload()
        }
    }

    func deleteUntracked(_ paths: [String]) {
        pendingDeletePaths = paths
        showDeleteConfirm = true
    }

    func actuallyDeleteUntracked(_ paths: [String]) {
        Task {
            let r = await GitTaskHelper.runOptional(["clean", "-f", "--"] + paths, in: repoRoot, timeout: 30)
            if let r, !r.isSuccess {
                error = true
                statusLine = GitErrorMessage.friendly(r.stderr)
            }
            if r?.isSuccess == true {
                SettingsStore.postBadgeRefresh()
            }
            reload()
        }
    }

    func undoLastCommit() {
        running = true
        error = false
        statusLine = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["reset", "--soft", "HEAD~1"], in: repoRoot, timeout: 30)
            if let r, r.isSuccess {
                statusLine = L10n.s("common.done")
                SettingsStore.postBadgeRefresh()
                reload()
            } else {
                error = true
                statusLine = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }
}
