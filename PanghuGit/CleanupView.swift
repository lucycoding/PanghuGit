import SwiftUI
import AppKit

struct CleanupView: View {
    let repoRoot: URL

    @State private var untrackedFiles: [String] = []
    @State private var untrackedDirs: [String] = []
    @State private var cleanDirs = false
    @State private var dryRun = true
    @State private var output: String = ""
    @State private var running = false
    @State private var error = false
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(L10n.s("cleanup.untracked")) {
                VStack(alignment: .leading, spacing: 6) {
                    if untrackedFiles.isEmpty && untrackedDirs.isEmpty {
                        Text(L10n.s("cleanup.clean")).foregroundStyle(.green)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(untrackedFiles, id: \.self) { path in
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc").foregroundStyle(.secondary).font(.caption)
                                        Text(path).font(.system(size: 12, design: .monospaced))
                                    }
                                }
                                ForEach(untrackedDirs, id: \.self) { path in
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder").foregroundStyle(.secondary).font(.caption)
                                        Text(path).font(.system(size: 12, design: .monospaced))
                                    }
                                }
                            }.padding(4)
                        }
                        .frame(maxHeight: 200)
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 16) {
                Toggle(L10n.s("cleanup.includeDirs"), isOn: $cleanDirs)
                Toggle(L10n.s("cleanup.dryRun"), isOn: $dryRun)
            }

            if !output.isEmpty {
                GroupBox(L10n.s("patch.output")) {
                    ScrollView {
                        Text(output)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(error ? .red : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(6)
                    }
                    .frame(maxHeight: .infinity)
                }
            }

            Divider()
            StatusBarView(text: output, isError: error, isLoading: running) {
                Button(L10n.s("common.refresh")) { reload() }.buttonStyle(.bordered)
                Button(L10n.s("cleanup.execute")) {
                    if dryRun { run() } else { showConfirm = true }
                }
                .buttonStyle(.borderedProminent)
                .disabled(running || (untrackedFiles.isEmpty && untrackedDirs.isEmpty))
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 400)
        .onAppear { reload() }
        .confirmationDialog(L10n.s("cleanup.confirmTitle"), isPresented: $showConfirm, titleVisibility: .visible) {
            Button(L10n.s("cleanup.execute"), role: .destructive) { run() }
            Button(L10n.s("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.f("cleanup.confirmMsg", untrackedFiles.count + untrackedDirs.count))
        }
    }

    private func reload() {
        Task {
            let r = await GitTaskHelper.runOptional(
                ["clean", "-dn"], in: repoRoot, timeout: 15)
            let rFiles = await GitTaskHelper.runOptional(
                ["ls-files", "--others", "--exclude-standard"], in: repoRoot, timeout: 15)
            var files: [String] = []
            var dirs: [String] = []
            if let rFiles, rFiles.isSuccess {
                files = rFiles.stdout.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
            }
            if let r, r.isSuccess {
                for line in r.stdout.split(whereSeparator: \.isNewline) {
                    let s = String(line)
                    if s.hasPrefix("Would remove ") {
                        let path = String(s.dropFirst(14))
                        if s.hasSuffix("/") { dirs.append(path) }
                    }
                }
            }
            untrackedFiles = files
            untrackedDirs = dirs
        }
    }

    private func run() {
        running = true; error = false; output = ""
        var args = ["clean"]
        if dryRun { args += ["-n"] }
        if cleanDirs { args += ["-d"] }
        args += ["-f"]
        Task {
            let r = await GitTaskHelper.runOptional(args, in: repoRoot)
            if let r, r.isSuccess {
                output = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if output.isEmpty { output = L10n.s("cleanup.done") }
                if !dryRun {
                    SettingsStore.postBadgeRefresh()
                    reload()
                }
            } else {
                error = true
                output = GitErrorMessage.friendly(r?.stderr ?? "")
            }
            running = false
        }
    }
}
