import XCTest
@testable import PanghuGit

final class GitFileStatusTests: XCTestCase {

    func testBadgeIdentifiers() {
        XCTAssertEqual(GitFileStatus.modified.badgeIdentifier, "modified")
        XCTAssertEqual(GitFileStatus.added.badgeIdentifier, "added")
        XCTAssertEqual(GitFileStatus.deleted.badgeIdentifier, "deleted")
        XCTAssertEqual(GitFileStatus.renamed.badgeIdentifier, "modified")
        XCTAssertEqual(GitFileStatus.copied.badgeIdentifier, "modified")
        XCTAssertEqual(GitFileStatus.unmergedU.badgeIdentifier, "conflict")
        XCTAssertEqual(GitFileStatus.unmergedBothDeleted.badgeIdentifier, "conflict")
        XCTAssertEqual(GitFileStatus.untracked.badgeIdentifier, "untracked")
        XCTAssertEqual(GitFileStatus.ignored.badgeIdentifier, "ignored")
        XCTAssertEqual(GitFileStatus.unmodified.badgeIdentifier, "")
    }

    func testPrimaryBadgeWorktreePriority() {
        // worktree 状态优先于 staged
        let entry = GitStatusEntry(
            path: "foo.swift", xy: "MM",
            staged: .modified, worktree: .modified,
            isUntracked: false
        )
        XCTAssertEqual(entry.primaryBadge, "modified")
    }

    func testPrimaryBadgeStagedWhenWorktreeClean() {
        let entry = GitStatusEntry(
            path: "bar.swift", xy: "M ",
            staged: .modified, worktree: .unmodified,
            isUntracked: false
        )
        XCTAssertEqual(entry.primaryBadge, "modified")
    }

    func testPrimaryBadgeUntracked() {
        let entry = GitStatusEntry(
            path: "new.swift", xy: "??",
            staged: .unmodified, worktree: .untracked,
            isUntracked: true
        )
        XCTAssertEqual(entry.primaryBadge, "untracked")
    }

    func testPrimaryBadgeEmptyWhenClean() {
        let entry = GitStatusEntry(
            path: "clean.swift", xy: "  ",
            staged: .unmodified, worktree: .unmodified,
            isUntracked: false
        )
        XCTAssertEqual(entry.primaryBadge, "")
    }

    func testParserRenameConsumesOldPath() {
        // "R  new.swift\0old.swift\0M  other.swift\0"
        let raw = "R  new.swift\u{0}old.swift\u{0}M  other.swift\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].path, "new.swift")
        XCTAssertEqual(entries[0].staged, .renamed)
        XCTAssertEqual(entries[1].path, "other.swift")
        XCTAssertEqual(entries[1].staged, .modified)
        XCTAssertEqual(entries[1].worktree, .unmodified)
    }

    func testParserCopyConsumesOldPath() {
        let raw = "C  copied.swift\u{0}orig.swift\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "copied.swift")
        XCTAssertEqual(entries[0].staged, .copied)
    }

    func testParserAllUntracked() {
        let raw = "?? a.txt\u{0}?? b.txt\u{0}?? c.txt\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries.allSatisfy { $0.isUntracked })
    }
}
