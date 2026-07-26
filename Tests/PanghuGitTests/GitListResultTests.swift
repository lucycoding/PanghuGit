import XCTest
@testable import PanghuGit

final class GitListResultTests: XCTestCase {

    func testSuccessValues() {
        let result: GitListResult<Int> = .success([1, 2, 3])
        XCTAssertEqual(result.values, [1, 2, 3])
    }

    func testEmptyValues() {
        let result: GitListResult<Int> = .empty
        XCTAssertEqual(result.values, [])
    }

    func testFailureValues() {
        let result: GitListResult<Int> = .failure("something went wrong")
        XCTAssertEqual(result.values, [])
    }

    func testFailureIsFailure() {
        let result: GitListResult<Int> = .failure("msg")
        XCTAssertTrue(result.isFailure)
    }

    func testSuccessIsNotFailure() {
        let result: GitListResult<Int> = .success([1])
        XCTAssertFalse(result.isFailure)
    }

    func testEmptyIsNotFailure() {
        let result: GitListResult<Int> = .empty
        XCTAssertFalse(result.isFailure)
    }

    func testSuccessWithEmptyArray() {
        let result: GitListResult<String> = .success([])
        XCTAssertEqual(result.values, [])
        XCTAssertFalse(result.isFailure)
    }

    func testSuccessWithStrings() {
        let result: GitListResult<String> = .success(["a", "b"])
        XCTAssertEqual(result.values, ["a", "b"])
    }
}
