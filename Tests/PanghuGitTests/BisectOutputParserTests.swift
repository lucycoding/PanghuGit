import XCTest
@testable import PanghuGit

final class BisectOutputParserTests: XCTestCase {

    func testParseFound() {
        let output = "abc1234def5678 is the first bad commit\ncommit abc1234def5678\nAuthor: Test"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.phase, .found)
        XCTAssertEqual(result.foundCommit, "abc1234def5678")
    }

    func testParseFoundWithLongSHA() {
        let output = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0 is the first bad commit"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.phase, .found)
        XCTAssertEqual(result.foundCommit, "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0")
    }

    func testParseProgress() {
        let output = "Bisecting: 4 revisions left to test after this (roughly 2 steps)\n[abc1234def5678a9b0c1d2e3f4a5b6c7d8e9f0a1] some commit message"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.phase, .bisecting)
        XCTAssertEqual(result.remainingSteps, 4)
        XCTAssertEqual(result.currentCommit, "abc1234def5678a9b0c1d2e3f4a5b6c7d8e9f0a1")
    }

    func testParseProgressOneRevision() {
        let output = "Bisecting: 1 revision left to test after this (roughly 1 step)\n[deadbeef] test"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.phase, .bisecting)
        XCTAssertEqual(result.remainingSteps, 1)
    }

    func testParseProgressZeroRevisions() {
        let output = "Bisecting: 0 revisions left to test after this (roughly 0 steps)\n[cafe1234] test"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.phase, .bisecting)
        XCTAssertEqual(result.remainingSteps, 0)
    }

    func testParseEmptyOutput() {
        let result = BisectOutputParser.parse("")
        XCTAssertEqual(result.phase, .bisecting)
        XCTAssertEqual(result.foundCommit, "")
        XCTAssertEqual(result.currentCommit, "")
    }

    func testParseFoundSHAExtraction() {
        let output = "f00bar is the first bad commit\ncommit f00bar"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.foundCommit, "f00bar")
    }

    func testParseMalformedBracketLine() {
        let output = "Bisecting: 2 revisions left\nno brackets here"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.phase, .bisecting)
        XCTAssertEqual(result.currentCommit, "")
    }

    func testParseOnlyBracketCommit() {
        let output = "[abc123] some message"
        let result = BisectOutputParser.parse(output)
        XCTAssertEqual(result.currentCommit, "abc123")
    }
}
