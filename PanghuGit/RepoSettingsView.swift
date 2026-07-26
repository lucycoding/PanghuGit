import SwiftUI

/// 仓库设置（F-18）：查看 remote 与 user，可改写 user；展示 .git/config 原文。
struct RepoSettingsView: View {
    let repoRoot: URL

    @State private var remotes: [RepoConfigQuery.Remote] = []
    @State private var user: RepoConfigQuery.UserInfo = .init(name: "", email: "")
    @State private var configRaw: String = ""
    @State private var editName: String = ""
    @State private var editEmail: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false
    @State private var showRelocate = false
    @State private var relocateRemote: String = ""
    @State private var relocateNewURL: String = ""
    @State private var showAddRemote = false
    @State private var newRemoteName = ""
    @State private var newRemoteURL = ""
    @State private var showRemoveConfirm = false
    @State private var pendingRemoveRemote = ""
    @State private var configItems: [ConfigItem] = []
    @State private var editConfigValues: [String: String] = [:]
    @State private var quickPullRebase: Bool = false
    @State private var quickAutocrlf: String = "false"
    @State private var quickIgnorecase: Bool = false
    @State private var selectedConfigKey: String? = nil
    @State private var showAddConfig = false
    @State private var newConfigKey = ""
    @State private var newConfigValue = ""
    @State private var hooks: [HookEntry] = []
    @State private var editingHook: String? = nil
    @State private var hookContent: String = ""

    struct ConfigItem: Identifiable {
        let id: String
        let key: String
        let value: String
        init(key: String, value: String, index: Int) {
            self.id = "\(key)#\(index)"
            self.key = key
            self.value = value
        }
    }

    var body: some View {
        TabView {
            remotesTab.tabItem { Label(L10n.s("reposettings.tab.remotes"), systemImage: "arrow.triangle.branch") }
            userTab.tabItem { Label(L10n.s("reposettings.tab.user"), systemImage: "person") }
            configTab.tabItem { Label(L10n.s("reposettings.tab.config"), systemImage: "gearshape") }
            hooksTab.tabItem { Label(L10n.s("reposettings.tab.hooks"), systemImage: "link") }
        }
        .padding(16)
        .overlay(alignment: .bottom) { StatusBarView(text: status, isError: error, isLoading: running) }
        .frame(minWidth: 760, minHeight: 580)
        .onAppear { reload() }
        .alert(L10n.f("reposettings.relocateTitle", relocateRemote), isPresented: $showRelocate) {
            TextField(L10n.s("reposettings.newURL"), text: $relocateNewURL)
            Button(L10n.s("reposettings.saveToRepo")) { relocateURL() }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        }
        .alert(L10n.s("reposettings.addRemote"), isPresented: $showAddRemote) {
            TextField(L10n.s("reposettings.remoteName"), text: $newRemoteName)
            TextField(L10n.s("reposettings.remoteURL"), text: $newRemoteURL)
            Button(L10n.s("reposettings.addRemote")) { addRemote() }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        }
        .alert(L10n.s("reposettings.addConfig"), isPresented: $showAddConfig) {
            TextField(L10n.s("reposettings.configKey"), text: $newConfigKey)
            TextField(L10n.s("reposettings.configValue"), text: $newConfigValue)
            Button(L10n.s("reposettings.addConfig")) { addConfig() }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(L10n.f("reposettings.removeConfirm", pendingRemoveRemote), isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button(L10n.s("reposettings.removeRemote"), role: .destructive) { removeRemote() }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.s("reposettings.removeConfirmMsg"))
        }
    }

    // MARK: - Remotes Tab

    private var remotesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox {
                if remotes.isEmpty {
                    Text(L10n.s("reposettings.noRemotes")).foregroundStyle(.tertiary).padding(.vertical)
                } else {
                    Table(remotes) {
                        TableColumn(L10n.s("reposettings.col.name")) { r in Text(r.name).monospaced() }.width(80)
                        TableColumn(L10n.s("reposettings.col.fetch")) { r in Text(r.fetchURL ?? "—").lineLimit(1).truncationMode(.head) }
                        TableColumn(L10n.s("reposettings.col.push")) { r in Text(r.pushURL ?? "—").lineLimit(1).truncationMode(.head) }
                        TableColumn("") { r in
                            HStack(spacing: 4) {
                                Button(L10n.s("reposettings.changeURL")) {
                                    relocateRemote = r.name
                                    relocateNewURL = r.fetchURL ?? ""
                                    showRelocate = true
                                }.buttonStyle(.bordered).controlSize(.small)
                                Button {
                                    pendingRemoveRemote = r.name
                                    showRemoveConfirm = true
                                } label: {
                                    Image(systemName: "minus.circle")
                                }.buttonStyle(.bordered).controlSize(.small)
                            }
                        }.width(140)
                    }
                    .padding(6)
                }
            } label: {
                HStack {
                    Text(L10n.f("reposettings.title", remotes.count))
                    Spacer()
                    Button {
                        newRemoteName = ""
                        newRemoteURL = ""
                        showAddRemote = true
                    } label: {
                        Image(systemName: "plus")
                    }.buttonStyle(.bordered).controlSize(.small)
                }
            }
            Spacer()
        }
    }

    // MARK: - User Tab

    private var userTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(L10n.s("reposettings.currentUser")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.s("reposettings.userName")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                        TextField("", text: $editName).textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text(L10n.s("reposettings.userEmail")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                        TextField("", text: $editEmail).textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Button(L10n.s("reposettings.saveToRepo")) {
                            saveUser()
                        }.buttonStyle(.borderedProminent).disabled(running)
                        Spacer()
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
    }

    // MARK: - Config Tab

    private var configTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(L10n.s("reposettings.tab.config")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button {
                            newConfigKey = ""
                            newConfigValue = ""
                            showAddConfig = true
                        } label: {
                            Image(systemName: "plus")
                        }.buttonStyle(.bordered).controlSize(.small)
                        Button {
                            if let id = selectedConfigKey,
                               let item = configItems.first(where: { $0.id == id }) {
                                removeConfig(key: item.key)
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.bordered).controlSize(.small)
                        .disabled(selectedConfigKey == nil)
                    }
                    Table(configItems, selection: $selectedConfigKey) {
                        TableColumn(L10n.s("reposettings.configKey")) { item in
                            Text(item.key).monospaced()
                        }.width(200)
                        TableColumn(L10n.s("reposettings.configValue")) { item in
                            TextField("", text: Binding(
                                get: { editConfigValues[item.key] ?? item.value },
                                set: { editConfigValues[item.key] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if let newVal = editConfigValues[item.key], newVal != item.value {
                                    setConfig(key: item.key, value: newVal)
                                }
                            }
                        }
                        TableColumn(L10n.s("reposettings.configDesc")) { item in
                            Text(configDescription(for: item.key))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }.width(160)
                    }
                    .padding(6)

                    quickToggles
                }
            }

            GroupBox(L10n.s("reposettings.configFile")) {
                ScrollView {
                    Text(configRaw.isEmpty ? L10n.s("reposettings.emptyConfig") : configRaw)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }.frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder private var quickToggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("pull.rebase").monospaced().frame(width: 140, alignment: .leading)
                Picker("", selection: Binding(
                    get: { quickPullRebase },
                    set: { quickPullRebase = $0; setConfig(key: "pull.rebase", value: $0 ? "true" : "false") }
                )) {
                    Text("true").tag(true)
                    Text("false").tag(false)
                }.frame(width: 100)
                Spacer()
            }
            HStack {
                Text("core.autocrlf").monospaced().frame(width: 140, alignment: .leading)
                Picker("", selection: Binding(
                    get: { quickAutocrlf },
                    set: { quickAutocrlf = $0; setConfig(key: "core.autocrlf", value: $0.isEmpty ? "false" : $0) }
                )) {
                    Text("true").tag("true")
                    Text("false").tag("false")
                    Text("input").tag("input")
                }.frame(width: 100)
                Spacer()
            }
            HStack {
                Text("core.ignorecase").monospaced().frame(width: 140, alignment: .leading)
                Picker("", selection: Binding(
                    get: { quickIgnorecase },
                    set: { quickIgnorecase = $0; setConfig(key: "core.ignorecase", value: $0 ? "true" : "false") }
                )) {
                    Text("true").tag(true)
                    Text("false").tag(false)
                }.frame(width: 100)
                Spacer()
            }
        }
        .padding(.horizontal, 6)
    }

    struct HookEntry: Identifiable {
        let id: String
        let name: String
        let isActive: Bool
    }

    // MARK: - Hooks Tab

    private var hooksTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let hookName = editingHook {
                HStack {
                    Text(hookName).font(.headline).monospaced()
                    Spacer()
                    Button(L10n.s("reposettings.hookSave")) { saveHook(hookName) }
                        .buttonStyle(.borderedProminent)
                        .disabled(running)
                    Button(L10n.s("common.cancel")) { editingHook = nil; hookContent = "" }
                        .buttonStyle(.bordered)
                }
                ScrollView {
                    TextEditor(text: $hookContent)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minHeight: 300)
                }
            } else {
                if hooks.isEmpty {
                    Text(L10n.s("reposettings.hooksPlaceholder"))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    Table(hooks) {
                        TableColumn(L10n.s("reposettings.tab.hooks")) { h in
                            Text(h.name).monospaced()
                        }
                        TableColumn("") { h in
                            HStack(spacing: 8) {
                                Text(h.isActive ? L10n.s("reposettings.hooksActive") : L10n.s("reposettings.hooksDisabled"))
                                    .foregroundStyle(h.isActive ? .green : .secondary)
                                    .font(.caption)
                                Toggle("", isOn: Binding(
                                    get: { h.isActive },
                                    set: { _ in toggleHook(h) }
                                )).toggleStyle(.switch).controlSize(.small)
                                Button(L10n.s("reposettings.hookEdit")) {
                                    loadHookContent(h.name)
                                }.buttonStyle(.bordered).controlSize(.small)
                            }
                        }.width(200)
                    }
                }
            }
            Spacer()
        }
    }

    private static func hooksDirURL(for root: URL) -> URL {
        GitDirResolver.resolve(root: root).appendingPathComponent("hooks")
    }

    private func loadHooks() {
        Task {
            let hooksDir = Self.hooksDirURL(for: repoRoot)
            let fm = FileManager.default
            let hooksDirPath = hooksDir.path
            guard let files = try? fm.contentsOfDirectory(atPath: hooksDirPath) else {
                hooks = []
                return
            }
            let entries = files
                .filter { !$0.hasPrefix(".") }
                .map { file -> HookEntry in
                    let name: String
                    let isActive: Bool
                    if file.hasSuffix(".sample") {
                        name = String(file.dropLast(".sample".count))
                        isActive = false
                    } else {
                        name = file
                        isActive = true
                    }
                    return HookEntry(id: file, name: name, isActive: isActive)
                }
                .sorted { $0.name < $1.name }
            hooks = entries
        }
    }

    private func toggleHook(_ hook: HookEntry) {
        Task {
            let hooksDir = Self.hooksDirURL(for: repoRoot)
            let fm = FileManager.default
            if hook.isActive {
                let sourceURL = hooksDir.appendingPathComponent(hook.name)
                let destURL = hooksDir.appendingPathComponent(hook.name + ".sample")
                guard fm.fileExists(atPath: sourceURL.path), !fm.fileExists(atPath: destURL.path) else {
                    loadHooks()
                    return
                }
                try? fm.moveItem(at: sourceURL, to: destURL)
            } else {
                let sourceURL = hooksDir.appendingPathComponent(hook.name + ".sample")
                let destURL = hooksDir.appendingPathComponent(hook.name)
                guard fm.fileExists(atPath: sourceURL.path), !fm.fileExists(atPath: destURL.path) else {
                    loadHooks()
                    return
                }
                try? fm.moveItem(at: sourceURL, to: destURL)
            }
            loadHooks()
        }
    }

    private func loadHookContent(_ name: String) {
        Task {
            let hooksDir = Self.hooksDirURL(for: repoRoot)
            let fm = FileManager.default
            let activeURL = hooksDir.appendingPathComponent(name)
            let sampleURL = hooksDir.appendingPathComponent(name + ".sample")
            let url = fm.fileExists(atPath: activeURL.path) ? activeURL : sampleURL
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            editingHook = name
            hookContent = content
        }
    }

    private func saveHook(_ name: String) {
        let content = hookContent
        Task {
            let hooksDir = Self.hooksDirURL(for: repoRoot)
            let fm = FileManager.default
            let activeURL = hooksDir.appendingPathComponent(name)
            let sampleURL = hooksDir.appendingPathComponent(name + ".sample")
            let isSample = !fm.fileExists(atPath: activeURL.path) && fm.fileExists(atPath: sampleURL.path)
            if isSample {
                try? fm.moveItem(at: sampleURL, to: activeURL)
            }
            try? content.write(to: activeURL, atomically: true, encoding: .utf8)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: activeURL.path)
            editingHook = nil
            hookContent = ""
            loadHooks()
        }
    }

    private func reload() {
        Task {
            let remoteList = await Task.detached { RepoConfigQuery.remotes(root: self.repoRoot) }.value
            let userInfo = await Task.detached { RepoConfigQuery.user(root: self.repoRoot) }.value
            let raw = await Task.detached { RepoConfigQuery.configFile(root: self.repoRoot) }.value
            let cfgList = await Task.detached { RepoConfigQuery.configList(root: self.repoRoot) }.value
            remotes = remoteList
            user = userInfo
            editName = userInfo.name
            editEmail = userInfo.email
            configRaw = raw
            configItems = cfgList.enumerated().map { i, kv in ConfigItem(key: kv.key, value: kv.value, index: i) }
            editConfigValues = cfgList.reduce(into: [String: String]()) { $0[$1.key] = $1.value }
            quickPullRebase = editConfigValues["pull.rebase"] == "true"
            quickAutocrlf = editConfigValues["core.autocrlf"] ?? "false"
            quickIgnorecase = editConfigValues["core.ignorecase"] == "true"
            status = L10n.s("reposettings.loaded"); error = false
            loadHooks()
        }
    }

    private func saveUser() {
        running = true
        let name = editName
        let email = editEmail
        Task {
            let result = await Task.detached { RepoConfigQuery.setUser(root: self.repoRoot, name: name, email: email) }.value
            status = result.message
            error = !result.success
            running = false
            if result.success { reload() }
        }
    }

    private func addRemote() {
        let name = newRemoteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !url.isEmpty,
              !name.contains(where: { $0.isNewline || $0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) || $0.isWhitespace }) else { return }
        Task {
            let r = await Task.detached { RepoConfigQuery.addRemote(root: self.repoRoot, name: name, url: url) }.value
            if let r, r.isSuccess {
                status = L10n.s("reposettings.loaded")
                error = false
            } else {
                status = GitErrorMessage.friendly(r?.stderr ?? "")
                error = true
            }
            reload()
        }
    }

    private func removeRemote() {
        let name = pendingRemoveRemote
        Task {
            let r = await Task.detached { RepoConfigQuery.removeRemote(root: self.repoRoot, name: name) }.value
            if let r, r.isSuccess {
                status = L10n.s("reposettings.loaded")
                error = false
            } else {
                status = GitErrorMessage.friendly(r?.stderr ?? "")
                error = true
            }
            reload()
        }
    }

    private func relocateURL() {
        let remote = relocateRemote
        let newURL = relocateNewURL.trimmingCharacters(in: .whitespaces)
        guard !newURL.isEmpty else { return }
        Task {
            let r = await GitTaskHelper.runOptional(
                ["remote", "set-url", "--", remote, newURL], in: repoRoot, timeout: 15)
            if let r, r.isSuccess {
                status = L10n.s("reposettings.relocateOk")
                error = false
            } else {
                status = GitErrorMessage.friendly(r?.stderr ?? "")
                error = true
            }
            reload()
        }
    }

    private func configDescription(for key: String) -> String {
        if key.hasPrefix("remote.") && key.hasSuffix(".url") { return L10n.s("reposettings.desc.remoteUrl") }
        if key.hasPrefix("branch.") && key.hasSuffix(".remote") { return L10n.s("reposettings.desc.branchRemote") }
        if key.hasPrefix("branch.") && key.hasSuffix(".merge") { return L10n.s("reposettings.desc.branchMerge") }
        switch key {
        case "user.name": return L10n.s("reposettings.desc.userName")
        case "user.email": return L10n.s("reposettings.desc.userEmail")
        case "core.autocrlf": return L10n.s("reposettings.desc.autocrlf")
        case "core.ignorecase": return L10n.s("reposettings.desc.ignorecase")
        case "pull.rebase": return L10n.s("reposettings.desc.pullRebase")
        case "core.bare": return L10n.s("reposettings.desc.bare")
        default: return ""
        }
    }

    private func setConfig(key: String, value: String) {
        Task {
            let r = await Task.detached { RepoConfigQuery.setConfig(root: self.repoRoot, key: key, value: value) }.value
            if let r, r.isSuccess {
                status = L10n.s("reposettings.loaded")
                error = false
            } else {
                status = GitErrorMessage.friendly(r?.stderr ?? "")
                error = true
            }
            reload()
        }
    }

    private func removeConfig(key: String) {
        Task {
            let r = await Task.detached { RepoConfigQuery.unsetConfig(root: self.repoRoot, key: key) }.value
            if let r, r.isSuccess {
                status = L10n.s("reposettings.loaded")
                error = false
            } else {
                status = GitErrorMessage.friendly(r?.stderr ?? "")
                error = true
            }
            reload()
        }
    }

    private func addConfig() {
        let key = newConfigKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = newConfigValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains(where: { $0.isNewline || $0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }) else { return }
        setConfig(key: key, value: value)
    }
}