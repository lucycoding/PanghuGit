import XCTest
@testable import PanghuGit

final class PanghuGitURLSchemeTests: XCTestCase {

    func testRoundTripBasic() {
        let target = URL(fileURLWithPath: "/Users/foo/myrepo")
        let inv = PanghuGitInvocation(action: .commit, target: target, selected: [])
        guard let url = PanghuGitURLScheme.makeURL(for: inv) else {
            XCTFail("makeURL returned nil"); return
        }
        XCTAssertEqual(url.scheme, "panghugit")
        XCTAssertEqual(url.host, "commit")
        let parsed = PanghuGitURLScheme.parse(url)
        XCTAssertEqual(parsed?.action, .commit)
        XCTAssertEqual(parsed?.target?.path, "/Users/foo/myrepo")
        XCTAssertTrue(parsed?.selected.isEmpty ?? false)
    }

    func testRoundTripWithSelectedNULSeparated() {
        let target = URL(fileURLWithPath: "/repo")
        let selected = [
            URL(fileURLWithPath: "/repo/a.txt"),
            URL(fileURLWithPath: "/repo/path,with,comma.txt")
        ]
        let inv = PanghuGitInvocation(action: .ignore, target: target, selected: selected)
        guard let url = PanghuGitURLScheme.makeURL(for: inv) else {
            XCTFail("makeURL returned nil"); return
        }
        let parsed = PanghuGitURLScheme.parse(url)
        XCTAssertEqual(parsed?.action, .ignore)
        XCTAssertEqual(parsed?.selected.count, 2)
        XCTAssertEqual(parsed?.selected.first?.path, "/repo/a.txt")
        XCTAssertEqual(parsed?.selected.last?.path, "/repo/path,with,comma.txt")
    }

    func testInvalidSchemeRejected() {
        let url = URL(string: "http://commit?target=/foo")!
        XCTAssertNil(PanghuGitURLScheme.parse(url))
    }

    func testUnknownActionRejected() {
        let url = URL(string: "panghugit://unknownaction?target=/foo")!
        XCTAssertNil(PanghuGitURLScheme.parse(url))
    }

    func testNoTargetNoPaths() {
        let inv = PanghuGitInvocation(action: .settings, target: nil, selected: [])
        guard let url = PanghuGitURLScheme.makeURL(for: inv) else {
            XCTFail("makeURL returned nil"); return
        }
        let parsed = PanghuGitURLScheme.parse(url)
        XCTAssertEqual(parsed?.action, .settings)
        XCTAssertNil(parsed?.target)
        XCTAssertTrue(parsed?.selected.isEmpty ?? false)
    }
}
