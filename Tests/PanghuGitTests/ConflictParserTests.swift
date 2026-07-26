import XCTest
@testable import PanghuGit

final class ConflictParserTests: XCTestCase {

    func testParseSimpleConflict() {
        let content = """
line before
<<<<<<< HEAD
ours line 1
ours line 2
=======
theirs line 1
>>>>>>> branch
line after
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        XCTAssertFalse(file.isBinary)
        XCTAssertEqual(file.blocks.count, 1)

        let block = file.blocks[0]
        XCTAssertEqual(block.markerLine, 1)
        XCTAssertEqual(block.oursContent, "ours line 1\nours line 2")
        XCTAssertEqual(block.theirsContent, "theirs line 1")
        XCTAssertNil(block.baseContent)
        XCTAssertEqual(block.separatorLine, 4)
        XCTAssertEqual(block.endLine, 6)
    }

    func testParseDiff3Conflict() {
        let content = """
<<<<<<< HEAD
ours content
|||||| base
base content
=======
theirs content
>>>>>>> branch
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        XCTAssertEqual(file.blocks.count, 1)

        let block = file.blocks[0]
        XCTAssertEqual(block.oursContent, "ours content")
        XCTAssertEqual(block.baseContent, "base content")
        XCTAssertEqual(block.theirsContent, "theirs content")
    }

    func testParseMultipleConflicts() {
        let content = """
first
<<<<<<< HEAD
A
=======
B
>>>>>>> branch
middle
<<<<<<< HEAD
C
=======
D
>>>>>>> branch
last
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        XCTAssertEqual(file.blocks.count, 2)
        XCTAssertEqual(file.blocks[0].oursContent, "A")
        XCTAssertEqual(file.blocks[1].oursContent, "C")
    }

    func testParseBinaryFile() {
        let content = "hello\0world"
        let file = ConflictParser.parse(content: content, path: "image.png")
        XCTAssertTrue(file.isBinary)
        XCTAssertTrue(file.blocks.isEmpty)
    }

    func testResolveContentSingleBlock() {
        let content = """
before
<<<<<<< HEAD
ours
=======
theirs
>>>>>>> branch
after
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        let resolved = [file.blocks[0].id: "resolved content"]
        let result = ConflictParser.resolveContent(rawContent: content, blocks: file.blocks, resolved: resolved)
        XCTAssertEqual(result, "before\nresolved content\nafter")
    }

    func testResolveContentMultipleBlocksReverseOrder() {
        let content = """
<<<<<<< HEAD
A1
=======
B1
>>>>>>> branch
mid
<<<<<<< HEAD
A2
=======
B2
>>>>>>> branch
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        XCTAssertEqual(file.blocks.count, 2)
        let resolved = [
            file.blocks[0].id: "R1",
            file.blocks[1].id: "R2"
        ]
        let result = ConflictParser.resolveContent(rawContent: content, blocks: file.blocks, resolved: resolved)
        XCTAssertEqual(result, "R1\nmid\nR2")
    }

    func testResolveContentPartialResolution() {
        let content = """
<<<<<<< HEAD
A
=======
B
>>>>>>> branch
mid
<<<<<<< HEAD
C
=======
D
>>>>>>> branch
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        let resolved = [file.blocks[0].id: "R1"]
        let result = ConflictParser.resolveContent(rawContent: content, blocks: file.blocks, resolved: resolved)
        XCTAssertTrue(result.contains("R1"))
        XCTAssertTrue(result.contains("<<<<<<< HEAD"))
        XCTAssertTrue(result.contains("C"))
    }

    func testHasResidualConflictMarkers() {
        XCTAssertTrue(ConflictParser.hasResidualConflictMarkers("some <<<<<<< HEAD"))
        XCTAssertTrue(ConflictParser.hasResidualConflictMarkers("some >>>>>>> branch"))
        XCTAssertFalse(ConflictParser.hasResidualConflictMarkers("clean content"))
    }

    func testEmptyContent() {
        let file = ConflictParser.parse(content: "", path: "empty.txt")
        XCTAssertFalse(file.isBinary)
        XCTAssertTrue(file.blocks.isEmpty)
    }

    func testNoConflictMarkers() {
        let content = "just normal text\nno conflicts here"
        let file = ConflictParser.parse(content: content, path: "clean.txt")
        XCTAssertFalse(file.isBinary)
        XCTAssertTrue(file.blocks.isEmpty)
    }

    func testParseBlockIdFormat() {
        let content = """
<<<<<<< HEAD
x
=======
y
>>>>>>> branch
"""
        let file = ConflictParser.parse(content: content, path: "dir/file.txt")
        XCTAssertEqual(file.blocks[0].id, "dir/file.txt:0")
    }

    func testMalformedConflictMissingEndMarker() {
        let content = """
before
<<<<<<< HEAD
ours
=======
theirs
after without end marker
more text
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        XCTAssertEqual(file.blocks.count, 0, "Malformed block without >>>>>>> causes parser to break out")
    }

    func testMalformedConflictWithEndMarkerButNoSep() {
        let content = """
before
<<<<<<< HEAD
ours
>>>>>>> branch
after
"""
        let file = ConflictParser.parse(content: content, path: "test.txt")
        XCTAssertEqual(file.blocks.count, 0, "Malformed block without ======= causes parser to break out")
    }
}
