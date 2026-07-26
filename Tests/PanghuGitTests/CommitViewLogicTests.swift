import XCTest
@testable import PanghuGit

final class CommitViewLogicTests: XCTestCase {

    // MARK: - buildCommitArgs logic

    func testCommitArgsBasic() {
        let args = buildCommitArgs(message: "test commit", amend: false, skipHooks: false, signoff: false, customAuthor: "")
        XCTAssertEqual(args[0], "commit")
        XCTAssertEqual(args[1], "-m")
        XCTAssertEqual(args[2], "test commit")
        XCTAssertFalse(args.contains("--amend"))
        XCTAssertFalse(args.contains("--no-verify"))
        XCTAssertFalse(args.contains("-s"))
    }

    func testCommitArgsAmend() {
        let args = buildCommitArgs(message: "amended", amend: true, skipHooks: false, signoff: false, customAuthor: "")
        XCTAssertTrue(args.contains("--amend"))
    }

    func testCommitArgsSkipHooks() {
        let args = buildCommitArgs(message: "test", amend: false, skipHooks: true, signoff: false, customAuthor: "")
        XCTAssertTrue(args.contains("--no-verify"))
    }

    func testCommitArgsSignoff() {
        let args = buildCommitArgs(message: "test", amend: false, skipHooks: false, signoff: true, customAuthor: "")
        XCTAssertTrue(args.contains("-s"))
    }

    func testCommitArgsCustomAuthor() {
        let args = buildCommitArgs(message: "test", amend: false, skipHooks: false, signoff: false, customAuthor: "Alice <alice@example.com>")
        XCTAssertTrue(args.contains("--author=Alice <alice@example.com>"))
    }

    func testCommitArgsMultilineMessage() {
        let args = buildCommitArgs(message: "title\n\nbody line 1\nbody line 2", amend: false, skipHooks: false, signoff: false, customAuthor: "")
        XCTAssertTrue(args.contains("-m"))
        XCTAssertTrue(args.contains("title"))
        XCTAssertTrue(args.contains("-m"))
        XCTAssertTrue(args.contains("body line 1\nbody line 2"))
    }

    func testCommitArgsMultilineMessageEmptyBody() {
        let args = buildCommitArgs(message: "title\n\n", amend: false, skipHooks: false, signoff: false, customAuthor: "")
        let mIndices = args.enumerated().filter { $0.element == "-m" }.map(\.offset)
        XCTAssertEqual(mIndices.count, 1, "Empty body should not produce extra -m")
    }

    func testCommitArgsAllFlags() {
        let args = buildCommitArgs(message: "test", amend: true, skipHooks: true, signoff: true, customAuthor: "Bob <bob@test.com>")
        XCTAssertTrue(args.contains("--amend"))
        XCTAssertTrue(args.contains("--no-verify"))
        XCTAssertTrue(args.contains("-s"))
        XCTAssertTrue(args.contains("--author=Bob <bob@test.com>"))
    }

    // MARK: - GitStatusEntry filtering for staged/modified

    func testStagedEntriesFilter() {
        let entries: [GitStatusEntry] = [
            GitStatusEntry(path: "a.txt", xy: "M ", staged: .modified, worktree: .unmodified, isUntracked: false),
            GitStatusEntry(path: "b.txt", xy: " M", staged: .unmodified, worktree: .modified, isUntracked: false),
            GitStatusEntry(path: "c.txt", xy: "MM", staged: .modified, worktree: .modified, isUntracked: false),
            GitStatusEntry(path: "d.txt", xy: "??", staged: .untracked, worktree: .untracked, isUntracked: true),
        ]
        let staged = entries.filter { !$0.isUntracked && $0.staged != .unmodified }
        XCTAssertEqual(staged.map(\.path), ["a.txt", "c.txt"])
    }

    func testModifiedEntriesFilter() {
        let entries: [GitStatusEntry] = [
            GitStatusEntry(path: "a.txt", xy: "M ", staged: .modified, worktree: .unmodified, isUntracked: false),
            GitStatusEntry(path: "b.txt", xy: " M", staged: .unmodified, worktree: .modified, isUntracked: false),
            GitStatusEntry(path: "c.txt", xy: "MM", staged: .modified, worktree: .modified, isUntracked: false),
        ]
        let modified = entries.filter { !$0.isUntracked && $0.worktree != .unmodified }
        XCTAssertEqual(modified.map(\.path), ["b.txt", "c.txt"])
    }

    private func buildCommitArgs(message: String, amend: Bool, skipHooks: Bool, signoff: Bool, customAuthor: String) -> [String] {
        CommitArgsBuilder.build(message: message, amend: amend, skipHooks: skipHooks, signoff: signoff, customAuthor: customAuthor)
    }
}
