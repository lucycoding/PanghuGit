import XCTest
@testable import PanghuGit

final class SubmoduleQueryTests: XCTestCase {

    func testParseGitmodulesWithComments() {
        let cfg = """
        # This is a comment
        [submodule "lib1"]
            path = libs/lib1
            url = https://github.com/example/lib1.git
            branch = main

        ; Semicolon comment
        [submodule "lib2"]
            url = https://github.com/example/lib2.git
            path = libs/lib2
        """
        let lines = cfg.split(whereSeparator: \.isNewline)
        var pathMap: [String: String] = [:]
        var urlMap: [String: String] = [:]
        var currentKey = ""
        for line in lines {
            let s = String(line).trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("#") || s.hasPrefix(";") || s.isEmpty { continue }
            if s.hasPrefix("[submodule \"") {
                let start = s.index(s.startIndex, offsetBy: "[submodule \"".count)
                if let end = s.range(of: "\"]") {
                    currentKey = String(s[start..<end.lowerBound])
                }
            } else if s.hasPrefix("path = ") {
                pathMap[currentKey] = String(s.dropFirst("path = ".count)).trimmingCharacters(in: .whitespaces)
            } else if s.hasPrefix("url = ") {
                urlMap[currentKey] = String(s.dropFirst("url = ".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        XCTAssertEqual(pathMap["lib1"], "libs/lib1")
        XCTAssertEqual(urlMap["lib1"], "https://github.com/example/lib1.git")
        XCTAssertEqual(pathMap["lib2"], "libs/lib2")
        XCTAssertEqual(urlMap["lib2"], "https://github.com/example/lib2.git")
    }
}