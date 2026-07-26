import SwiftUI
import AppKit

private enum DiffToolPreset: String, CaseIterable, Identifiable {
    case builtin = ""
    case opendiff = "opendiff"
    case vimdiff = "vimdiff"
    case custom = "__custom__"
    var id: String { rawValue }
    var toolName: String {
        switch self {
        case .builtin, .custom: return ""
        case .opendiff: return "opendiff"
        case .vimdiff: return "vimdiff"
        }
    }
    var displayName: String {
        switch self {
        case .builtin: return L10n.s("settings.diffToolBuiltin")
        case .opendiff: return L10n.s("settings.diffToolOpendiff")
        case .vimdiff: return L10n.s("settings.diffToolVimdiff")
        case .custom: return L10n.s("settings.diffToolCustom")
        }
    }
    static func from(toolName: String) -> DiffToolPreset {
        switch toolName {
        case "": return .builtin
        case "opendiff": return .opendiff
        case "vimdiff": return .vimdiff
        default: return .custom
        }
    }
}

/// 设置面板（F-17）：通过 App Group 共享给 Finder Sync。
struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var diffToolPreset: DiffToolPreset = .builtin

    var body: some View {
        TabView {
            general
                .tabItem { Label(L10n.s("settings.tab.general"), systemImage: "gear") }

            gitTab
                .tabItem { Label(L10n.s("settings.tab.git"), systemImage: "arrow.triangle.branch") }

            ignoreTab
                .tabItem { Label(L10n.s("settings.tab.ignoreBadges"), systemImage: "eye.slash") }

            commitTab
                .tabItem { Label(L10n.s("settings.tab.commit"), systemImage: "text.badge.checkmark") }

            languageTab
                .tabItem { Label(L10n.s("settings.tab.language"), systemImage: "globe") }
        }
        .frame(minWidth: 600, minHeight: 520)
    }

    // MARK: - 通用

    @State private var probeInfo: String = ""
    @State private var globalUserName: String = ""
    @State private var globalUserEmail: String = ""
    @State private var globalUserStatus: String = ""
    @State private var globalUserError = false
    @State private var globalUserRunning = false

    private var general: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.s("settings.gitExecutable")).font(.headline)
                    HStack {
                        TextField("", text: $store.gitPath).textFieldStyle(.roundedBorder)
                        Button(L10n.s("settings.choose")) {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                store.gitPath = url.path
                            }
                        }
                        Button(L10n.s("settings.probe")) { probe() }
                    }
                    Text(L10n.s("settings.gitPathHintFull"))
                        .font(.caption).foregroundStyle(.secondary)

                    if !probeInfo.isEmpty {
                        Text(probeInfo)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Button(L10n.s("settings.listCandidates")) { listCandidates() }
                        Button(L10n.s("settings.testEffective")) { showResolved() }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.s("settings.diffMergeTool")).font(.headline)
                    HStack {
                        Picker("", selection: $diffToolPreset) {
                            ForEach(DiffToolPreset.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .frame(width: 180)
                        .onChange(of: diffToolPreset) { newValue in
                            if newValue != .custom {
                                store.diffTool = newValue.toolName
                            }
                        }
                        if diffToolPreset == .custom {
                            TextField("", text: $store.diffTool).textFieldStyle(.roundedBorder)
                        }
                    }
                    Text(L10n.s("settings.diffToolHint"))
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.s("settings.menuStyle")).font(.headline)
                    Picker("", selection: $store.menuStyle) {
                        ForEach(SettingsStore.MenuStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Text(L10n.s("settings.menuStyleHint"))
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.s("settings.terminalApp")).font(.headline)
                    Picker("", selection: $store.terminalApp) {
                        ForEach(SettingsStore.TerminalApp.allCases) { app in
                            Text(app.displayName).tag(app.rawValue)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Text(L10n.s("settings.terminalAppHint"))
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.s("settings.globalUser")).font(.headline)
                    HStack {
                        TextField(L10n.s("reposettings.userName"), text: $globalUserName).textFieldStyle(.roundedBorder)
                        TextField(L10n.s("reposettings.userEmail"), text: $globalUserEmail).textFieldStyle(.roundedBorder)
                        Button(L10n.s("settings.save")) { saveGlobalUser() }
                            .disabled(globalUserRunning)
                    }
                    if !globalUserStatus.isEmpty {
                        Text(globalUserStatus)
                            .font(.caption)
                            .foregroundStyle(globalUserError ? .red : .secondary)
                    }
                }
            }
            .padding(16)
        }
        .onAppear { diffToolPreset = DiffToolPreset.from(toolName: store.diffTool); loadGlobalUser() }
    }

    // MARK: - Git

    private var gitTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.s("settings.defaultBranch")).font(.headline)
                TextField("", text: $store.gitDefaultBranch).textFieldStyle(.roundedBorder)
                Text(L10n.s("settings.defaultBranchHint") + "（" + L10n.s("settings.defaultBranchPlaceholder") + "）")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    // MARK: - 忽略 / 角标

    private var ignoreTab: some View {
        Form {
            Section(L10n.s("settings.ignoreSection")) {
                Toggle(L10n.s("settings.ignoreAutoStage"), isOn: $store.ignoreAutoCommit)
                Text(L10n.s("settings.ignoreAutoStageHint")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L10n.s("settings.badgeRefresh")) {
                Slider(value: $store.refreshInterval, in: 0.5...10, step: 0.5)
                HStack {
                    Text(L10n.f("settings.refreshIntervalSeconds", store.refreshInterval)).monospacedDigit()
                    Spacer()
                }
            }
        }
        .padding(16)
    }

    private func probe() {
        let url = URL(fileURLWithPath: store.gitPath)
        if let v = GitLocator.versionString(at: url) {
            probeInfo = L10n.f("settings.probeOk", v, GitLocator.sourceLabel(for: url))
            NSSound.beep()
        } else {
            // 用户指定不可用，尝试回退
            if let resolved = GitLocator.resolved() {
                let v = GitLocator.versionString(at: resolved) ?? "(unknown)"
                probeInfo = L10n.f("settings.probeFallback", resolved.path, v, GitLocator.sourceLabel(for: resolved))
            } else {
                probeInfo = L10n.s("settings.probeNotFound")
            }
            NSSound.beep()
        }
    }

    private func listCandidates() {
        let cs = GitLocator.candidates()
        var lines: [String] = [L10n.s("settings.candidatesHeader")]
        for c in cs {
            let ok = GitLocator.isExecutable(at: c) ? "✓" : "✗"
            let src = GitLocator.sourceLabel(for: c)
            lines.append("  \(ok) \(c.path)  [\(src)]")
        }
        probeInfo = lines.joined(separator: "\n")
    }

    private func showResolved() {
        if let r = GitLocator.resolved() {
            let v = GitLocator.versionString(at: r) ?? L10n.s("settings.candidateVersionNA")
            probeInfo = L10n.f("settings.currentEffective", r.path, v, GitLocator.sourceLabel(for: r))
        } else {
            probeInfo = L10n.s("settings.notFoundShort")
        }
    }

    private func loadGlobalUser() {
        Task {
            let info = await Task.detached { RepoConfigQuery.globalUser() }.value
            globalUserName = info.name
            globalUserEmail = info.email
        }
    }

    private func saveGlobalUser() {
        globalUserRunning = true
        let name = globalUserName
        let email = globalUserEmail
        Task {
            let result = await Task.detached { RepoConfigQuery.setGlobalUser(name: name.isEmpty ? nil : name, email: email.isEmpty ? nil : email) }.value
            globalUserStatus = result.message
            globalUserError = !result.success
            globalUserRunning = false
        }
    }

    // MARK: - 提交

    @State private var newTemplate: String = ""

    private var commitTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.s("settings.conventional")).font(.headline)
                Toggle(L10n.s("settings.enableConventional"), isOn: $store.conventionalEnabled)
                Text(L10n.s("settings.conventionalHint"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.s("settings.templates")).font(.headline)
                HStack {
                    TextField(L10n.s("settings.templatePlaceholder"), text: $newTemplate).textFieldStyle(.roundedBorder)
                    Button(L10n.s("settings.add")) {
                        let t = newTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty, !store.commitTemplates.contains(t) else { return }
                        store.commitTemplates.append(t)
                        newTemplate = ""
                    }
                }
                if store.commitTemplates.isEmpty {
                    Text(L10n.s("settings.templatesEmpty"))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(store.commitTemplates, id: \.self) { tpl in
                            Text(tpl).lineLimit(1).truncationMode(.tail)
                        }
                        .onDelete { idx in store.commitTemplates.remove(atOffsets: idx) }
                    }
                    .frame(maxHeight: 140)
                }
            }
        }
        .padding(16)
    }

    // MARK: - 语言

    private var languageTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.s("settings.language")).font(.headline)
                Picker("", selection: $store.language) {
                    ForEach(SettingsStore.Language.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: store.language) { _ in
                    store.applyLanguage()
                }
                Text(L10n.s("settings.languageHint"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}