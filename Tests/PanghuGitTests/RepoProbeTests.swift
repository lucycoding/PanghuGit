import XCTest
@testable import PanghuGit

final class RepoProbeTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RepoProbeTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    func testRootReturnsNilForNonGitDirectory() {
        let nonGitDir = tempDir.appendingPathComponent("notarepo")
        try? FileManager.default.createDirectory(at: nonGitDir, withIntermediateDirectories: true)
        let result = RepoProbe.root(at: nonGitDir)
        XCTAssertNil(result)
    }

    func testRootReturnsNilForNonExistentPath() {
        let nonexistent = tempDir.appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        let result = RepoProbe.root(at: nonexistent)
        XCTAssertNil(result)
    }

    func testRootReturnsCorrectRootForGitRepo() {
        let repoDir = tempDir.appendingPathComponent("myrepo")
        try? FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = repoDir
        try? process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0, "git init failed")

        let result = RepoProbe.root(at: repoDir)
        XCTAssertNotNil(result, "RepoProbe.root should return non-nil for a git repo")
        if let root = result {
            let standardizedRepo = repoDir.standardizedFileURL.path
            let standardizedRoot = root.standardizedFileURL.path
            XCTAssertEqual(standardizedRoot, standardizedRepo, "root should match the repo directory")
        }
    }

    func testRootFindsRepoFromSubdirectory() {
        let repoDir = tempDir.appendingPathComponent("myrepo2")
        let subDir = repoDir.appendingPathComponent("src/deep/nested")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = repoDir
        try? process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0, "git init failed")

        let result = RepoProbe.root(at: subDir)
        XCTAssertNotNil(result, "RepoProbe.root should find repo root from subdirectory")
        if let root = result {
            let standardizedRepo = repoDir.standardizedFileURL.path
            let standardizedRoot = root.standardizedFileURL.path
            XCTAssertEqual(standardizedRoot, standardizedRepo)
        }
    }
}
