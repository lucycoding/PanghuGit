import XCTest
@testable import PanghuGit

final class GitStatusParserTests: XCTestCase {

    func testSimpleModified() {
        let raw = " M file1.swift\u{0}?? newfile.swift\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].path, "file1.swift")
        XCTAssertEqual(entries[0].staged, .unmodified)
        XCTAssertEqual(entries[0].worktree, .modified)
        XCTAssertEqual(entries[1].path, "newfile.swift")
        XCTAssertTrue(entries[1].isUntracked)
    }

    func testStagedFile() {
        let raw = "M  staged.swift\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "staged.swift")
        XCTAssertEqual(entries[0].staged, .modified)
        XCTAssertEqual(entries[0].worktree, .unmodified)
    }

    func testRename() {
        // git status --porcelain=v1 -z rename format: "R  NEW_PATH\0OLD_PATH\0"
        let raw = "R  new.swift\u{0}old.swift\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "new.swift")
        XCTAssertEqual(entries[0].staged, .renamed)
    }

    func testConflict() {
        let raw = "UU conflicting.swift\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(MergeQuery.isConflictXY(entries[0].xy))
    }

    func testIgnored() {
        let raw = "!! build/\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].worktree, .ignored)
    }

    func testEmpty() {
        let entries = GitStatusParser().parse("")
        XCTAssertTrue(entries.isEmpty)
    }

    func testBranchHeader() {
        let raw = "# branch.main\u{0} M file.swift\u{0}"
        let entries = GitStatusParser().parse(raw)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].path, "file.swift")
    }
}