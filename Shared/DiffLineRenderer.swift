import SwiftUI

enum DiffLineKind {
    case header, fileMeta, hunk, added, removed, context
}

struct DiffLine: Identifiable {
    let id: Int
    let text: String
    let kind: DiffLineKind
}

struct DiffLineRenderer: View {
    let line: DiffLine

    var body: some View {
        let (fg, bg) = Self.colors(line.kind)
        Text(line.text)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 0.5)
            .padding(.horizontal, 6)
            .background(bg)
    }

    static func colors(_ kind: DiffLineKind) -> (Color, Color) {
        switch kind {
        case .header:  return (.secondary, Color(nsColor: .controlBackgroundColor))
        case .fileMeta: return (.primary, Color.purple.opacity(0.08))
        case .hunk:    return (.accentColor, Color.accentColor.opacity(0.08))
        case .added:   return (Color(nsColor: .textColor), Color.green.opacity(0.18))
        case .removed: return (Color(nsColor: .textColor), Color.red.opacity(0.18))
        case .context: return (Color(nsColor: .textColor), Color.clear)
        }
    }

    static func parse(_ text: String) -> [DiffLine] {
        guard !text.isEmpty else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { i, line in
            let s = String(line)
            let kind: DiffLineKind
            if s.hasPrefix("diff --git") { kind = .header }
            else if s.hasPrefix("index ") || s.hasPrefix("--- ") || s.hasPrefix("+++ ") { kind = .fileMeta }
            else if s.hasPrefix("@@") { kind = .hunk }
            else if s.hasPrefix("+") { kind = .added }
            else if s.hasPrefix("-") { kind = .removed }
            else { kind = .context }
            return DiffLine(id: i, text: s, kind: kind)
        }
    }
}
