import Foundation

enum DiffOrigin {
    case staged, worktree
}

struct DiffFileGroup: Identifiable {
    let id: Int
    let header: String
    let filePath: String
    let hunks: [DiffHunk]
    let origin: DiffOrigin
    let isBinary: Bool
}

struct DiffHunk: Identifiable {
    let id: Int
    let header: String
    let lines: [String]
    let startIndex: Int
}

struct HunkParser {
    static func parse(_ diffText: String, origin: DiffOrigin = .worktree) -> [DiffFileGroup] {
        let lines = diffText.components(separatedBy: "\n")
        var groups: [DiffFileGroup] = []
        var currentHeader = ""
        var currentPath = ""
        var currentHunks: [DiffHunk] = []
        var hunkLines: [String] = []
        var hunkHeader = ""
        var hunkStart = 0
        var fileIndex = 0
        var hunkIndex = 0
        var inHunk = false
        var isBinary = false

        for line in lines {
            if line.hasPrefix("diff --git") {
                if inHunk {
                    currentHunks.append(DiffHunk(id: hunkIndex, header: hunkHeader, lines: hunkLines, startIndex: hunkStart))
                    hunkIndex += 1
                    hunkLines = []
                    inHunk = false
                }
                if !currentHeader.isEmpty || !currentHunks.isEmpty {
                    groups.append(DiffFileGroup(id: fileIndex, header: currentHeader, filePath: currentPath, hunks: currentHunks, origin: origin, isBinary: isBinary))
                    fileIndex += 1
                }
                currentHeader = line
                currentPath = extractPath(from: line)
                currentHunks = []
                hunkIndex = 0
                isBinary = false
            } else if line.hasPrefix("--- ") || line.hasPrefix("+++ ") {
                currentHeader += "\n" + line
            } else if line.hasPrefix("Binary files") {
                isBinary = true
            } else if line.hasPrefix("@@") {
                if inHunk {
                    currentHunks.append(DiffHunk(id: hunkIndex, header: hunkHeader, lines: hunkLines, startIndex: hunkStart))
                    hunkIndex += 1
                }
                hunkHeader = line
                hunkLines = []
                hunkStart = groups.count * 1000 + hunkIndex
                inHunk = true
            } else if inHunk {
                hunkLines.append(line)
            }
        }

        if inHunk {
            currentHunks.append(DiffHunk(id: hunkIndex, header: hunkHeader, lines: hunkLines, startIndex: hunkStart))
        }
        if !currentHeader.isEmpty || !currentHunks.isEmpty {
            groups.append(DiffFileGroup(id: fileIndex, header: currentHeader, filePath: currentPath, hunks: currentHunks, origin: origin, isBinary: isBinary))
        }

        return groups
    }

    static func buildPatchHeader(for path: String) -> String {
        "diff --git a/\(path) b/\(path)\n--- a/\(path)\n+++ b/\(path)"
    }

    static func buildPatch(header: String, hunk: DiffHunk) -> String {
        header + "\n" + hunk.header + "\n" + hunk.lines.joined(separator: "\n") + "\n"
    }

    private static func extractPath(from diffGitLine: String) -> String {
        if let aRange = diffGitLine.range(of: " a/"), let bRange = diffGitLine.range(of: " b/", range: aRange.upperBound..<diffGitLine.endIndex) {
            let raw = String(diffGitLine[aRange.upperBound..<bRange.lowerBound])
            return unquotePath(raw)
        }
        if let qA = diffGitLine.range(of: " \"a/"), let qB = diffGitLine.range(of: "\" \"b/", range: qA.upperBound..<diffGitLine.endIndex) {
            let raw = String(diffGitLine[qA.upperBound..<qB.lowerBound])
            return unquotePath(raw)
        }
        if let qA = diffGitLine.range(of: " \"a/") {
            let afterA = diffGitLine[qA.upperBound...]
            if let closing = afterA.range(of: "\"") {
                let raw = String(afterA[..<closing.lowerBound])
                return unquotePath(raw)
            }
        }
        return ""
    }

    private static func unquotePath(_ path: String) -> String {
        path.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
