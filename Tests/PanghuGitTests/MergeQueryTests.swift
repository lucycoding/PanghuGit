import XCTest
@testable import PanghuGit

final class MergeQueryTests: XCTestCase {

    func testIsConflictXY() {
        XCTAssertTrue(MergeQuery.isConflictXY("UU"))
        XCTAssertTrue(MergeQuery.isConflictXY("DU"))
        XCTAssertTrue(MergeQuery.isConflictXY("UD"))
        XCTAssertTrue(MergeQuery.isConflictXY("DD"))
        XCTAssertTrue(MergeQuery.isConflictXY("AA"))
        XCTAssertTrue(MergeQuery.isConflictXY("AU"))
        XCTAssertTrue(MergeQuery.isConflictXY("UA"))
    }

    func testNonConflictXY() {
        XCTAssertFalse(MergeQuery.isConflictXY(" M"))
        XCTAssertFalse(MergeQuery.isConflictXY("M "))
        XCTAssertFalse(MergeQuery.isConflictXY("A "))
        XCTAssertFalse(MergeQuery.isConflictXY("??" ))
        XCTAssertFalse(MergeQuery.isConflictXY("!!"))
    }
}