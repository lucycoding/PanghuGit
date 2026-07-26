import XCTest
@testable import PanghuGit

final class RepoConfigQueryTests: XCTestCase {

    // MARK: - configList parsing (indirect via --list --local output simulation)

    func testConfigListSplitOnFirstEquals() {
        let line = "remote.origin.url=https://github.com/user/repo.git"
        let eq = line.firstIndex(of: "=")
        XCTAssertNotNil(eq)
        let key = String(line[..<eq!])
        let value = String(line[line.index(after: eq!)...])
        XCTAssertEqual(key, "remote.origin.url")
        XCTAssertEqual(value, "https://github.com/user/repo.git")
    }

    func testConfigListValueContainsEquals() {
        let line = "core.gitproxy=proxy for example.com=/usr/bin/connect"
        let eq = line.firstIndex(of: "=")
        XCTAssertNotNil(eq)
        let key = String(line[..<eq!])
        let value = String(line[line.index(after: eq!)...])
        XCTAssertEqual(key, "core.gitproxy")
        XCTAssertEqual(value, "proxy for example.com=/usr/bin/connect")
    }

    func testConfigListEmptyValue() {
        let line = "core.somekey="
        let eq = line.firstIndex(of: "=")
        XCTAssertNotNil(eq)
        let value = String(line[line.index(after: eq!)...])
        XCTAssertEqual(value, "")
    }

    // MARK: - Remote parsing

    func testRemoteParsingFromVerboseOutput() {
        let output = "origin\thttps://github.com/user/repo.git\t(fetch)\norigin\thttps://github.com/user/repo.git\t(push)"
        let lines = output.split(whereSeparator: \.isNewline)
        var map: [String: RepoConfigQuery.Remote] = [:]
        for line in lines {
            let parts = String(line).split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let name = String(parts[0])
            let url = String(parts[1])
            let suffix = String(parts[2]).trimmingCharacters(in: .whitespaces)
            let isPush = suffix.contains("(push)")
            let existing = map[name] ?? RepoConfigQuery.Remote(name: name, fetchURL: nil, pushURL: nil)
            if isPush {
                map[name] = RepoConfigQuery.Remote(name: name, fetchURL: existing.fetchURL, pushURL: url)
            } else {
                map[name] = RepoConfigQuery.Remote(name: name, fetchURL: url, pushURL: existing.pushURL)
            }
        }
        XCTAssertEqual(map.count, 1)
        XCTAssertEqual(map["origin"]?.fetchURL, "https://github.com/user/repo.git")
        XCTAssertEqual(map["origin"]?.pushURL, "https://github.com/user/repo.git")
    }

    // MARK: - Duplicate key handling

    func testDuplicateKeysInConfigList() {
        let pairs: [(key: String, value: String)] = [
            (key: "remote.origin.fetch", value: "+refs/heads/*:refs/remotes/origin/*"),
            (key: "remote.origin.fetch", value: "+refs/tags/*:refs/tags/*"),
            (key: "core.bare", value: "false")
        ]
        let dict = pairs.reduce(into: [String: String]()) { $0[$1.key] = $1.value }
        XCTAssertEqual(dict["remote.origin.fetch"], "+refs/tags/*:refs/tags/*")
        XCTAssertEqual(dict["core.bare"], "false")
    }
}
