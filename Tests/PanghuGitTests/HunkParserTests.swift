import XCTest
@testable import PanghuGit

final class HunkParserTests: XCTestCase {

    func testSingleFileSingleHunk() {
        let diff = """
diff --git a/foo.txt b/foo.txt
--- a/foo.txt
+++ b/foo.txt
@@ -1,3 +1,4 @@
 line1
+added
 line2
 line3
"""
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].filePath, "foo.txt")
        XCTAssertEqual(groups[0].hunks.count, 1)
        XCTAssertEqual(groups[0].hunks[0].header, "@@ -1,3 +1,4 @@")
        XCTAssertEqual(groups[0].hunks[0].lines.count, 4)
    }

    func testSingleFileMultipleHunks() {
        let diff = """
diff --git a/bar.txt b/bar.txt
--- a/bar.txt
+++ b/bar.txt
@@ -1,3 +1,3 @@
 line1
-modified
+changed
 line3
@@ -10,3 +10,4 @@
 line10
+added10
 line11
 line12
"""
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].hunks.count, 2)
        XCTAssertEqual(groups[0].hunks[0].lines.count, 4)
        XCTAssertEqual(groups[0].hunks[1].lines.count, 4)
    }

    func testMultipleFiles() {
        let diff = """
diff --git a/a.txt b/a.txt
--- a/a.txt
+++ b/a.txt
@@ -1 +1 @@
-old
+new
diff --git a/b.txt b/b.txt
--- a/b.txt
+++ b/b.txt
@@ -1 +1 @@
-x
+y
"""
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].filePath, "a.txt")
        XCTAssertEqual(groups[1].filePath, "b.txt")
        XCTAssertEqual(groups[0].hunks.count, 1)
        XCTAssertEqual(groups[1].hunks.count, 1)
    }

    func testEmptyDiff() {
        let groups = HunkParser.parse("")
        XCTAssertEqual(groups.count, 0)
    }

    func testBuildPatch() {
        let hunk = DiffHunk(id: 0, header: "@@ -1 +1 @@", lines: ["-old", "+new"], startIndex: 0)
        let header = "diff --git a/test.txt b/test.txt\n--- a/test.txt\n+++ b/test.txt"
        let patch = HunkParser.buildPatch(header: header, hunk: hunk)
        XCTAssertTrue(patch.hasPrefix("diff --git a/test.txt b/test.txt"))
        XCTAssertTrue(patch.contains("--- a/test.txt"))
        XCTAssertTrue(patch.contains("+++ b/test.txt"))
        XCTAssertTrue(patch.contains("@@ -1 +1 @@"))
        XCTAssertTrue(patch.contains("-old"))
        XCTAssertTrue(patch.contains("+new"))
    }

    func testBuildPatchHeader() {
        let header = HunkParser.buildPatchHeader(for: "src/main.swift")
        XCTAssertEqual(header, "diff --git a/src/main.swift b/src/main.swift\n--- a/src/main.swift\n+++ b/src/main.swift")
    }
}
