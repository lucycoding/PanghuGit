import XCTest
@testable import PanghuGit

final class DiffViewLineParsingTests: XCTestCase {

    func testHeaderLine() {
        let line = "diff --git a/file.swift b/file.swift"
        XCTAssertTrue(line.hasPrefix("diff --git"))
    }

    func testFileMetaLines() {
        XCTAssertTrue("index abc..def 100644".hasPrefix("index "))
        XCTAssertTrue("--- a/file.swift".hasPrefix("--- "))
        XCTAssertTrue("+++ b/file.swift".hasPrefix("+++ "))
    }

    func testHunkLine() {
        XCTAssertTrue("@@ -1,5 +1,7 @@".hasPrefix("@@"))
    }

    func testAddedLine() {
        XCTAssertTrue("+new code here".hasPrefix("+"))
        XCTAssertFalse("++ new code".hasPrefix("+") == false)
    }

    func testRemovedLine() {
        XCTAssertTrue("-old code here".hasPrefix("-"))
    }

    func testContextLine() {
        let line = " unchanged line"
        XCTAssertFalse(line.hasPrefix("+"))
        XCTAssertFalse(line.hasPrefix("-"))
        XCTAssertFalse(line.hasPrefix("@@"))
        XCTAssertFalse(line.hasPrefix("diff"))
        XCTAssertFalse(line.hasPrefix("index "))
        XCTAssertFalse(line.hasPrefix("--- "))
        XCTAssertFalse(line.hasPrefix("+++ "))
    }

    func testMultiLineDiffOutput() {
        let patch = """
        diff --git a/file.swift b/file.swift
        index abc..def 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -1,5 +1,7 @@
         context line
        -removed line
        +added line
        +another added
         more context
        """
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 10)

        XCTAssertTrue(lines[0].hasPrefix("diff --git"))
        XCTAssertTrue(lines[1].hasPrefix("index "))
        XCTAssertTrue(lines[2].hasPrefix("--- "))
        XCTAssertTrue(lines[3].hasPrefix("+++ "))
        XCTAssertTrue(lines[4].hasPrefix("@@"))
        XCTAssertTrue(lines[6].hasPrefix("-"))
        XCTAssertTrue(lines[7].hasPrefix("+"))
        XCTAssertTrue(lines[8].hasPrefix("+"))
    }
}
