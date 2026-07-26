import Foundation

public struct ConflictBlock: Identifiable, Sendable {
    public let id: String
    public let markerLine: Int
    public let oursContent: String
    public let theirsContent: String
    public let baseContent: String?
    public let separatorLine: Int
    public let endLine: Int

    public init(id: String, markerLine: Int, oursContent: String, theirsContent: String, baseContent: String?, separatorLine: Int, endLine: Int) {
        self.id = id
        self.markerLine = markerLine
        self.oursContent = oursContent
        self.theirsContent = theirsContent
        self.baseContent = baseContent
        self.separatorLine = separatorLine
        self.endLine = endLine
    }
}

public struct ConflictFile: Identifiable, Sendable {
    public let id: String
    public let path: String
    public let blocks: [ConflictBlock]
    public let rawContent: String
    public let isBinary: Bool

    public init(id: String, path: String, blocks: [ConflictBlock], rawContent: String, isBinary: Bool) {
        self.id = id
        self.path = path
        self.blocks = blocks
        self.rawContent = rawContent
        self.isBinary = isBinary
    }
}

public enum ConflictParser {
    private static let markerOurs = "<<<<<<< "
    private static let markerBase = "|||||| "
    private static let markerSep = "======="
    private static let markerTheirs = ">>>>>>> "

    public static func parse(content: String, path: String) -> ConflictFile {
        let isBinary = detectBinary(content)
        guard !isBinary else {
            return ConflictFile(id: path, path: path, blocks: [], rawContent: content, isBinary: true)
        }
        let blocks = parseBlocks(content, path: path)
        return ConflictFile(id: path, path: path, blocks: blocks, rawContent: content, isBinary: false)
    }

    public static func parseBlocks(_ content: String, path: String = "") -> [ConflictBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [ConflictBlock] = []
        var i = 0

        while i < lines.count {
            guard lines[i].hasPrefix(markerOurs) else { i += 1; continue }

            let markerLine = i
            i += 1

            var oursLines: [String] = []
            var baseLines: [String]?
            var theirsLines: [String] = []
            var sepLine = -1
            var endLine = -1
            var phase = 0 // 0=ours, 1=base(diff3), 2=theirs

            while i < lines.count {
                if lines[i].hasPrefix(markerTheirs) {
                    endLine = i
                    i += 1
                    break
                } else if lines[i].hasPrefix(markerBase) && phase == 0 {
                    phase = 1
                    baseLines = []
                    i += 1
                } else if lines[i].hasPrefix(markerSep) && phase < 2 {
                    sepLine = i
                    phase = 2
                    i += 1
                } else {
                    switch phase {
                    case 0: oursLines.append(lines[i])
                    case 1: baseLines!.append(lines[i])
                    case 2: theirsLines.append(lines[i])
                    default: break
                    }
                    i += 1
                }
            }

            guard sepLine >= 0, endLine >= 0 else { break }

            let oursContent = oursLines.joined(separator: "\n")
            let theirsContent = theirsLines.joined(separator: "\n")
            let baseContent = baseLines.map { $0.joined(separator: "\n") }

            blocks.append(ConflictBlock(
                id: "\(path):\(markerLine)",
                markerLine: markerLine,
                oursContent: oursContent,
                theirsContent: theirsContent,
                baseContent: baseContent,
                separatorLine: sepLine,
                endLine: endLine
            ))
        }

        return blocks
    }

    public static func resolveContent(rawContent: String, blocks: [ConflictBlock], resolved: [String: String]) -> String {
        var lines = rawContent.components(separatedBy: "\n")
        let sortedBlocks = blocks.sorted { $0.endLine > $1.endLine }

        for block in sortedBlocks {
            guard let replacement = resolved[block.id] else { continue }
            let replacementLines = replacement.components(separatedBy: "\n")
            let range = block.markerLine...block.endLine
            lines.replaceSubrange(range, with: replacementLines)
        }

        return lines.joined(separator: "\n")
    }

    public static func hasResidualConflictMarkers(_ content: String) -> Bool {
        content.contains(markerOurs) || content.contains(markerTheirs)
    }

    private static func detectBinary(_ content: String) -> Bool {
        if let data = content.data(using: .utf8) {
            let sampleSize = min(8192, data.count)
            for i in 0..<sampleSize where data[i] == 0 {
                return true
            }
        }
        return false
    }

    public static func indexStageContent(root: URL, stage: Int, path: String) -> String? {
        let r = try? GitRunner.configuredWithTimeout(10).run(
            ["show", ":\(stage):\(path)"], in: root)
        guard let r, r.isSuccess else { return nil }
        return r.stdout
    }
}
