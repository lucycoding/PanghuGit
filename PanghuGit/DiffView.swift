import SwiftUI

struct DiffView: View {
    let repoRoot: URL
    var aRef: String? = nil
    var bRef: String? = nil
    var file: String? = nil
    var initialMode: Mode? = nil

    enum Mode: String, CaseIterable, Identifiable {
        case worktreeVsStaged
        case worktreeVsHEAD
        case stagedVsHEAD
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .worktreeVsStaged: return L10n.s("diff.mode.worktreeVsStaged")
            case .worktreeVsHEAD: return L10n.s("diff.mode.worktreeVsHEAD")
            case .stagedVsHEAD: return L10n.s("diff.mode.stagedVsHEAD")
            }
        }
    }

    @State private var mode: Mode = .worktreeVsHEAD
    @State private var pathOverride: String = ""
    @State private var patch: String = ""
    @State private var parsedLines: [DiffLine] = []
    @State private var running = false
    @State private var error = false
    @ObservedObject private var store = SettingsStore.shared

    private var isFixedRange: Bool { aRef != nil && bRef != nil }
    private var effectiveFile: String? {
        let p = pathOverride.trimmingCharacters(in: .whitespaces)
        return p.isEmpty ? file : p
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            patchContent
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 560)
        .onAppear { if let m = initialMode { mode = m }; reload() }
        .onChange(of: patch) { _ in recomputeParsedLines() }
    }

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if isFixedRange {
                    Text("\(aRef ?? "")…\(bRef ?? "")").monospaced()
                } else {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.localizedName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                    .onChange(of: mode) { _ in reload() }
                }
                Spacer()
                if !store.diffTool.isEmpty {
                    Button(L10n.s("diff.openInDifftool")) { openInDifftool() }
                        .buttonStyle(.bordered)
                        .disabled(running)
                }
                Button(L10n.s("diff.recalc")) { reload() }.buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                Text(L10n.s("diff.file")).foregroundStyle(.secondary)
                TextField(L10n.s("diff.filePlaceholder"), text: $pathOverride).textFieldStyle(.roundedBorder)
                if let f = effectiveFile { Text(f).font(.caption).foregroundStyle(.tertiary) }
                Spacer()
            }
        }
    }

    // MARK: - Diff 行解析

    private func recomputeParsedLines() {
        parsedLines = DiffLineRenderer.parse(patch)
    }

    private var patchContent: some View {
        GroupBox(L10n.s("diff.patch")) {
            if patch.isEmpty || patch == L10n.s("diff.noDiff") {
                Text(L10n.s("diff.noDiff"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(parsedLines) { line in
                            DiffLineRenderer(line: line)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - 计算

    private func reload() {
        running = true; error = false; patch = ""
        let capturedMode = mode
        let capturedIsFixedRange = isFixedRange
        let capturedARef = aRef
        let capturedBRef = bRef
        let capturedFile = effectiveFile
        Task {
            let result: String
            if capturedIsFixedRange {
                result = await Task.detached { LogQuery.diff(root: self.repoRoot, capturedARef, capturedBRef, file: capturedFile) }.value
            } else {
                switch capturedMode {
                case .worktreeVsStaged:
                    let args = ["diff", "--no-color", "--"] + (capturedFile.flatMap { [$0] } ?? [])
                    let r = await GitTaskHelper.runOptional(args, in: repoRoot)
                    result = r?.stdout ?? ""
                case .worktreeVsHEAD:
                    result = await Task.detached { LogQuery.diff(root: self.repoRoot, "HEAD", nil, file: capturedFile) }.value
                case .stagedVsHEAD:
                    let args = ["diff", "--staged", "HEAD", "--no-color", "--"] + (capturedFile.flatMap { [$0] } ?? [])
                    let r = await GitTaskHelper.runOptional(args, in: repoRoot)
                    result = r?.stdout ?? ""
                }
            }
            if result.isEmpty && !capturedIsFixedRange {
                patch = L10n.s("diff.noDiff")
                error = false
            } else {
                patch = result.isEmpty ? L10n.s("diff.noDiff") : result
                error = patch.contains("fatal:")
            }
            running = false
        }
    }

    private func openInDifftool() {
        let tool = store.diffTool
        var args = ["difftool", "--tool=\(tool)", "--no-prompt"]
        if isFixedRange {
            args += ["\(aRef ?? "")..\(bRef ?? "")"]
        } else {
            switch mode {
            case .worktreeVsStaged: break
            case .worktreeVsHEAD:   args += ["HEAD"]
            case .stagedVsHEAD:     args += ["--staged", "HEAD"]
            }
        }
        args += ["--"]
        if let v = effectiveFile, !v.isEmpty { args += [v] }
        Task {
            _ = await GitTaskHelper.runOptional(args, in: repoRoot, timeout: 60)
        }
    }
}
