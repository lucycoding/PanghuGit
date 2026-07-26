import SwiftUI
import AppKit

struct ConflictDetailView: View {
    let repoRoot: URL
    let filePath: String
    @Binding var conflictFile: ConflictFile?

    @State private var oursContent: String = ""
    @State private var baseContent: String?
    @State private var theirsContent: String = ""
    @State private var resolved: [String: String] = [:]
    @State private var undoStack: [(String, String)] = []
    @State private var showManualEdit = false
    @State private var manualEditContent: String = ""
    @State private var activeBlock: ConflictBlock.ID?
    @State private var loading = true
    @State private var showResidualWarning = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let file = conflictFile, file.isBinary {
                binaryConflictUI
            } else if let file = conflictFile, !file.blocks.isEmpty {
                conflictContentUI(file)
            } else {
                EmptyStateView(message: L10n.s("conflict.noConflictBlocks"), systemImage: "doc.text.magnifyingglass")
            }
        }
        .onAppear { loadStageContents() }
        .alert(L10n.s("conflict.residualWarning.title"), isPresented: $showResidualWarning) {
            Button(L10n.s("common.ok")) {}
        } message: {
            Text(L10n.s("conflict.residualWarning.message"))
        }
    }

    private var header: some View {
        HStack {
            Text(filePath).monospaced().font(.headline).lineLimit(1).truncationMode(.middle)
            Spacer()
            if let file = conflictFile, !file.isBinary {
                let total = file.blocks.count
                let done = resolved.count
                Text(L10n.f("conflict.blockProgress", done, total))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(L10n.s("conflict.editManually")) { openManualEdit() }
                .buttonStyle(.bordered).controlSize(.small)
            Button(L10n.s("conflict.openFileMerge")) { openFileMerge() }
                .buttonStyle(.bordered).controlSize(.small)
            if !undoStack.isEmpty {
                Button(L10n.s("conflict.undo")) { undoLast() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }.padding(10)
    }

    private func conflictContentUI(_ file: ConflictFile) -> some View {
        VStack(spacing: 0) {
            threeColumnDiff(file)
            Divider()
            blockActionBar(file)
        }
    }

    private func threeColumnDiff(_ file: ConflictFile) -> some View {
        let oursLines = oursContent.components(separatedBy: "\n")
        let theirsLines = theirsContent.components(separatedBy: "\n")
        let baseLines = baseContent?.components(separatedBy: "\n") ?? []

        return HStack(spacing: 1) {
            columnView(title: L10n.s("conflict.ours"), lines: oursLines, color: .blue, file: file, side: .ours)
            if baseContent != nil {
                columnView(title: L10n.s("conflict.base"), lines: baseLines, color: .gray, file: file, side: .base)
            }
            columnView(title: L10n.s("conflict.theirs"), lines: theirsLines, color: .orange, file: file, side: .theirs)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private enum ConflictSide { case ours, base, theirs }

    private func columnView(title: String, lines: [String], color: Color, file: ConflictFile, side: ConflictSide) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(color).frame(maxWidth: .infinity).padding(.vertical, 2).background(color.opacity(0.1))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        let lineNum = idx
                        let inConflict = blockContainingLine(lineNum, in: file) != nil
                        let isResolved = isLineResolved(lineNum, in: file)
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(rowBackground(inConflict: inConflict, isResolved: isResolved, side: side))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let block = blockContainingLine(lineNum, in: file) {
                                    activeBlock = block.id
                                }
                            }
                    }
                }
            }
        }
    }

    private func rowBackground(inConflict: Bool, isResolved: Bool, side: ConflictSide) -> Color {
        if isResolved { return Color.green.opacity(0.1) }
        if !inConflict { return .clear }
        switch side {
        case .ours: return Color.blue.opacity(0.08)
        case .base: return Color.gray.opacity(0.08)
        case .theirs: return Color.orange.opacity(0.08)
        }
    }

    private func blockContainingLine(_ line: Int, in file: ConflictFile) -> ConflictBlock? {
        file.blocks.first { line >= $0.markerLine && line <= $0.endLine }
    }

    private func isLineResolved(_ line: Int, in file: ConflictFile) -> Bool {
        guard let block = blockContainingLine(line, in: file) else { return false }
        return resolved[block.id] != nil
    }

    private func blockActionBar(_ file: ConflictFile) -> some View {
        let unresolved = file.blocks.filter { resolved[$0.id] == nil }
        let currentBlock = unresolved.first ?? file.blocks.first

        return HStack(spacing: 8) {
            if let block = currentBlock {
                let idx = file.blocks.firstIndex(where: { $0.id == block.id }) ?? 0
                Text(L10n.f("conflict.blockLabel", idx + 1, file.blocks.count))
                    .font(.caption).foregroundStyle(.secondary)

                Button(L10n.s("conflict.acceptOurs")) { acceptBlock(block, content: block.oursContent) }
                    .buttonStyle(.bordered).controlSize(.small)
                if block.baseContent != nil {
                    Button(L10n.s("conflict.acceptBase")) { acceptBlock(block, content: block.baseContent ?? "") }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                Button(L10n.s("conflict.acceptTheirs")) { acceptBlock(block, content: block.theirsContent) }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            Spacer()
        }.padding(8).background(.regularMaterial)
    }

    private var binaryConflictUI: some View {
        VStack(spacing: 16) {
            Text(L10n.s("conflict.binaryFile")).font(.headline)
            HStack(spacing: 24) {
                binaryStageView(label: L10n.s("conflict.ours"), stage: 2)
                if baseContent != nil {
                    binaryStageView(label: L10n.s("conflict.base"), stage: 1)
                }
                binaryStageView(label: L10n.s("conflict.theirs"), stage: 3)
            }
        }.padding(24)
    }

    private func binaryStageView(label: String, stage: Int) -> some View {
        VStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            let size = stageSize(stage: stage)
            Text(size).font(.callout).monospacedDigit()
            Button(L10n.f("conflict.acceptFormat", label)) { acceptBinaryStage(stage: stage) }
                .buttonStyle(.bordered).controlSize(.small)
        }.padding(12).background(.regularMaterial).cornerRadius(8)
    }

    private func stageSize(stage: Int) -> String {
        let content = stage == 2 ? oursContent : (stage == 3 ? theirsContent : (baseContent ?? ""))
        let bytes = content.utf8.count
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1048576 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / 1048576.0)
    }

    private func acceptBinaryStage(stage: Int) {
        let content = stage == 2 ? oursContent : (stage == 3 ? theirsContent : (baseContent ?? ""))
        let url = repoRoot.appendingPathComponent(filePath)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        let path = filePath
        Task {
            _ = await GitTaskHelper.runOptional(["add", "--", path], in: repoRoot, timeout: 10)
        }
    }

    private func loadStageContents() {
        let path = filePath
        let root = repoRoot
        Task {
            async let ours = Task.detached { ConflictParser.indexStageContent(root: root, stage: 2, path: path) ?? "" }.value
            async let base = Task.detached { ConflictParser.indexStageContent(root: root, stage: 1, path: path) }.value
            async let theirs = Task.detached { ConflictParser.indexStageContent(root: root, stage: 3, path: path) ?? "" }.value
            async let rawContent = Task.detached {
                let fullPath = root.appendingPathComponent(path).path
                return (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
            }.value

            oursContent = await ours
            baseContent = await base
            theirsContent = await theirs
            conflictFile = ConflictParser.parse(content: await rawContent, path: path)
            loading = false
        }
    }

    private func acceptBlock(_ block: ConflictBlock, content: String) {
        undoStack.append((block.id, resolved[block.id] ?? ""))
        resolved[block.id] = content
        writeResolvedToFile()
    }

    private func undoLast() {
        guard let last = undoStack.popLast() else { return }
        if last.1.isEmpty {
            resolved.removeValue(forKey: last.0)
        } else {
            resolved[last.0] = last.1
        }
        writeResolvedToFile()
    }

    private func writeResolvedToFile() {
        guard let file = conflictFile else { return }
        let newContent = ConflictParser.resolveContent(
            rawContent: file.rawContent, blocks: file.blocks, resolved: resolved)
        let url = repoRoot.appendingPathComponent(filePath)
        try? newContent.write(to: url, atomically: true, encoding: .utf8)

        if ConflictParser.hasResidualConflictMarkers(newContent) {
            showResidualWarning = true
        }

        let allResolved = file.blocks.allSatisfy { resolved[$0.id] != nil }
        if allResolved {
            let path = filePath
            Task {
                _ = await GitTaskHelper.runOptional(["add", "--", path], in: repoRoot, timeout: 10)
                SettingsStore.postBadgeRefresh()
            }
        }
    }

    private func openManualEdit() {
        guard let file = conflictFile else { return }
        let newContent = ConflictParser.resolveContent(
            rawContent: file.rawContent, blocks: file.blocks, resolved: resolved)
        manualEditContent = newContent
        showManualEdit = true
        HostWindow.show(id: "conflict-manual-\(filePath)", title: L10n.f("conflict.manualEditTitle", filePath)) {
            ManualConflictEditor(content: $manualEditContent, onSave: {
                let url = repoRoot.appendingPathComponent(filePath)
                try? manualEditContent.write(to: url, atomically: true, encoding: .utf8)
                if ConflictParser.hasResidualConflictMarkers(manualEditContent) {
                    showResidualWarning = true
                }
                let path = filePath
                Task {
                    _ = await GitTaskHelper.runOptional(["add", "--", path], in: repoRoot, timeout: 10)
                    SettingsStore.postBadgeRefresh()
                }
            })
        }
    }

    private func openFileMerge() {
        let root = repoRoot
        let capturedFilePath = filePath
        Task.detached {
            let safeName = capturedFilePath.replacingOccurrences(of: "/", with: "_")
            let oursTemp = NSTemporaryDirectory() + "panghugit_conflict_ours_\(safeName)"
            let theirsTemp = NSTemporaryDirectory() + "panghugit_conflict_theirs_\(safeName)"
            let oursData = ConflictParser.indexStageContent(root: root, stage: 2, path: capturedFilePath) ?? ""
            let theirsData = ConflictParser.indexStageContent(root: root, stage: 3, path: capturedFilePath) ?? ""
            try? oursData.write(toFile: oursTemp, atomically: true, encoding: .utf8)
            try? theirsData.write(toFile: theirsTemp, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/opendiff")
            process.arguments = [oursTemp, theirsTemp]
            process.terminationHandler = { _ in
                try? FileManager.default.removeItem(atPath: oursTemp)
                try? FileManager.default.removeItem(atPath: theirsTemp)
            }
            do {
                try process.run()
            } catch {
                try? FileManager.default.removeItem(atPath: oursTemp)
                try? FileManager.default.removeItem(atPath: theirsTemp)
            }
        }
    }
}

struct ManualConflictEditor: View {
    @Binding var content: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Spacer()
                Button(L10n.s("common.save")) { onSave() }
                    .buttonStyle(.borderedProminent)
            }.padding(8)
        }.frame(minWidth: 600, minHeight: 400)
    }
}
