import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportView: View {
    let repoRoot: URL

    @State private var ref: String = "HEAD"
    @State private var format: ExportFormat = .zip
    @State private var outputPath: String = ""
    @State private var output: String = ""
    @State private var running = false
    @State private var error = false

    enum ExportFormat: String, CaseIterable, Identifiable {
        case zip = "zip"
        case tar = "tar"
        case tarGz = "tar.gz"
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .zip: return ".zip"
            case .tar: return ".tar"
            case .tarGz: return ".tar.gz"
            }
        }
        var gitFormat: String {
            switch self {
            case .zip: return "zip"
            case .tar: return "tar"
            case .tarGz: return "tar.gz"
            }
        }
        var fileExtension: String {
            switch self {
            case .zip: return "zip"
            case .tar: return "tar"
            case .tarGz: return "tar.gz"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(L10n.s("export.params")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.s("export.ref")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                        TextField("HEAD / tag / branch", text: $ref).textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text(L10n.s("export.format")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                        Picker("", selection: $format) {
                            ForEach(ExportFormat.allCases) { Text($0.localizedName).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                    HStack {
                        Text(L10n.s("export.outputFile")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                        TextField(L10n.s("export.outputPlaceholder"), text: $outputPath).textFieldStyle(.roundedBorder)
                        Button(L10n.s("settings.choose")) {
                            let panel = NSSavePanel()
                            panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .item]
                            panel.nameFieldStringValue = "archive.\(format.fileExtension)"
                            if panel.runModal() == .OK, let url = panel.url {
                                outputPath = url.path
                            }
                        }
                    }
                    Text(L10n.s("export.hint")).font(.caption).foregroundStyle(.secondary)
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }

            if !output.isEmpty {
                GroupBox(L10n.s("patch.output")) {
                    Text(output)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(error ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
            }

            Divider()
            StatusBarView(text: output, isError: error, isLoading: running) {
                Button(L10n.s("export.execute")) { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || !canRun)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 340)
    }

    private var canRun: Bool {
        !ref.trimmingCharacters(in: .whitespaces).isEmpty && !outputPath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func run() {
        running = true; error = false; output = ""
        let r = ref.trimmingCharacters(in: .whitespaces)
        let out = outputPath.trimmingCharacters(in: .whitespaces)
        Task {
            let result = await GitTaskHelper.runOptional(
                ["archive", "--format=\(format.gitFormat)", "--output=\(out)", r], in: repoRoot, timeout: 60)
            if let result, result.isSuccess {
                output = L10n.f("export.ok", out)
            } else {
                error = true
                output = GitErrorMessage.friendly(result?.stderr ?? "")
            }
            running = false
        }
    }
}
