import SwiftUI

public enum CommitFileStatus: String {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case typeChange = "T"
    case unknown = ""

    public init(raw: String) {
        let c = raw.trimmingCharacters(in: .letters.inverted)
        switch c {
        case "A": self = .added
        case "M": self = .modified
        case "D": self = .deleted
        case "R": self = .renamed
        case "C": self = .copied
        case "T": self = .typeChange
        default: self = .unknown
        }
    }

    public var icon: String {
        switch self {
        case .added: return "✔"
        case .modified: return "!"
        case .deleted: return "×"
        case .renamed: return "→"
        case .copied: return "✔"
        case .typeChange: return "!"
        case .unknown: return "?"
        }
    }

    public var color: Color {
        switch self {
        case .added: return .blue
        case .modified: return .red
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .blue
        case .typeChange: return .red
        case .unknown: return .secondary
        }
    }

    public var bgColor: Color {
        switch self {
        case .added: return .blue.opacity(0.12)
        case .modified: return .red.opacity(0.12)
        case .deleted: return .red.opacity(0.12)
        case .renamed: return .blue.opacity(0.12)
        case .copied: return .blue.opacity(0.12)
        case .typeChange: return .red.opacity(0.12)
        case .unknown: return Color(nsColor: .controlBackgroundColor)
        }
    }

    public var label: String {
        switch self {
        case .added: return L10n.s("log.status.added")
        case .modified: return L10n.s("log.status.modified")
        case .deleted: return L10n.s("log.status.deleted")
        case .renamed: return L10n.s("log.status.renamed")
        case .copied: return L10n.s("log.status.copied")
        case .typeChange: return L10n.s("log.status.typeChange")
        case .unknown: return rawValue
        }
    }
}
