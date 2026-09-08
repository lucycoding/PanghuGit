import XCTest
@testable import PanghuGit

final class BranchQueryParsingTests: XCTestCase {

    func testParseLocalBranch() {
        let line = "*:refs/heads/main:main"
        let parts = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(String(parts[0]), "*")
        XCTAssertEqual(String(parts[1]), "refs/heads/main")
        XCTAssertEqual(String(parts[2]), "main")
        let isHEAD = String(parts[0]).contains("*")
        let isRemote = String(parts[1]).hasPrefix("refs/remotes/")
        XCTAssertTrue(isHEAD)
        XCTAssertFalse(isRemote)
    }

    func testParseRemoteBranch() {
        let line = " :refs/remotes/origin/main:origin/main"
        let parts = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        XCTAssertEqual(parts.count, 3)
        let isHEAD = String(parts[0]).contains("*")
        let isRemote = String(parts[1]).hasPrefix("refs/remotes/")
        XCTAssertFalse(isHEAD)
        XCTAssertTrue(isRemote)
    }

    func testParseNonBranchRef() {
        let line = " :refs/heads/:"
        let parts = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { XCTFail("Expected 3 parts"); return }
        let shortRef = String(parts[2])
        XCTAssertTrue(shortRef.isEmpty)
    }

    func testBranchStructEquality() {
        let b1 = BranchQuery.Branch(name: "main", isRemote: false, isHEAD: true)
        let b2 = BranchQuery.Branch(name: "main", isRemote: false, isHEAD: true)
        XCTAssertEqual(b1, b2)
    }

    func testBranchStructInequality() {
        let b1 = BranchQuery.Branch(name: "main", isRemote: false, isHEAD: true)
        let b2 = BranchQuery.Branch(name: "dev", isRemote: false, isHEAD: false)
        XCTAssertNotEqual(b1, b2)
    }

    // MARK: - localTrackingName（远程分支 → 本地跟踪分支名）

    func testLocalTrackingNameForRemoteBranch() {
        XCTAssertEqual(BranchQuery.Branch.localTrackingName(forRemote: "origin/feature-x"), "feature-x")
        XCTAssertEqual(BranchQuery.Branch.localTrackingName(forRemote: "upstream/main"), "main")
    }

    func testLocalTrackingNameKeepsNestedSlashes() {
        // "origin/feature/sub" → 本地分支名 "feature/sub"
        XCTAssertEqual(BranchQuery.Branch.localTrackingName(forRemote: "origin/feature/sub"), "feature/sub")
    }

    func testLocalTrackingNameRejectsOriginHEAD() {
        XCTAssertNil(BranchQuery.Branch.localTrackingName(forRemote: "origin/HEAD"))
    }

    func testLocalTrackingNameInstanceProperty() {
        let remote = BranchQuery.Branch(name: "origin/feature-x", isRemote: true, isHEAD: false)
        XCTAssertEqual(remote.localTrackingName, "feature-x")
        let local = BranchQuery.Branch(name: "origin/feature-x", isRemote: false, isHEAD: false)
        XCTAssertNil(local.localTrackingName)
    }
}
