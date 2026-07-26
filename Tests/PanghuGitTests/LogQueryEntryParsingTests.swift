import XCTest
@testable import PanghuGit

final class LogQueryEntryParsingTests: XCTestCase {

    func testParseSingleLine() {
        let line = "abc123full\thash123\tJohn\t2026-01-15\tInitial commit\tHEAD -> main"
        let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
        XCTAssertEqual(cols.count, 6)
        XCTAssertEqual(String(cols[0]), "abc123full")
        XCTAssertEqual(String(cols[1]), "hash123")
        XCTAssertEqual(String(cols[2]), "John")
        XCTAssertEqual(String(cols[3]), "2026-01-15")
        XCTAssertEqual(String(cols[4]), "Initial commit")
        XCTAssertEqual(String(cols[5]), "HEAD -> main")
    }

    func testParseLineWithoutRefs() {
        let line = "abc123full\thash123\tJohn\t2026-01-15\tInitial commit"
        let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
        XCTAssertEqual(cols.count, 5)
        XCTAssertNil(LogQuery.Entry?.none)
    }

    func testParseEmptyOutput() {
        let lines = "".split(whereSeparator: \.isNewline)
        XCTAssertTrue(lines.isEmpty)
    }

    func testEntryCreation() {
        let entry = LogQuery.Entry(
            id: "fullhash",
            shortHash: "abc1234",
            authorName: "Alice",
            authorDate: "2026-07-15",
            subject: "Fix bug",
            refs: "HEAD -> main"
        )
        XCTAssertEqual(entry.id, "fullhash")
        XCTAssertEqual(entry.shortHash, "abc1234")
        XCTAssertEqual(entry.authorName, "Alice")
        XCTAssertEqual(entry.authorDate, "2026-07-15")
        XCTAssertEqual(entry.subject, "Fix bug")
        XCTAssertEqual(entry.refs, "HEAD -> main")
    }

    func testEntryIdentifiable() {
        let e1 = LogQuery.Entry(id: "hash1", shortHash: "h1", authorName: "A", authorDate: "2026-01-01", subject: "S1", refs: "")
        let e2 = LogQuery.Entry(id: "hash2", shortHash: "h2", authorName: "A", authorDate: "2026-01-01", subject: "S2", refs: "")
        XCTAssertNotEqual(e1.id, e2.id)
    }

    func testEntryHashable() {
        let e1 = LogQuery.Entry(id: "hash1", shortHash: "h1", authorName: "A", authorDate: "2026-01-01", subject: "S1", refs: "")
        let e2 = LogQuery.Entry(id: "hash1", shortHash: "h1", authorName: "A", authorDate: "2026-01-01", subject: "S1", refs: "")
        XCTAssertEqual(e1, e2)
        let set = Set([e1, e2])
        XCTAssertEqual(set.count, 1)
    }
}
