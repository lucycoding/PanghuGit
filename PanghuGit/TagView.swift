import SwiftUI
import AppKit

struct TagView: View {
    let repoRoot: URL

    @State private var entries: [TagQuery.Entry] = []
    @State private var selection: TagQuery.Entry?
    @State private var newName: String = ""
    @State private var newMessage: String = ""
    @State private var targetRef: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteName: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.f("tag.title", entries.count)).font(.headline)
                Spacer()
                Button(L10n.s("tag.fetchTags")) { fetchTags() }.buttonStyle(.bordered).controlSize(.small)
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
            }.padding(10)
            Divider()
            HSplitView {
                list.frame(minWidth: 280)
                detail.frame(minWidth: 320, idealWidth: 460)
            }
            createRow
        }
        .padding(16)
        .overlay(alignment: .bottom) { StatusBarView(text: status, isError: error, isLoading: running) }
        .frame(minWidth: 720, minHeight: 560)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("tag.deleteConfirm"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.s("common.delete"), role: .destructive) {
                if let name = pendingDeleteName { deleteTag(name) }
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            if let name = pendingDeleteName {
                Text(L10n.f("tag.deleteMessage", name))
            }
        }
    }

    // MARK: - 列表

    private var list: some View {
        VStack(spacing: 0) {
            if entries.isEmpty && !running {
                EmptyStateView(message: L10n.s("tag.empty"), systemImage: "tag")
            }
            List(entries, id: \.id, selection: $selection) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).monospaced()
                    HStack(spacing: 8) {
                        Text(t.target).font(.caption).foregroundStyle(.tint)
                        if let d = t.date { Text(d).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let a = t.annotation {
                        Text(a).font(.caption).lineLimit(1).truncationMode(.tail)
                    }
                }.padding(.vertical, 2).tag(t)
                .contextMenu {
                    Button(L10n.s("common.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(t.name, forType: .string)
                    }
                }
                .onCopyCommand { [NSItemProvider(object: NSString(string: t.name))] }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let t = selection {
            VStack(alignment: .leading, spacing: 8) {
                GroupBox(L10n.s("tag.detail")) {
                    VStack(alignment: .leading, spacing: 6) {
                        row(L10n.s("tag.name"), t.name)
                        row(L10n.s("tag.target"), t.target)
                        if let a = t.annotation { row(L10n.s("tag.annotation"), a) }
                        if let d = t.date { row(L10n.s("tag.date"), d) }
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button(L10n.s("tag.delete")) { pendingDeleteName = t.name; showDeleteConfirm = true }
                        .tint(.red)
                        .disabled(running)
                }
                Spacer()
            }.padding(12)
        } else {
            EmptyStateView(message: L10n.s("tag.selectHint"))
        }
    }

    // MARK: - 创建

    private var createRow: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 8) {
                Text(L10n.s("tag.createLabel")).frame(width: 50, alignment: .leading).foregroundStyle(.secondary)
                TextField(L10n.s("tag.newName"), text: $newName).textFieldStyle(.roundedBorder)
                Text(L10n.s("tag.targetRef")).foregroundStyle(.secondary)
                TextField(L10n.s("tag.targetPlaceholder"), text: $targetRef).textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                Text(L10n.s("tag.message")).foregroundStyle(.secondary)
                TextField(L10n.s("tag.messagePlaceholder"), text: $newMessage).textFieldStyle(.roundedBorder)
                Button(L10n.s("tag.createLabel")) { create() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).frame(width: 50, alignment: .leading).foregroundStyle(.secondary)
            Text(value).monospaced(); Spacer()
        }
    }

    // MARK: - 行为

    private func reload() {
        Task {
            let fmt = "%(refname:short)\t%(objectname:short)\t%(contents:subject)\t%(creatordate:short)"
            let r = await GitTaskHelper.runOptional(
                ["for-each-ref", "--format=\(fmt)", "refs/tags"], in: repoRoot, timeout: 20)
            if let r, r.isSuccess {
                let items: [TagQuery.Entry] = r.stdout.split(whereSeparator: \.isNewline).compactMap { line in
                    let cols = String(line).split(separator: "\t", omittingEmptySubsequences: false)
                    guard cols.count >= 2 else { return nil }
                    return TagQuery.Entry(
                        id: String(cols[0]),
                        name: String(cols[0]),
                        target: String(cols[1]),
                        annotation: cols.count >= 3 && !String(cols[2]).isEmpty ? String(cols[2]) : nil,
                        date: cols.count >= 4 && !String(cols[3]).isEmpty ? String(cols[3]) : nil
                    )
                }
                entries = items
                error = false
                status = ""
                selection = items.first
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
                entries = []
                selection = nil
            }
        }
    }

    private func fetchTags() {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["fetch", "--tags", "--all"], in: repoRoot, timeout: 60)
            if let r, r.isSuccess {
                status = L10n.s("common.done")
                reload()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let msg = newMessage.trimmingCharacters(in: .whitespaces)
        let target = targetRef.trimmingCharacters(in: .whitespaces)
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await Task.detached {
                TagQuery.create(root: self.repoRoot, name: name, message: msg,
                                annotated: !msg.isEmpty, targetRef: target.isEmpty ? nil : target)
            }.value
            if let r, r.isSuccess {
                status = L10n.f("tag.created", name)
                newName = ""; newMessage = ""; targetRef = ""
                SettingsStore.postBadgeRefresh()
                reload()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
                running = false
            }
        }
    }

    private func deleteTag(_ name: String) {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await Task.detached { TagQuery.delete(root: self.repoRoot, name: name) }.value
            if let r, r.isSuccess {
                status = L10n.f("tag.deleted", name)
                SettingsStore.postBadgeRefresh()
                reload()
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
                running = false
            }
        }
    }
}