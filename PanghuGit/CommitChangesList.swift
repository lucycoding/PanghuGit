import SwiftUI
import AppKit

extension CommitView {

    // MARK: - 改动列表

    var changesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.f("commit.changes", entries.count)).font(.headline)
                    .accessibilityLabel(L10n.f("commit.changes", entries.count))
                Spacer()
                Button(L10n.s("commit.selectAll")) { selectAll() }.buttonStyle(.bordered).controlSize(.small)
                Button(L10n.s("commit.deselectAll")) { selection.removeAll() }.buttonStyle(.bordered).controlSize(.small)
                Button(L10n.s("commit.refresh")) { reload() }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
                Button(L10n.s("commit.ctx.stageFile")) { stageSelected() }.buttonStyle(.bordered).keyboardShortcut("s", modifiers: [.command, .shift])
                Button(L10n.s("commit.ctx.unstageFile")) { unstageSelected() }.buttonStyle(.bordered).keyboardShortcut("s", modifiers: [.command, .option])
            }.padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !stagedEntries.isEmpty {
                        sectionHeader(
                            title: L10n.f("commit.section.staged", stagedEntries.count),
                            color: .green,
                            allPaths: stagedEntries.map(\.path)
                        )
                        ForEach(stagedEntries, id: \.path) { entry in
                            fileRow(entry)
                        }
                    }
                    if !modifiedEntries.isEmpty {
                        sectionHeader(
                            title: L10n.f("commit.section.modified", modifiedEntries.count),
                            color: .orange,
                            allPaths: modifiedEntries.map(\.path)
                        )
                        ForEach(modifiedEntries, id: \.path) { entry in
                            fileRow(entry)
                        }
                    }
                    if !untrackedEntries.isEmpty {
                        sectionHeader(
                            title: L10n.f("commit.section.untracked", untrackedEntries.count),
                            color: .gray,
                            allPaths: untrackedEntries.map(\.path)
                        )
                        ForEach(untrackedEntries, id: \.path) { entry in
                            fileRow(entry)
                        }
                        Button {
                            addToVersionControl(untrackedEntries.map(\.path))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text(L10n.s("commit.addToVersionControl"))
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.horizontal, 28).padding(.vertical, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func sectionHeader(title: String, color: Color, allPaths: [String]) -> some View {
        let allSelected = !allPaths.isEmpty && allPaths.allSatisfy { selection.contains($0) }
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { allSelected },
                set: { on in
                    if on { selection.formUnion(allPaths) }
                    else { selection.subtract(allPaths) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 2)
    }

    @ViewBuilder
    func fileRow(_ entry: GitStatusEntry) -> some View {
        let isSelected = selection.contains(entry.path)
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { on in
                    if on { selection.insert(entry.path) }
                    else { selection.remove(entry.path) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            StatusBadge(entry: entry)

            Text(entry.path).lineLimit(1).truncationMode(.middle)
                .font(.system(size: 12))
                .accessibilityLabel(entry.path)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 2)
        .background(diffSelection == entry.path ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            openFile(entry.path)
        }
        .onTapGesture {
            diffSelection = entry.path
            loadDiff(for: entry.path)
        }
        .contextMenu {
            Button(L10n.s("ctx.open")) {
                openFile(entry.path)
            }
            Button(L10n.s("ctx.openWith")) {
                openFileWith(entry.path)
            }
            Button(L10n.s("ctx.showInFinder")) {
                showInFinder(entry.path)
            }
            Divider()
            if entry.isUntracked {
                Button(L10n.s("commit.ctx.stageFile")) {
                    stageFiles([entry.path])
                }
                Button(L10n.s("commit.ctx.deleteFile")) {
                    deleteUntracked([entry.path])
                }
            } else if entry.staged != .unmodified && entry.worktree == .unmodified {
                Button(L10n.s("commit.ctx.unstageFile")) {
                    unstageFiles([entry.path])
                }
            } else if entry.worktree != .unmodified {
                if entry.staged == .unmodified {
                    Button(L10n.s("commit.ctx.stageFile")) {
                        stageFiles([entry.path])
                    }
                } else {
                    Button(L10n.s("commit.ctx.unstageFile")) {
                        unstageFiles([entry.path])
                    }
                }
                Button(L10n.s("commit.ctx.restoreFile")) {
                    restoreFiles([entry.path])
                }
            }
            Divider()
            Button(L10n.s("commit.ctx.openInDifftool")) {
                openDifftoolForFile(entry.path)
            }
        }
    }

    func selectAll() {
        selection = Set(entries.map(\.path))
    }

    func stageSelected() {
        let toStage = selection.filter { p in
            entries.contains { $0.path == p && ($0.staged == .unmodified || $0.staged == .untracked) }
        }
        if !toStage.isEmpty { stageFiles(Array(toStage)) }
    }

    func unstageSelected() {
        let toUnstage = selection.filter { p in
            entries.contains { $0.path == p && $0.staged != .unmodified && $0.staged != .untracked }
        }
        if !toUnstage.isEmpty { unstageFiles(Array(toUnstage)) }
    }

    func filterAuthorSuggestions() {
        let query = customAuthor.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { authorSuggestions = []; return }
        authorSuggestions = Array(allAuthors.filter { $0.lowercased().contains(query) }.prefix(5))
    }

    func addToVersionControl(_ paths: [String]) {
        Task {
            _ = await GitTaskHelper.runOptional(["add", "--"] + paths, in: repoRoot, timeout: 30)
            reload()
        }
    }

    func stageFiles(_ paths: [String]) {
        Task {
            _ = await GitTaskHelper.runOptional(["add", "--"] + paths, in: repoRoot, timeout: 30)
            selection.formUnion(paths)
            reload()
        }
    }

    func unstageFiles(_ paths: [String]) {
        Task {
            _ = await GitTaskHelper.runOptional(["reset", "HEAD", "--"] + paths, in: repoRoot, timeout: 30)
            selection.subtract(paths)
            reload()
        }
    }

    func openDifftoolForFile(_ path: String) {
        let tool = store.diffTool
        Task {
            _ = await GitTaskHelper.runOptional(
                ["difftool", "--tool=\(tool)", "--no-prompt", "--", path], in: repoRoot, timeout: 60)
        }
    }
}
