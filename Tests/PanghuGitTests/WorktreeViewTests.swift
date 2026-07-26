import XCTest
@testable import PanghuGit

final class WorktreeViewTests: XCTestCase {

    // MARK: - parseWorktreeList

    func testParseSingleWorktree() {
        let output = """
        worktree /Users/test/repo
        HEAD abc1234def5678
        branch refs/heads/main

        """
        let entries = WorktreeView.parseWorktreeList(output)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].directory, "/Users/test/repo")
        XCTAssertEqual(entries[0].sha, "abc1234def5678")
        XCTAssertEqual(entries[0].branch, "main")
    }

    func testParseMultipleWorktrees() {
        let output = """
        worktree /Users/test/repo
        HEAD abc1234
        branch refs/heads/main

        worktree /Users/test/repo-feature
        HEAD def5678
        branch refs/heads/feature

        """
        let entries = WorktreeView.parseWorktreeList(output)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].branch, "main")
        XCTAssertEqual(entries[1].branch, "feature")
    }

    func testParseDetachedWorktree() {
        let output = """
        worktree /Users/test/repo
        HEAD abc1234
        branch refs/heads/main

        worktree /Users/test/repo-detached
        HEAD def5678
        detached

        """
        let entries = WorktreeView.parseWorktreeList(output)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[1].branch, "", "Detached worktrees have no branch")
    }

    func testParseEmptyOutput() {
        let entries = WorktreeView.parseWorktreeList("")
        XCTAssertEqual(entries.count, 0)
    }

    func testParseWorktreeWithNoTrailingNewline() {
        let output = """
        worktree /Users/test/repo
        HEAD abc1234
        branch refs/heads/main
        """
        let entries = WorktreeView.parseWorktreeList(output)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].directory, "/Users/test/repo")
    }

    func testParseWorktreeWithBareRepo() {
        let output = """
        worktree /Users/test/repo
        HEAD abc1234
        branch refs/heads/develop

        """
        let entries = WorktreeView.parseWorktreeList(output)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].branch, "develop")
    }
}
