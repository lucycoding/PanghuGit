import SwiftUI
import AppKit

/// 分支管理面板：本地/远程分支列表 + 新建 + 删除 + 重命名。
struct BranchManagerView: View {
    let repoRoot: URL

    @State private var branches: [BranchQuery.Branch] = []
    @State private var filter: String = ""
    @State private var selection: String? = nil
    @State private var newName: String = ""
    @State private var newNameFrom: String = ""
    @State private var renameTarget: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showDeleteConfirm = false

    private var selectedBranch: BranchQuery.Branch? {
        guard let name = selection else { return nil }
        return branches.first { $0.name == name }
    }

    private var filtered: [BranchQuery.Branch] {
        guard !filter.isEmpty else { return branches }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.s("branch.title")).font(.headline)
                Spacer()
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                TextField(L10n.s("branch.filter"), text: $filter).textFieldStyle(.roundedBorder)
            }

            List(filtered, id: \.name, selection: $selection) { b in
                HStack {
                    if b.isHEAD { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    Text(b.name).tag(b.name)
                    Spacer()
                    if b.isRemote {
                        Text(L10n.s("branch.remote")).font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .contextMenu {
                    if b.isRemote {
                        Button(L10n.s("branch.checkoutRemote")) {
                            checkoutBranch(b)
                        }
                        .disabled(running || b.localTrackingName == nil)
                        Divider()
                    }
                    Button(L10n.s("common.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(b.name, forType: .string)
                    }
                }
                .onCopyCommand { [NSItemProvider(object: NSString(string: b.name))] }
            }

            Divider()
            createRow
            Divider()
            renameRow
            Divider()
            deleteRow
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 540)
        .onAppear { reload() }
        .overlay(alignment: .bottom) {
            StatusBarView(text: status, isError: error, isLoading: running)
        }
        .onChange(of: selection) { newValue in
            if let name = newValue, let b = branches.first(where: { $0.name == name }), !b.isRemote { renameTarget = b.name }
        }
        .confirmationDialog(L10n.s("branch.deleteConfirm"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.s("branch.deleteLabel"), role: .destructive) {
                if let b = selectedBranch { run(["branch", "-d", b.name]) }
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            if let b = selectedBranch {
                Text(L10n.f("branch.deleteMessage", b.name))
            }
        }
    }

    // MARK: - 行

    private var createRow: some View {
        HStack(spacing: 8) {
            Text(L10n.s("branch.createLabel")).frame(width: 50, alignment: .leading).foregroundStyle(.secondary)
            TextField(L10n.s("branch.newName"), text: $newName).textFieldStyle(.roundedBorder)
            Text(L10n.s("branch.from")).foregroundStyle(.secondary)
            TextField(L10n.s("branch.fromPlaceholder"), text: $newNameFrom).textFieldStyle(.roundedBorder)
            Button(L10n.s("branch.create")) {
                let name = newName.trimmingCharacters(in: .whitespaces)
                let from = newNameFrom.trimmingCharacters(in: .whitespaces)
                var args = ["branch", name]
                if !from.isEmpty { args += ["--", from] }
                run(args)
            }.disabled(running || newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var renameRow: some View {
        HStack(spacing: 8) {
            Text(L10n.s("branch.renameLabel")).frame(width: 50, alignment: .leading).foregroundStyle(.secondary)
            TextField(L10n.s("branch.renameFrom"), text: $renameTarget).textFieldStyle(.roundedBorder)
            Text(L10n.s("branch.renameArrow"))
            TextField(L10n.s("branch.newNameLabel"), text: $newName)
            Button(L10n.s("branch.rename")) {
                run(["branch", "-m",
                     renameTarget.trimmingCharacters(in: .whitespaces),
                     newName.trimmingCharacters(in: .whitespaces)])
            }
            .disabled(running || renameTarget.isEmpty || newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var deleteRow: some View {
        HStack(spacing: 8) {
            Text(L10n.s("branch.deleteLabel")).frame(width: 50, alignment: .leading).foregroundStyle(.secondary)
            Text(selectedBranch?.name ?? L10n.s("branch.deleteHint")).font(.system(.body, design: .monospaced))
                .foregroundStyle(selectedBranch == nil ? .tertiary : .primary)
            Spacer()
            Button(L10n.s("branch.deleteBranch")) { showDeleteConfirm = true }
                .tint(.red)
                .disabled(running || selectedBranch == nil
                          || (selectedBranch?.isHEAD ?? false)
                          || (selectedBranch?.isRemote ?? false))
        }
    }

    // MARK: - 行为

    private func reload() {
        running = true
        Task {
            let result = await Task.detached { BranchQuery.list(root: self.repoRoot) }.value
            running = false
            branches = result.values
            if case .failure(let msg) = result {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(msg))
            } else {
                error = false
                status = ""
            }
            if let s = selection, !result.values.contains(where: { $0.name == s }) {
                selection = result.values.first?.name
            }
        }
    }

    /// 检出分支：远程分支自动创建同名本地跟踪分支；已有同名本地分支则直接切换。
    private func checkoutBranch(_ b: BranchQuery.Branch) {
        if b.isRemote {
            guard let localName = b.localTrackingName else { return }
            let localExists = branches.contains { !$0.isRemote && $0.name == localName }
            if localExists {
                run(["checkout", localName], successMessage: L10n.f("switch.switchedTo", localName))
            } else {
                run(["checkout", "-b", localName, "--track", b.name],
                    successMessage: L10n.f("switch.checkedOutRemote", localName))
            }
        } else {
            run(["checkout", b.name], successMessage: L10n.f("switch.switchedTo", b.name))
        }
    }

    private func run(_ args: [String], successMessage: String? = nil) {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(args, in: repoRoot)
            if let r, r.isSuccess {
                status = successMessage ?? L10n.s("common.done")
                newName = ""
                SettingsStore.postBadgeRefresh()
                reload()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }
}