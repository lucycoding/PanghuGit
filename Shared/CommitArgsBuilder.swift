import Foundation

enum CommitArgsBuilder {
    public static func build(message: String, amend: Bool, skipHooks: Bool, signoff: Bool, customAuthor: String) -> [String] {
        var args = ["commit"]
        if amend { args.append("--amend") }
        let lines = message.components(separatedBy: "\n")
        if lines.count <= 1 {
            args += ["-m", message]
        } else {
            let title = lines[0]
            let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            args += ["-m", title]
            if !body.isEmpty { args += ["-m", body] }
        }
        if skipHooks { args.append("--no-verify") }
        if signoff { args.append("-s") }
        if !customAuthor.isEmpty { args.append("--author=\(customAuthor)") }
        return args
    }
}
