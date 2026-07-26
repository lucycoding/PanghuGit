import SwiftUI
import AppKit

struct SwitchView: View {
    let repoRoot: URL

    @State private var branches: [BranchQuery.Branch] = []
    @State private var currentBranchName: String?
    @State private var filter: String = ""
    @State private var selection: String?
    @State private var newBranchName: String = ""
    @State private var startPoint: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false

    private var filtered: [BranchQuery.Branch] {
        guard !filter.isEmpty else { return branches }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.s("switch.currentBranchLabel")).foregroundStyle(.secondary)
                Text(currentBranchName ?? L10n.s("switch.detached"))
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                TextField(L10n.s("switch.filterBranch"), text: $filter).textFieldStyle(.roundedBorder)
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
            }

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.s("switch.createHint")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField(L10n.s("switch.newBranchName"), text: $newBranchName).textFieldStyle(.roundedBorder)
                    TextField(L10n.s("switch.startFrom"), text: $startPoint)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .help(L10n.s("switch.startFromPlaceholder"))
                    Button(L10n.s("switch.createAndSwitch")) { checkoutNew() }
                        .disabled(running || newBranchName.isEmpty)
                }
            }

            HStack(spacing: 12) {
                Spacer()
                Button(L10n.s("switch.checkoutSelected")) { checkoutSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || selection == nil || (selection.flatMap { name in branches.first(where: { $0.name == name })?.isHEAD } ?? false))
            }
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 460)
        .onAppear { reload() }
        .overlay(alignment: .bottom) {
            StatusBarView(text: status, isError: error, isLoading: running)
        }
    }

    private func reload() {
        running = true
        Task {
            let list = await Task.detached { BranchQuery.list(root: self.repoRoot) }.value
            let cur = await Task.detached { BranchQuery.currentBranch(at: self.repoRoot) }.value
            running = false
            branches = list.values
            currentBranchName = cur
            if let cur {
                selection = list.values.first(where: { $0.isHEAD })?.name ?? cur
            }
        }
    }

    private func checkoutSelected() {
        guard let name = selection else { return }
        run(args: ["checkout", name], displayName: name)
    }

    private func checkoutNew() {
        let trimmed = newBranchName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let sp = startPoint.trimmingCharacters(in: .whitespaces)
        var args = ["checkout", "-b", trimmed]
        if !sp.isEmpty { args.append(sp) }
        run(args: args, displayName: trimmed)
    }

    private func run(args: [String], displayName: String) {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let statusR = await GitTaskHelper.runOptional(
                ["status", "--porcelain"], in: repoRoot, timeout: 10)
            let isDirty = statusR?.isSuccess == true && !statusR!.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            var stashRef: String? = nil
            if isDirty {
                let stashR = await GitTaskHelper.runOptional(
                    ["stash", "push", "--include-untracked", "-m", "panghugit-auto-switch"], in: repoRoot)
                if let stashR, stashR.isSuccess {
                    let listR = await GitTaskHelper.runOptional(["stash", "list"], in: repoRoot, timeout: 10)
                    stashRef = listR?.stdout.split(whereSeparator: \.isNewline).first.map { String($0.split(separator: ":").first ?? Substring($0)) }
                }
            }
            let r = await GitTaskHelper.runOptional(args + ["--"], in: repoRoot)
            if let stashRef {
                _ = await GitTaskHelper.runOptional(["stash", "pop", stashRef], in: repoRoot)
            }
            if let r, r.isSuccess {
                status = L10n.f("switch.switchedTo", displayName)
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