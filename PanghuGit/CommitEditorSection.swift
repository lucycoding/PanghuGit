import SwiftUI

extension CommitView {

    // MARK: - 提交信息编辑

    var editorSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text(L10n.s("commit.title")).font(.headline)
                Spacer()
                if !store.commitTemplates.isEmpty {
                    Menu(L10n.s("commit.templates")) {
                        ForEach(store.commitTemplates, id: \.self) { tpl in
                            Button(tpl) { message = tpl }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel(L10n.s("commit.templates"))
                }
                if !recentMessages.isEmpty {
                    Menu(L10n.s("commit.recent")) {
                        ForEach(recentMessages, id: \.self) { m in Button(m) { message = m } }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel(L10n.s("commit.recent"))
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)

            if store.conventionalEnabled {
                ScrollView(.horizontal, showsIndicators: false) {
                    conventionalRow
                }
                .padding(.horizontal, 12)
            }

            HStack {
                Button(L10n.s("commit.commitOnly")) { commit(pushToo: false) }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityLabel(L10n.s("commit.commitOnly"))
                Button(L10n.s("commit.commitAndPush")) { commit(pushToo: true) }
                    .disabled(running || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .accessibilityLabel(L10n.s("commit.commitAndPush"))
                Spacer()
                Button(L10n.s("commit.undoLast")) { showUndoConfirm = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(running || amendMode)
            }
            .padding(.horizontal, 12)

            HStack {
                Toggle(isOn: $amendMode) {
                    Text(L10n.s("commit.amend"))
                }
                .toggleStyle(.checkbox)
                .disabled(running || lastCommitMessage.isEmpty)
                .keyboardShortcut("a", modifiers: [.command, .shift])
                Toggle(isOn: $skipHooks) {
                    Text(L10n.s("commit.skipHooks"))
                        .foregroundStyle(skipHooks ? .orange : .primary)
                }
                .toggleStyle(.checkbox)
                .keyboardShortcut("/", modifiers: .command)
                Toggle(isOn: $signoff) {
                    Text(L10n.s("commit.signoff"))
                }
                .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal, 12)

            HStack {
                Text(L10n.s("commit.customAuthor"))
                    .font(.system(size: 12))
                TextField(L10n.s("commit.customAuthorPlaceholder"), text: $customAuthor, prompt: Text(repoAuthorPlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: customAuthor) { _ in filterAuthorSuggestions() }
                if !authorSuggestions.isEmpty {
                    Menu {
                        ForEach(authorSuggestions, id: \.self) { suggestion in
                            Button(suggestion) { customAuthor = suggestion; authorSuggestions = [] }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 12))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            TextEditor(text: $message)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.2))
                .frame(minHeight: 60, idealHeight: 60, maxHeight: 120)
                .accessibilityLabel(L10n.s("commit.message"))
                .padding(.horizontal, 12).padding(.bottom, 10)
        }
        .background(.regularMaterial)
    }

    @ViewBuilder var conventionalRow: some View {
        HStack(spacing: 6) {
            ForEach(PanghuConventional.types, id: \.self) { type in
                Button(type) {
                    insertConventional(type)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
            }
        }
    }

    func insertConventional(_ type: String) {
        let prefix = "\(type):"
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            message = prefix + " "
        } else if trimmed.hasPrefix(prefix) {
            return
        } else if let nl = trimmed.firstIndex(where: { $0.isNewline }) {
            message = prefix + " " + trimmed[..<nl] + String(trimmed[nl...])
        } else {
            message = prefix + " " + trimmed
        }
    }
}
