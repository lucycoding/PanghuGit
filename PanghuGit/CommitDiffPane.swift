import SwiftUI

extension CommitView {

    // MARK: - Diff 面板

    var diffPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(diffSelection ?? "").font(.headline).lineLimit(1).truncationMode(.middle)
                Spacer()
                if diffSelection != nil {
                    Button(L10n.s("diff.openInDifftool")) { openDiffForSelection() }.buttonStyle(.bordered)
                }
            }.padding(.horizontal, 10).padding(.top, 10)
            ScrollView {
                if diffText.isEmpty {
                    Text(L10n.s("diff.noDiff"))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                } else if diffFileGroups.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(DiffLineRenderer.parse(diffText), id: \.id) { line in
                            DiffLineRenderer(line: line)
                        }
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(diffFileGroups) { group in
                            ForEach(group.hunks) { hunk in
                                hunkView(group: group, hunk: hunk)
                            }
                        }
                    }
                }
            }
            if canStageHunk {
                HStack(spacing: 8) {
                    Spacer()
                    if !isStagedHunk {
                        Button(L10n.s("commit.stageHunk")) { stageFocusedHunk() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    if isStagedHunk {
                        Button(L10n.s("commit.unstageHunk")) { unstageFocusedHunk() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.regularMaterial)
            }
        }
    }

    var canStageHunk: Bool {
        guard let key = focusedHunkId,
              let path = diffSelection,
              let entry = entries.first(where: { $0.path == path }),
              !entry.isUntracked else { return false }
        let parts = key.split(separator: ":")
        guard parts.count == 2,
              let fileIdx = Int(parts[0]),
              let hunkIdx = Int(parts[1]),
              fileIdx < diffFileGroups.count,
              hunkIdx < diffFileGroups[fileIdx].hunks.count else { return false }
        let group = diffFileGroups[fileIdx]
        return !group.isBinary && (entry.worktree != .unmodified || entry.staged != .unmodified)
    }

    var isStagedHunk: Bool {
        guard let key = focusedHunkId else { return false }
        let parts = key.split(separator: ":")
        guard parts.count == 2,
              let fileIdx = Int(parts[0]),
              fileIdx < diffFileGroups.count else { return false }
        return diffFileGroups[fileIdx].origin == .staged
    }

    @ViewBuilder
    func hunkView(group: DiffFileGroup, hunk: DiffHunk) -> some View {
        let hunkKey = "\(group.id):\(hunk.id)"
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if group.origin == .worktree {
                    Toggle("", isOn: Binding(
                        get: { stagedHunks.contains(hunkKey) },
                        set: { on in
                            if on { stagedHunks.insert(hunkKey) }
                            else { stagedHunks.remove(hunkKey) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .controlSize(.small)
                }
                Text(hunk.header)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.08))
            .contentShape(Rectangle())
            .onTapGesture { focusedHunkId = hunkKey }

            ForEach(DiffLineRenderer.parse(hunk.header + "\n" + hunk.lines.joined(separator: "\n")), id: \.id) { line in
                DiffLineRenderer(line: line)
            }
        }
        .background(focusedHunkId == hunkKey ? Color.accentColor.opacity(0.06) : Color.clear)
    }

    func loadDiff(for path: String) {
        Task {
            let r = await GitTaskHelper.runOptional(
                ["diff", "--no-color", "--", path], in: repoRoot, timeout: 15)
            let staged = await GitTaskHelper.runOptional(
                ["diff", "--cached", "--no-color", "--", path], in: repoRoot, timeout: 15)
            var stagedGroups: [DiffFileGroup] = []
            var worktreeGroups: [DiffFileGroup] = []
            var combined = ""
            if let s = staged, s.isSuccess, !s.stdout.isEmpty {
                stagedGroups = HunkParser.parse(s.stdout, origin: .staged)
                combined += s.stdout
            }
            if let r, r.isSuccess, !r.stdout.isEmpty {
                if !combined.isEmpty { combined += "\n" }
                worktreeGroups = HunkParser.parse(r.stdout, origin: .worktree)
                combined += r.stdout
            }
            let allGroups = stagedGroups + worktreeGroups
            diffText = combined
            diffFileGroups = allGroups
            stagedHunks = []
            focusedHunkId = allGroups.first.flatMap { g in g.hunks.first.map { "\(g.id):\($0.id)" } }
        }
    }

    func stageFocusedHunk() {
        guard let key = focusedHunkId,
              let path = diffSelection else { return }
        let parts = key.split(separator: ":")
        guard parts.count == 2,
              let fileIdx = Int(parts[0]),
              let hunkIdx = Int(parts[1]),
              fileIdx < diffFileGroups.count,
              hunkIdx < diffFileGroups[fileIdx].hunks.count else { return }
        let hunk = diffFileGroups[fileIdx].hunks[hunkIdx]
        applyHunk(path: path, hunk: hunk, reverse: false)
    }

    func unstageFocusedHunk() {
        guard let key = focusedHunkId,
              let path = diffSelection else { return }
        let parts = key.split(separator: ":")
        guard parts.count == 2,
              let fileIdx = Int(parts[0]),
              let hunkIdx = Int(parts[1]),
              fileIdx < diffFileGroups.count,
              hunkIdx < diffFileGroups[fileIdx].hunks.count else { return }
        let group = diffFileGroups[fileIdx]
        guard group.origin == .staged else { return }
        let hunk = group.hunks[hunkIdx]
        applyHunk(path: path, hunk: hunk, reverse: true)
    }

    func applyHunk(path: String, hunk: DiffHunk, reverse: Bool) {
        let groupIdx = diffFileGroups.firstIndex(where: { $0.filePath == path }) ?? 0
        let group = diffFileGroups[groupIdx]
        let patch = HunkParser.buildPatch(header: group.header, hunk: hunk)
        let tempDir = NSTemporaryDirectory()
        let tempPath = tempDir + UUID().uuidString + ".patch"
        let tempURL = URL(fileURLWithPath: tempPath)
        do {
            try patch.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            statusLine = error.localizedDescription
            self.error = true
            return
        }
        let hunkKey = "\(groupIdx):\(hunk.id)"
        Task {
            var args = ["apply", "--cached"]
            if reverse { args.append("-R") }
            args.append(tempPath)
            let r = await GitTaskHelper.runOptional(args, in: repoRoot, timeout: 30)
            try? FileManager.default.removeItem(at: tempURL)
            if let r, !r.isSuccess {
                error = true
                statusLine = GitErrorMessage.friendly(r.stderr)
            } else {
                stagedHunks.remove(hunkKey)
                if r?.isSuccess == true {
                    SettingsStore.postBadgeRefresh()
                    reload()
                }
            }
        }
    }

    func openDiffForSelection() {
        guard let path = diffSelection,
              let entry = entries.first(where: { $0.path == path }) else { return }
        openDiff(entry)
    }
}
