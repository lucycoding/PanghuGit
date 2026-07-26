import SwiftUI
import AppKit

struct WorktreeView: View {
    let repoRoot: URL

    struct WorktreeEntry: Identifiable {
        let id: String
        let directory: String
        let branch: String
        let sha: String
        init(directory: String, branch: String, sha: String) {
            self.id = directory
            self.directory = directory
            self.branch = branch
            self.sha = sha
        }
    }

    @State private var worktrees: [WorktreeEntry] = []
    @State private var selection: WorktreeEntry.ID?
    @State private var newPath: String = ""
    @State private var newBranch: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showRemoveConfirm = false
    @State private var pendingRemovePath: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.f("worktree.title", worktrees.count)).font(.headline)
                Spacer()
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
            }

            if worktrees.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Text(L10n.s("worktree.empty"))
                        .foregroundStyle(.secondary).font(.title3)
                    Spacer()
                }
            } else {
                Table(worktrees, selection: $selection) {
                    TableColumn(L10n.s("worktree.path")) { w in
                        Text(w.directory).monospaced().lineLimit(1).truncationMode(.middle)
                            .accessibilityLabel(w.directory)
                            .contextMenu {
                                Button(L10n.s("common.copy")) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(w.directory, forType: .string)
                                }
                            }
                    }
                    TableColumn(L10n.s("worktree.branch")) { w in
                        Text(w.branch).monospaced()
                            .accessibilityLabel(w.branch)
                    }
                    TableColumn("") { w in
                        Button(L10n.s("worktree.remove")) {
                            pendingRemovePath = w.directory
                            showRemoveConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }.width(80)
                }
            }

            Divider()

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(L10n.s("worktree.newPath")).frame(width: 60, alignment: .leading).foregroundStyle(.secondary)
                        TextField("/path/to/new/worktree", text: $newPath).textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                newPath = url.path
                            }
                        } label: {
                            Image(systemName: "folder")
                        }.buttonStyle(.bordered).controlSize(.small)
                    }
                    HStack(spacing: 8) {
                        Text(L10n.s("worktree.newBranch")).frame(width: 60, alignment: .leading).foregroundStyle(.secondary)
                        TextField("branch-name", text: $newBranch).textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                    }
                    HStack {
                        Spacer()
                        Button(L10n.s("worktree.add")) { addWorktree() }
                            .buttonStyle(.borderedProminent)
                            .disabled(running || newPath.trimmingCharacters(in: .whitespaces).isEmpty || newBranch.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }

            StatusBarView(text: status, isError: error, isLoading: running)
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 480)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("worktree.removeConfirm"), isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button(L10n.s("worktree.remove"), role: .destructive) {
                removeWorktree(at: pendingRemovePath)
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.f("worktree.removeMsg", pendingRemovePath))
        }
        .onCopyCommand {
            if let id = selection, let w = worktrees.first(where: { $0.id == id }) {
                [NSItemProvider(object: NSString(string: w.directory))]
            } else {
                []
            }
        }
    }

    private func reload() {
        Task {
            let r = await GitTaskHelper.runOptional(["worktree", "list", "--porcelain"], in: repoRoot)
            if let r, r.isSuccess {
                worktrees = Self.parseWorktreeList(r.stdout)
                error = false
                status = ""
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
                worktrees = []
            }
        }
    }

    private func addWorktree() {
        let path = newPath.trimmingCharacters(in: .whitespaces)
        let branch = newBranch.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty, !branch.isEmpty else { return }
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["worktree", "add", "--", path, branch], in: repoRoot, timeout: 60)
            if let r, r.isSuccess {
                error = false
                status = L10n.s("common.done")
                newPath = ""
                newBranch = ""
                reload()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func removeWorktree(at path: String) {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["worktree", "remove", "--", path], in: repoRoot)
            if let r, r.isSuccess {
                error = false
                status = L10n.s("common.done")
                reload()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    static func parseWorktreeList(_ output: String) -> [WorktreeEntry] {
        var entries: [WorktreeEntry] = []
        var directory = ""
        var branch = ""
        var sha = ""
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !directory.isEmpty {
                    entries.append(WorktreeEntry(directory: directory, branch: branch, sha: sha))
                }
                directory = ""; branch = ""; sha = ""
            } else if trimmed.hasPrefix("worktree ") {
                directory = String(trimmed.dropFirst("worktree ".count))
            } else if trimmed.hasPrefix("branch ") {
                branch = String(trimmed.dropFirst("branch ".count))
                if branch.hasPrefix("refs/heads/") {
                    branch = String(branch.dropFirst("refs/heads/".count))
                }
            } else if trimmed.hasPrefix("HEAD ") {
                sha = String(trimmed.dropFirst("HEAD ".count))
            }
        }
        if !directory.isEmpty {
            entries.append(WorktreeEntry(directory: directory, branch: branch, sha: sha))
        }
        return entries
    }
}
