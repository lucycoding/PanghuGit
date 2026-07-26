import Foundation

enum BisectPhase {
    case idle, bisecting, found
}

enum BisectOutputParser {
    struct Result {
        var phase: BisectPhase
        var foundCommit: String
        var currentCommit: String
        var remainingSteps: Int
    }

    static func parse(_ output: String) -> Result {
        if output.contains("is the first bad commit") {
            let lines = output.components(separatedBy: "\n")
            let sha = lines.first.map { line in
                line.split(separator: " ").first.map(String.init) ?? line
            } ?? ""
            return Result(phase: .found, foundCommit: sha.trimmingCharacters(in: .whitespaces), currentCommit: "", remainingSteps: 0)
        } else {
            var commit = ""
            var steps = 0
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") && trimmed.contains("]") {
                    if let openBracket = trimmed.firstIndex(of: "["),
                       let closingBracket = trimmed.firstIndex(of: "]"),
                       openBracket < closingBracket {
                        commit = String(trimmed[trimmed.index(after: openBracket)..<closingBracket])
                    }
                }
                if let range = trimmed.range(of: "(\\d+) revisions? left", options: .regularExpression) {
                    let numStr = trimmed[range].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    if let n = Int(numStr) { steps = n }
                }
            }
            return Result(phase: .bisecting, foundCommit: "", currentCommit: commit, remainingSteps: steps)
        }
    }
}
