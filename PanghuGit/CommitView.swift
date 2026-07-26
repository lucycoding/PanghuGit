import SwiftUI
import AppKit

struct CommitView: View {
    let repoRoot: URL

    @ObservedObject var store = SettingsStore.shared

    let parser = GitStatusParser()

    @State var entries: [GitStatusEntry] = []
    @State var selection: Set<String> = []
    @State var diffSelection: String?
    @State var diffText: String = ""
    @State var message: String = ""
    @State var recentMessages: [String] = []
    @State var running = false
    @State var statusLine: String = ""
    @State var error = false
    @State var showRestoreConfirm = false
    @State var pendingRestorePaths: [String] = []
    @State var showDeleteConfirm = false
    @State var pendingDeletePaths: [String] = []
    @State var skipHooks = false
    @State var amendMode = false
    @State var signoff = false
    @State var customAuthor = ""
    @State var allAuthors: [String] = []
    @State var authorsLoaded = false
    @State var repoAuthorPlaceholder: String = ""
    @State var authorSuggestions: [String] = []
    @State var lastCommitMessage: String = ""
    @State var showAmendForceConfirm = false
    @State var pendingPushWithForce: Bool? = nil
    @State var showUndoConfirm = false
    @State var diffFileGroups: [DiffFileGroup] = []
    @State var stagedHunks: Set<String> = []
    @State var focusedHunkId: String? = nil

    var stagedEntries: [GitStatusEntry] {
        entries.filter { !$0.isUntracked && $0.staged != .unmodified }
    }

    var modifiedEntries: [GitStatusEntry] {
        entries.filter { !$0.isUntracked && $0.worktree != .unmodified }
    }

    var untrackedEntries: [GitStatusEntry] {
        entries.filter { $0.isUntracked }
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                changesList
                    .frame(minWidth: 280)
                diffPane
                    .frame(minWidth: 300, idealWidth: 500)
            }
            Divider()
            editorSection
                .frame(maxHeight: 200)
            StatusBarView(text: statusLine, isError: error, isLoading: running)
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 560)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("commit.restore.confirmTitle"), isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button(L10n.s("commit.restore.execute"), role: .destructive) {
                actuallyRestore(pendingRestorePaths)
            }
            Button(L10n.s("common.cancel"), role: .cancel) { pendingRestorePaths = [] }
        } message: {
            Text(L10n.f("commit.restore.confirmMsg", pendingRestorePaths.count))
        }
        .confirmationDialog(L10n.s("commit.delete.confirmTitle"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.s("commit.delete.confirmAction"), role: .destructive) {
                actuallyDeleteUntracked(pendingDeletePaths)
            }
            Button(L10n.s("common.cancel"), role: .cancel) { pendingDeletePaths = [] }
        } message: {
            Text(L10n.f("commit.delete.confirmMsg", pendingDeletePaths.count))
        }
        .confirmationDialog(L10n.s("commit.amendForceConfirm.title"), isPresented: $showAmendForceConfirm, titleVisibility: .visible) {
            Button(L10n.s("commit.amendForceConfirm.action"), role: .destructive) {
                pushPending(forceWithLease: true)
            }
            Button(L10n.s("commit.amendForceConfirm.normalPush"), role: .cancel) {
                pushPending(forceWithLease: false)
            }
        } message: {
            Text(L10n.s("commit.amendForceConfirm.msg"))
        }
        .confirmationDialog(L10n.s("commit.undoConfirm.title"), isPresented: $showUndoConfirm, titleVisibility: .visible) {
            Button(L10n.s("commit.undoConfirm.action"), role: .destructive) {
                undoLastCommit()
            }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.s("commit.undoConfirm.msg"))
        }
        .onChange(of: amendMode) { newValue in
            if newValue && message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                message = lastCommitMessage
            }
        }
    }
}
