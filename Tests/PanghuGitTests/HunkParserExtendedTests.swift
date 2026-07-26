import XCTest
@testable import PanghuGit

final class HunkParserExtendedTests: XCTestCase {

    // MARK: - extractPath edge cases

    func testExtractPathWithSpaces() {
        let diff = """
        diff --git "a/path with spaces.txt" "b/path with spaces.txt"
        --- a/path with spaces.txt
        +++ b/path with spaces.txt
        @@ -1 +1 @@
        -old
        +new
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].filePath, "path with spaces.txt")
    }

    func testExtractPathNormal() {
        let diff = """
        diff --git a/src/main.swift b/src/main.swift
        --- a/src/main.swift
        +++ b/src/main.swift
        @@ -1 +1 @@
        -old
        +new
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].filePath, "src/main.swift")
    }

    func testExtractPathDeepNested() {
        let diff = """
        diff --git a/a/b/c/d/file.txt b/a/b/c/d/file.txt
        --- a/a/b/c/d/file.txt
        +++ b/a/b/c/d/file.txt
        @@ -1 +1 @@
        -old
        +new
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].filePath, "a/b/c/d/file.txt")
    }

    // MARK: - Binary diff handling

    func testBinaryDiffSkipped() {
        let diff = """
        diff --git a/image.png b/image.png
        Binary files differ
        diff --git a/text.txt b/text.txt
        --- a/text.txt
        +++ b/text.txt
        @@ -1 +1 @@
        -old
        +new
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].filePath, "image.png")
        XCTAssertEqual(groups[0].hunks.count, 0, "Binary files should have no hunks")
        XCTAssertEqual(groups[1].filePath, "text.txt")
        XCTAssertEqual(groups[1].hunks.count, 1)
    }

    // MARK: - Rename diff

    func testRenameDiff() {
        let diff = """
        diff --git a/old.txt b/new.txt
        --- a/old.txt
        +++ b/new.txt
        @@ -1 +1 @@
        -old content
        +new content
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].filePath, "old.txt")
        XCTAssertEqual(groups[0].hunks.count, 1)
    }

    // MARK: - buildPatch with header

    func testBuildPatchWithHeader() {
        let hunk = DiffHunk(id: 0, header: "@@ -1,3 +1,4 @@", lines: [" line1", "+added", " line2", " line3"], startIndex: 0)
        let header = "diff --git a/foo.txt b/foo.txt\n--- a/foo.txt\n+++ b/foo.txt"
        let patch = HunkParser.buildPatch(header: header, hunk: hunk)
        XCTAssertTrue(patch.contains("diff --git a/foo.txt b/foo.txt"))
        XCTAssertTrue(patch.contains("--- a/foo.txt"))
        XCTAssertTrue(patch.contains("+++ b/foo.txt"))
        XCTAssertTrue(patch.contains("@@ -1,3 +1,4 @@"))
        XCTAssertTrue(patch.contains("+added"))
    }

    func testBuildPatchWithRenameHeader() {
        let hunk = DiffHunk(id: 0, header: "@@ -1 +1 @@", lines: ["-old", "+new"], startIndex: 0)
        let header = "diff --git a/old.txt b/new.txt\n--- a/old.txt\n+++ b/new.txt"
        let patch = HunkParser.buildPatch(header: header, hunk: hunk)
        XCTAssertTrue(patch.contains("--- a/old.txt"))
        XCTAssertTrue(patch.contains("+++ b/new.txt"))
    }

    // MARK: - Multiple hunks across multiple files

    func testMultipleFilesMultipleHunks() {
        let diff = """
        diff --git a/file1.txt b/file1.txt
        --- a/file1.txt
        +++ b/file1.txt
        @@ -1,3 +1,3 @@
         a
        -b
        +B
         c
        @@ -10,3 +10,3 @@
         x
        -y
        +Y
         z
        diff --git a/file2.txt b/file2.txt
        --- a/file2.txt
        +++ b/file2.txt
        @@ -1 +1 @@
        -old
        +new
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].filePath, "file1.txt")
        XCTAssertEqual(groups[0].hunks.count, 2)
        XCTAssertEqual(groups[1].filePath, "file2.txt")
        XCTAssertEqual(groups[1].hunks.count, 1)
    }

    // MARK: - IDs are sequential

    func testGroupIdsAreSequential() {
        let diff = """
        diff --git a/a.txt b/a.txt
        --- a/a.txt
        +++ b/a.txt
        @@ -1 +1 @@
        -x
        +y
        diff --git a/b.txt b/b.txt
        --- b/b.txt
        +++ b/b.txt
        @@ -1 +1 @@
        -x
        +y
        diff --git a/c.txt b/c.txt
        --- a/c.txt
        +++ b/c.txt
        @@ -1 +1 @@
        -x
        +y
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.map(\.id), [0, 1, 2])
    }

    func testHunkIdsAreSequentialWithinFile() {
        let diff = """
        diff --git a/foo.txt b/foo.txt
        --- a/foo.txt
        +++ b/foo.txt
        @@ -1,3 +1,3 @@
         a
        -b
        +B
         c
        @@ -10,3 +10,3 @@
         x
        -y
        +Y
         z
        @@ -20,3 +20,3 @@
         p
        -q
        +Q
         r
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups[0].hunks.map(\.id), [0, 1, 2])
    }

    // MARK: - No-newline-at-end marker

    func testNoNewlineAtEnd() {
        let diff = """
        diff --git a/file.txt b/file.txt
        --- a/file.txt
        +++ b/file.txt
        @@ -1 +1 @@
        -old
        \\ No newline at end of file
        +new
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].hunks.count, 1)
        XCTAssertTrue(groups[0].hunks[0].lines.contains("\\ No newline at end of file"))
    }

    // MARK: - Empty hunk lines

    func testEmptyHunkLines() {
        let diff = """
        diff --git a/empty.txt b/empty.txt
        --- a/empty.txt
        +++ b/empty.txt
        @@ -0,0 +1 @@
        +first line
        """
        let groups = HunkParser.parse(diff)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].hunks.count, 1)
        XCTAssertEqual(groups[0].hunks[0].lines.count, 1)
    }
}
