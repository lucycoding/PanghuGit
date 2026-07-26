import XCTest
@testable import PanghuGit

final class ActionRouterIdTests: XCTestCase {

    // MARK: - Window ID uniqueness

    func testDifferentReposProduceDifferentIds() {
        let root1 = URL(fileURLWithPath: "/Users/test/repo1")
        let root2 = URL(fileURLWithPath: "/Users/test/repo2")
        let id1 = rid("commit", root: root1)
        let id2 = rid("commit", root: root2)
        XCTAssertNotEqual(id1, id2)
    }

    func testSameRepoSameId() {
        let root = URL(fileURLWithPath: "/Users/test/repo")
        let id1 = rid("commit", root: root)
        let id2 = rid("commit", root: root)
        XCTAssertEqual(id1, id2)
    }

    func testDifferentActionsDifferentIds() {
        let root = URL(fileURLWithPath: "/Users/test/repo")
        let id1 = rid("commit", root: root)
        let id2 = rid("log", root: root)
        XCTAssertNotEqual(id1, id2)
    }

    func testNilRootReturnsBase() {
        let id = rid("settings", root: nil)
        XCTAssertEqual(id, "settings")
    }

    func testIdContainsSanitizedPath() {
        let root = URL(fileURLWithPath: "/Users/test/my-repo")
        let id = rid("commit", root: root)
        XCTAssertTrue(id.hasPrefix("commit-"))
        XCTAssertFalse(id.contains("/"))
    }

    private func rid(_ base: String, root: URL?) -> String {
        guard let root else { return base }
        let safe = root.path.replacingOccurrences(of: "/", with: "_")
        return "\(base)-\(safe)"
    }
}
