import SwiftUI
import AppKit

struct LogView: View {
    let repoRoot: URL
    var initialFile: String? = nil

    @State private var entries: [LogQuery.Entry] = []
    @State private var selection: LogQuery.Entry?
    @State private var filterBranch: String = ""
    @State private var filterAuthor: String = ""
    @State private var filterFile: String = ""
    @State private var sinceDays: Int = 7
    @State private var branches: [BranchQuery.Branch] = []
    @State private var selectedBranchName: String? = nil
    @State private var canLoadMore = false
    @State private var loadingMore = false
    @State private var showExpandToAll = false
    struct ChangedFile: Identifiable, Hashable {
        var id: String { path }
        let path: String
        let status: CommitFileStatus
    }
    @State private var changedFiles: [ChangedFile] = []
    @State private var loading = false
    @State private var cherryPickStatus: String = ""
    @State private var cherryPickError = false
    @State private var multiSelection: Set<String> = []
    @State private var showResetConfirm = false
    @State private var pendingReset: (sha: String, mode: String, args: [String])?
    @State private var resetMode: ResetMode = .mixed
    @State private var followRenames = false

    private var sinceArg: String? {
        sinceDays > 0 ? "\(sinceDays) days ago" : nil
    }

    private var localBranches: [BranchQuery.Branch] {
        branches.filter { !$0.isRemote }
    }

    private var remoteBranches: [BranchQuery.Branch] {
        branches.filter { $0.isRemote }
    }

    var body: some View {
        VStack(spacing: 0) {
            filters
            if let f = initialFile, !f.isEmpty, !filterFile.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                    Text(L10n.f("log.fileHistoryBanner", f))
                    Spacer()
                    Button {
                        filterFile = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .font(.callout)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.tint.opacity(0.08))
            }
            if !cherryPickStatus.isEmpty {
                HStack {
                    Text(cherryPickStatus)
                        .foregroundStyle(cherryPickError ? .red : .secondary)
                        .font(.callout)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        cherryPickStatus = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.regularMaterial)
            }
            Divider()
            HStack(spacing: 0) {
                branchSidebar.frame(width: 180)
                Divider()
                commitList.frame(minWidth: 400)
                if selection != nil || !multiSelection.isEmpty {
                    Divider()
                    detail.frame(minWidth: 320, idealWidth: 460)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 920, minHeight: 580)
        .onAppear {
            if let f = initialFile, !f.isEmpty { filterFile = f; followRenames = true }
            reload()
        }
        .onReceive(DistributedNotificationCenter.default.publisher(for: Notification.Name("com.lucy.panghugit.refreshBadges"))) { _ in
            reload()
        }
        .confirmationDialog(L10n.s("log.reset.confirmTitle"), isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button(L10n.s("log.reset.execute"), role: .destructive) {
                if let p = pendingReset { actuallyRunReset(p.args) }
            }
            Button(L10n.s("common.cancel"), role: .cancel) { pendingReset = nil }
        } message: {
            if let p = pendingReset {
                Text(L10n.f("log.reset.confirmMsg", p.mode, String(p.sha.prefix(7))))
            }
        }
        .alert(L10n.s("log.expandToAll.title"), isPresented: $showExpandToAll) {
            Button(L10n.s("log.expandToAll.action")) {
                sinceDays = 0
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.f("log.expandToAll.msg", sinceDays))
        }
    }

    // MARK: - 过滤栏

    private var filters: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch").foregroundStyle(.secondary)
            TextField(L10n.s("log.filters.branch"), text: $filterBranch).textFieldStyle(.roundedBorder)
            Image(systemName: "person").foregroundStyle(.secondary)
            TextField(L10n.s("log.filters.author"), text: $filterAuthor).textFieldStyle(.roundedBorder)
            Image(systemName: "doc.text").foregroundStyle(.secondary)
            TextField(L10n.s("log.filters.file"), text: $filterFile).textFieldStyle(.roundedBorder)
            if !filterFile.isEmpty {
                Toggle(L10n.s("log.followRenames"), isOn: $followRenames)
                    .toggleStyle(.checkbox)
                if followRenames {
                    Text(L10n.s("log.followNoPagination")).font(.caption2).foregroundStyle(.orange)
                }
            }
            Text(L10n.s("log.filters.recentPrefix")).foregroundStyle(.secondary)
            Picker("", selection: $sinceDays) {
                Text(L10n.s("log.filters.days7")).tag(7)
                Text(L10n.s("log.filters.days30")).tag(30)
                Text(L10n.s("log.filters.days90")).tag(90)
                Text(L10n.s("log.filters.recent.all")).tag(0)
            }.frame(width: 90)
            .onChange(of: sinceDays) { _ in reload() }
            Spacer()
            Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
        }
        .padding(10)
    }

    // MARK: - 分支侧边栏

    private var branchSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.s("log.branches")).font(.headline).padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !localBranches.isEmpty {
                        Text(L10n.s("log.branchesLocal"))
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 2)
                        ForEach(localBranches, id: \.name) { branch in
                            branchRow(name: branch.name, isHead: branch.isHEAD, isRemote: false)
                        }
                    }
                    if !remoteBranches.isEmpty {
                        Text(L10n.s("log.branchesRemote"))
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.top, 10).padding(.bottom, 2)
                        ForEach(remoteBranches, id: \.name) { branch in
                            branchRow(name: branch.name, isHead: false, isRemote: true)
                        }
                    }
                }
            }
        }
    }

    private func branchRow(name: String, isHead: Bool, isRemote: Bool) -> some View {
        let isSelected = selectedBranchName == name
        return HStack(spacing: 4) {
            Image(systemName: isRemote ? "cloud" : "arrow.triangle.branch")
                .font(.caption).foregroundStyle(.secondary)
            Text(isHead ? "\(name) (HEAD)" : name)
                .lineLimit(1).truncationMode(.tail)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3).padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedBranchName = nil
                filterBranch = ""
            } else {
                selectedBranchName = name
                filterBranch = name
            }
            reload()
        }
    }

    // MARK: - 提交列表

    private var commitList: some View {
        VStack(spacing: 0) {
            if loading { ProgressView().padding() }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries, id: \.id) { e in
                        logRow(e)
                            .background(
                                multiSelection.contains(e.id)
                                    ? Color.accentColor.opacity(0.25)
                                    : selection?.id == e.id
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.clear
                            )
                    }
                    if canLoadMore {
                        Button {
                            loadMore()
                        } label: {
                            HStack {
                                if loadingMore { ProgressView().controlSize(.small) }
                                Text(L10n.s("log.loadMore"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(loadingMore)
                    }
                }
                .padding(.trailing, 14)
            }
            .overlay {
                if entries.isEmpty && !loading {
                    EmptyStateView(message: L10n.s("log.empty"), systemImage: "clock")
                }
            }
        }
    }

    private func selectCommit(_ e: LogQuery.Entry) {
        if selection?.id == e.id { return }
        selection = e
        loadFiles()
    }

    @ViewBuilder
    private func logRow(_ e: LogQuery.Entry) -> some View {
        row(e)
            .contentShape(Rectangle())
            .onTapGesture {
                let cmdDown = NSEvent.modifierFlags.contains(.command)
                if cmdDown {
                    toggleMultiSelect(e)
                } else {
                    selectSingle(e)
                }
            }
            .contextMenu {
                Button(L10n.s("log.ctx.copySHA")) { copySHA(e) }.keyboardShortcut("c", modifiers: .command)
                Button(L10n.s("log.ctx.copyBranchName")) { copyBranchName(e) }
                Button(L10n.s("log.ctx.copyCommitMsg")) { copyCommitMessage(e) }.keyboardShortcut("c", modifiers: [.command, .option])
                Button(L10n.s("log.ctx.checkout")) { checkoutCommit(e) }
                Button(L10n.s("log.ctx.createTag")) { createTag(e) }
                Button(L10n.s("log.ctx.cherryPick")) { cherryPick(e) }
                if multiSelection.count >= 2 {
                    Divider()
                    Button(L10n.f("log.ctx.cherryPickRange", multiSelection.count)) { cherryPickRange() }
                }
                if multiSelection.count == 2 {
                    Button(L10n.s("log.diffRange")) { diffRange() }
                }
                Divider()
                Button(L10n.s("log.ctx.revertCommit")) { revertCommit(e) }
                Menu(L10n.s("log.ctx.resetToHere")) {
                    Button(L10n.s("revert.reset.soft"))  { resetToCommit(e, mode: .soft) }
                    Button(L10n.s("revert.reset.mixed")) { resetToCommit(e, mode: .mixed) }
                    Button(L10n.s("revert.reset.hard"))  { resetToCommit(e, mode: .hard) }
                }
            }
            .onCopyCommand {
                [NSItemProvider(object: NSString(string: e.id))]
            }
    }

    private func row(_ e: LogQuery.Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(e.shortHash).monospaced().foregroundStyle(.tint)
                if !e.refs.isEmpty {
                    Text(e.refs)
                        .font(.caption2).padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                Spacer()
                Text(e.authorDate).font(.caption).foregroundStyle(.secondary)
            }
            Text(e.subject).lineLimit(1).truncationMode(.tail)
            Text(e.authorName).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2).padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(e.shortHash) \(e.subject) \(e.authorName)")
    }

    // MARK: - 详情

    @ViewBuilder private var detail: some View {
        if !multiSelection.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.f("log.multiSelected", multiSelection.count))
                    .font(.headline)
                HStack(spacing: 10) {
                    if multiSelection.count >= 2 {
                        Button(L10n.f("log.ctx.cherryPickRange", multiSelection.count)) {
                            cherryPickRange()
                        }
                    }
                    if cherryPickError {
                        Button(L10n.s("log.cherryPickAbort")) {
                            abortCherryPick()
                        }
                    }
                    Spacer()
                }
                if !cherryPickStatus.isEmpty {
                    Text(cherryPickStatus)
                        .foregroundStyle(cherryPickError ? .red : .secondary)
                        .font(.callout)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(12)
            .frame(minWidth: 320, idealWidth: 460)
        } else if let e = selection {
            VStack(alignment: .leading, spacing: 10) {
                GroupBox(L10n.f("log.detail.changedFiles", changedFiles.count)) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(changedFiles) { f in
                                HStack(spacing: 6) {
                                    Text(f.status.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(f.status.color)
                                        .frame(width: 20, height: 20)
                                        .background(f.status.bgColor, in: RoundedRectangle(cornerRadius: 4))
                                    Text(f.path).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Button(L10n.s("log.detail.diff")) {
                                        openDiffWindow(hash: e.id, file: f.path)
                                    }
                                    Button(L10n.s("diff.openInDifftool")) {
                                        openDifftoolForFile(hash: e.id, file: f.path)
                                    }
                                }.padding(.horizontal, 4).padding(.vertical, 2)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    openDifftoolForFile(hash: e.id, file: f.path)
                                }
                                .contextMenu {
                                    Button(L10n.s("log.viewAtRevision")) {
                                        viewFileAtRevision(hash: e.id, path: f.path)
                                    }
                                    Button(L10n.s("log.ctx.copyFilePath")) {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(f.path, forType: .string)
                                    }
                                }
                            }
                        }.padding(6)
                    }
                    .frame(maxHeight: .infinity)
                }
                GroupBox(L10n.s("log.detail.commitInfo")) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledRow(L10n.s("log.detail.hash"), e.id).monospaced()
                            LabeledRow(L10n.s("log.detail.author"), e.authorName)
                            LabeledRow(L10n.s("log.detail.date"), e.authorDate)
                            Text(e.subject)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(.top, 2)
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
            }.padding(12)
            .frame(minWidth: 320, idealWidth: 460)
        } else {
            EmptyStateView(message: L10n.s("log.selectHint"))
                .frame(minWidth: 320, idealWidth: 460)
        }
    }

    // MARK: - 行为

    private func reload() {
        loading = true
        canLoadMore = false
        let capturedFilterBranch = filterBranch
        let capturedFilterAuthor = filterAuthor
        let capturedFilterFile = filterFile
        let capturedSinceArg = sinceArg
        let capturedFollowRenames = followRenames
        Task {
            let listResult = await Task.detached {
                LogQuery.entries(root: self.repoRoot,
                             branch: capturedFilterBranch.isEmpty ? nil : capturedFilterBranch,
                             author: capturedFilterAuthor.isEmpty ? nil : capturedFilterAuthor,
                             since: capturedSinceArg,
                             file: capturedFilterFile.isEmpty ? nil : capturedFilterFile,
                             maxCount: 51,
                             follow: capturedFollowRenames)
            }.value
            let branchList = await Task.detached { BranchQuery.list(root: self.repoRoot) }.value
            let list = listResult.values
            let trimmed = Array(list.prefix(50))
            var hasMore = list.count > 50
            if !hasMore, capturedSinceArg != nil {
                let probe = await Task.detached {
                    LogQuery.entries(root: self.repoRoot,
                                  branch: capturedFilterBranch.isEmpty ? nil : capturedFilterBranch,
                                  author: capturedFilterAuthor.isEmpty ? nil : capturedFilterAuthor,
                                  since: nil,
                                  file: capturedFilterFile.isEmpty ? nil : capturedFilterFile,
                                  maxCount: 1,
                                  skip: trimmed.count)
                }.value
                hasMore = !probe.values.isEmpty
            }
            canLoadMore = capturedFollowRenames ? false : hasMore
            if !trimmed.isEmpty {
                entries = trimmed
                if selection == nil || !trimmed.contains(where: { $0.id == selection?.id }) {
                    selection = trimmed.first
                    loadFiles()
                }
            } else {
                entries = []
                selection = nil
            }
            branches = branchList.values
            loading = false
        }
    }

    private func loadMore() {
        guard !followRenames else { return }
        if entries.isEmpty {
            if sinceDays > 0 {
                showExpandToAll = true
            }
            return
        }
        guard let earliest = entries.last?.authorDate else { return }
        loadingMore = true
        let capturedFilterBranch = filterBranch
        let capturedFilterAuthor = filterAuthor
        let capturedFilterFile = filterFile
        let capturedFollowRenames = followRenames
        Task {
            let listResult = await Task.detached {
                LogQuery.entries(root: self.repoRoot,
                             branch: capturedFilterBranch.isEmpty ? nil : capturedFilterBranch,
                             author: capturedFilterAuthor.isEmpty ? nil : capturedFilterAuthor,
                             before: earliest,
                             file: capturedFilterFile.isEmpty ? nil : capturedFilterFile,
                             maxCount: 51,
                             follow: capturedFollowRenames)
            }.value
            let list = listResult.values
            let trimmed = Array(list.prefix(50))
            canLoadMore = list.count > 50
            let existingIds = Set(entries.map(\.id))
            let newEntries = trimmed.filter { !existingIds.contains($0.id) }
            entries.append(contentsOf: newEntries)
            loadingMore = false
        }
    }

    private func loadFiles() {
        guard let e = selection else { changedFiles = []; return }
        let targetId = e.id
        Task {
            let files = await Task.detached { LogQuery.changedFiles(root: self.repoRoot, hash: targetId) }.value
            guard selection?.id == targetId else { return }
            changedFiles = files.map { ChangedFile(path: $0.path, status: CommitFileStatus(raw: $0.status)) }
        }
    }

    private func openDiffWindow(hash: String, file: String) {
        HostWindow.show(id: "diff-\(hash)-\(file)", title: L10n.s("hostwindow.title.commitDiff")) {
            DiffView(repoRoot: repoRoot, aRef: "\(hash)^", bRef: hash, file: file)
        }
    }

    private func openDifftoolForFile(hash: String, file: String) {
        let tool = SettingsStore.shared.diffTool
        Task {
            _ = await GitTaskHelper.runOptional(
                ["difftool", "--tool=\(tool)", "--no-prompt", "\(hash)^..\(hash)", "--", file], in: repoRoot, timeout: 60)
        }
    }

    private func viewFileAtRevision(hash: String, path: String) {
        let shortHash = String(hash.prefix(7))
        Task {
            let r = await GitTaskHelper.runOptional(
                ["show", "\(hash):\(path)"], in: repoRoot)
            let content = (r?.isSuccess == true) ? (r?.stdout ?? "") : (r?.stderr ?? L10n.f("common.failed", ""))
            HostWindow.show(id: "revision-file-\(hash)-\(path)",
                            title: L10n.f("log.revisionFileTitle", path, shortHash)) {
                RevisionFileView(content: content, fileName: path)
            }
        }
    }

    // MARK: - 右键操作

    private func toggleMultiSelect(_ e: LogQuery.Entry) {
        if multiSelection.contains(e.id) {
            multiSelection.remove(e.id)
        } else {
            multiSelection.insert(e.id)
        }
        selection = nil
        changedFiles = []
    }

    private func selectSingle(_ e: LogQuery.Entry) {
        selection = e
        multiSelection = []
        loadFiles()
    }

    private func copySHA(_ e: LogQuery.Entry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(e.id, forType: .string)
    }

    private func copyBranchName(_ e: LogQuery.Entry) {
        let branchNames = e.refs
            .components(separatedBy: CharacterSet(charactersIn: "(), "))
            .filter { $0.hasPrefix("HEAD -> ") || !$0.isEmpty }
            .map { $0.hasPrefix("HEAD -> ") ? String($0.dropFirst("HEAD -> ".count)) : $0 }
            .filter { !$0.isEmpty && $0 != "HEAD" }
        let text = branchNames.first ?? e.refs
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyCommitMessage(_ e: LogQuery.Entry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(e.subject, forType: .string)
    }

    private func checkoutCommit(_ e: LogQuery.Entry) {
        Task {
            _ = await GitTaskHelper.runOptional(["checkout", e.id], in: repoRoot)
        }
    }

    private func createTag(_ e: LogQuery.Entry) {
        HostWindow.show(id: "log-tag-\(e.id)", title: L10n.f("log.ctx.tagTitle", e.shortHash)) {
            TagView(repoRoot: repoRoot)
        }
    }

    private func cherryPick(_ e: LogQuery.Entry) {
        cherryPickError = false
        cherryPickStatus = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["cherry-pick", "--", e.id], in: repoRoot)
            if let r, r.isSuccess {
                cherryPickStatus = L10n.f("common.doneWithCmd", "cherry-pick \(e.shortHash)")
                SettingsStore.postBadgeRefresh()
                reload()
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    cherryPickStatus = ""
                }
            } else {
                let stderr = r?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let conflicts = await Task.detached { MergeQuery.conflicts(root: self.repoRoot) }.value
                if !conflicts.isEmpty {
                    cherryPickError = true
                    cherryPickStatus = L10n.f("merge.failedWithConflicts", conflicts.count)
                } else {
                    cherryPickError = true
                    cherryPickStatus = L10n.f("common.failed", GitErrorMessage.friendly(stderr))
                }
            }
        }
    }

    private func cherryPickRange() {
        let selected = entries.filter { multiSelection.contains($0.id) }
        let sorted = selected.sorted { a, b in
            guard let ai = entries.firstIndex(where: { $0.id == a.id }),
                  let bi = entries.firstIndex(where: { $0.id == b.id }) else { return false }
            return ai > bi
        }
        guard selected.count >= 2 else { return }
        let shas = sorted.map(\.id)
        cherryPickError = false
        cherryPickStatus = L10n.s("common.running")
        let count = selected.count
        Task {
            let r = await GitTaskHelper.runOptional(["cherry-pick"] + shas, in: repoRoot, timeout: 60)
            if let r, r.isSuccess {
                cherryPickStatus = L10n.f("common.doneWithCmd", "cherry-pick \(count) commits")
                multiSelection = []
                SettingsStore.postBadgeRefresh()
                reload()
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    cherryPickStatus = ""
                }
            } else {
                let stderr = r?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let conflicts = await Task.detached { MergeQuery.conflicts(root: self.repoRoot) }.value
                if !conflicts.isEmpty {
                    cherryPickError = true
                    cherryPickStatus = L10n.f("merge.failedWithConflicts", conflicts.count)
                } else {
                    cherryPickError = true
                    cherryPickStatus = L10n.f("common.failed", GitErrorMessage.friendly(stderr))
                }
            }
        }
    }

    private func abortCherryPick() {
        cherryPickStatus = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["cherry-pick", "--abort"], in: repoRoot)
            if let r, r.isSuccess {
                cherryPickError = false
                cherryPickStatus = L10n.f("common.doneWithCmd", "cherry-pick --abort")
            } else {
                cherryPickError = true
                cherryPickStatus = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            multiSelection = []
            if let r, r.isSuccess {
                SettingsStore.postBadgeRefresh()
                reload()
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    cherryPickStatus = ""
                }
            }
        }
    }

    private func diffRange() {
        let selected = entries.filter { multiSelection.contains($0.id) }
        guard selected.count == 2 else { return }
        let sorted = selected.sorted { a, b in
            guard let ai = entries.firstIndex(where: { $0.id == a.id }),
                  let bi = entries.firstIndex(where: { $0.id == b.id }) else { return false }
            return ai < bi
        }
        guard let newer = sorted.first?.id,
              let older = sorted.last?.id else { return }
        HostWindow.show(id: "diff-range-\(older)-\(newer)", title: L10n.s("hostwindow.title.diff")) {
            DiffView(repoRoot: repoRoot, aRef: older, bRef: newer)
        }
    }

    private func revertCommit(_ e: LogQuery.Entry) {
        cherryPickError = false
        cherryPickStatus = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["revert", "--no-edit", "--", e.id], in: repoRoot)
            if let r, r.isSuccess {
                cherryPickStatus = L10n.f("common.doneWithCmd", "revert \(e.shortHash)")
                SettingsStore.postBadgeRefresh()
                reload()
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    cherryPickStatus = ""
                }
            } else {
                let stderr = r?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let conflicts = await Task.detached { MergeQuery.conflicts(root: self.repoRoot) }.value
                if !conflicts.isEmpty {
                    cherryPickError = true
                    cherryPickStatus = L10n.f("merge.failedWithConflicts", conflicts.count)
                } else {
                    cherryPickError = true
                    cherryPickStatus = L10n.f("common.failed", GitErrorMessage.friendly(stderr))
                }
            }
        }
    }

    enum ResetMode: String, CaseIterable {
        case soft, mixed, hard
        var flag: String { "--\(rawValue)" }
        var localizedName: String {
            switch self {
            case .soft:  return L10n.s("revert.reset.soft")
            case .mixed: return L10n.s("revert.reset.mixed")
            case .hard:  return L10n.s("revert.reset.hard")
            }
        }
    }

    private func resetToCommit(_ e: LogQuery.Entry, mode: ResetMode) {
        let args = ["reset", mode.flag, "--", e.id]
        if mode == .hard {
            pendingReset = (sha: e.id, mode: mode.localizedName, args: args)
            showResetConfirm = true
        } else {
            actuallyRunReset(args)
        }
    }

    private func actuallyRunReset(_ args: [String]) {
        cherryPickError = false
        cherryPickStatus = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(args, in: repoRoot)
            if let r, r.isSuccess {
                cherryPickStatus = L10n.f("common.doneWithCmd", args.joined(separator: " "))
                SettingsStore.postBadgeRefresh()
                reload()
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    cherryPickStatus = ""
                }
            } else {
                cherryPickError = true
                cherryPickStatus = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
        }
    }

    struct LabeledRow: View {
        let label: String
        let value: String
        init(_ l: String, _ v: String) { label = l; value = v }
        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                Text(label).frame(width: 50, alignment: .leading).foregroundStyle(.secondary)
                Text(value); Spacer()
            }.font(.system(.body, design: nil))
        }
    }
}

struct RevisionFileView: View {
    let content: String
    let fileName: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(content, forType: .string)
                } label: {
                    Text(L10n.s("common.copy")).font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button(L10n.s("log.saveAs")) {
                    saveAs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(8)
            Divider()
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName.components(separatedBy: "/").last ?? fileName
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
