import XCTest
@testable import PanghuGit

final class GitErrorMessageTests: XCTestCase {

    func testNotGitRepo() {
        let result = GitErrorMessage.friendly("fatal: not a git repository (or any of the parent directories): .git")
        XCTAssertEqual(result, L10n.s("error.notGitRepo"))
    }

    func testMergeConflict() {
        let result = GitErrorMessage.friendly("CONFLICT (content): Merge conflict in file.swift")
        XCTAssertEqual(result, L10n.s("error.mergeConflict"))
    }

    func testMergeConflictLowercase() {
        let result = GitErrorMessage.friendly("Automatic merge failed; fix merge conflict and commit")
        XCTAssertEqual(result, L10n.s("error.mergeConflict"))
    }

    func testRemoteAccess() {
        let result = GitErrorMessage.friendly("fatal: remote error: Can't connect")
        XCTAssertEqual(result, L10n.s("error.remoteAccess"))
    }

    func testRemoteAccessCouldNotRead() {
        let result = GitErrorMessage.friendly("fatal: Could not read from remote repository")
        XCTAssertEqual(result, L10n.s("error.remoteAccess"))
    }

    func testAuthFailed() {
        let result = GitErrorMessage.friendly("Permission denied (publickey)")
        XCTAssertEqual(result, L10n.s("error.authFailed"))
    }

    func testAuthFailedAuthentication() {
        let result = GitErrorMessage.friendly("Authentication failed for repository")
        XCTAssertEqual(result, L10n.s("error.authFailed"))
    }

    func testPushRejected() {
        let result = GitErrorMessage.friendly("Updates were rejected because the remote contains work that you do")
        XCTAssertEqual(result, L10n.s("error.pushRejected"))
    }

    func testPushRejectedFailedToPush() {
        let result = GitErrorMessage.friendly("error: failed to push some refs to 'origin'")
        XCTAssertEqual(result, L10n.s("error.pushRejected"))
    }

    func testEmptyStringReturnsGitFailed() {
        let result = GitErrorMessage.friendly("")
        XCTAssertEqual(result, L10n.s("common.gitFailed"))
    }

    func testWhitespaceOnlyReturnsGitFailed() {
        let result = GitErrorMessage.friendly("   \n\t  ")
        XCTAssertEqual(result, L10n.s("common.gitFailed"))
    }

    func testUnknownErrorReturnsOriginal() {
        let msg = "something completely unexpected happened"
        let result = GitErrorMessage.friendly(msg)
        XCTAssertEqual(result, msg)
    }

    func testDirtyOverwrite() {
        let result = GitErrorMessage.friendly("error: Your local changes would be overwritten by merge")
        XCTAssertEqual(result, L10n.s("error.dirtyOverwrite"))
    }

    func testNoFastForward() {
        let result = GitErrorMessage.friendly("fatal: not possible to fast-forward, aborting")
        XCTAssertEqual(result, L10n.s("error.noFastForward"))
    }

    func testRemoteNotFound() {
        let result = GitErrorMessage.friendly("fatal: no such remote 'upstream'")
        XCTAssertEqual(result, L10n.s("error.remoteNotFound"))
    }

    func testAlreadyExists() {
        let result = GitErrorMessage.friendly("fatal: A branch named 'foo' already exists")
        XCTAssertEqual(result, L10n.s("error.alreadyExists"))
    }

    func testPathNotFound() {
        let result = GitErrorMessage.friendly("error: pathspec 'xyz' did not match any file(s) known to git")
        XCTAssertEqual(result, L10n.s("error.pathNotFound"))
    }
}
