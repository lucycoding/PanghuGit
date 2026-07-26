import XCTest
@testable import PanghuGit

final class CommitFileStatusTests: XCTestCase {

    func testInitFromRawSingleLetter() {
        XCTAssertEqual(CommitFileStatus(raw: "A"), .added)
        XCTAssertEqual(CommitFileStatus(raw: "M"), .modified)
        XCTAssertEqual(CommitFileStatus(raw: "D"), .deleted)
        XCTAssertEqual(CommitFileStatus(raw: "R"), .renamed)
        XCTAssertEqual(CommitFileStatus(raw: "C"), .copied)
        XCTAssertEqual(CommitFileStatus(raw: "T"), .typeChange)
    }

    func testInitFromRawWithRenameScore() {
        XCTAssertEqual(CommitFileStatus(raw: "R100"), .renamed)
        XCTAssertEqual(CommitFileStatus(raw: "C090"), .copied)
    }

    func testInitFromRawUnknown() {
        XCTAssertEqual(CommitFileStatus(raw: "X"), .unknown)
        XCTAssertEqual(CommitFileStatus(raw: ""), .unknown)
        XCTAssertEqual(CommitFileStatus(raw: "???"), .unknown)
    }

    func testIconMapping() {
        XCTAssertEqual(CommitFileStatus.added.icon, "✔")
        XCTAssertEqual(CommitFileStatus.modified.icon, "!")
        XCTAssertEqual(CommitFileStatus.deleted.icon, "×")
        XCTAssertEqual(CommitFileStatus.renamed.icon, "→")
        XCTAssertEqual(CommitFileStatus.copied.icon, "✔")
        XCTAssertEqual(CommitFileStatus.typeChange.icon, "!")
        XCTAssertEqual(CommitFileStatus.unknown.icon, "?")
    }

    func testRawValueRoundTrip() {
        XCTAssertEqual(CommitFileStatus.added.rawValue, "A")
        XCTAssertEqual(CommitFileStatus.modified.rawValue, "M")
        XCTAssertEqual(CommitFileStatus.deleted.rawValue, "D")
        XCTAssertEqual(CommitFileStatus.renamed.rawValue, "R")
        XCTAssertEqual(CommitFileStatus.copied.rawValue, "C")
        XCTAssertEqual(CommitFileStatus.typeChange.rawValue, "T")
    }
}
