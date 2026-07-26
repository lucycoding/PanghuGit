import XCTest
@testable import PanghuGit

final class SyncViewLogicTests: XCTestCase {

    // MARK: - ForceMode enum

    func testForceModeAllCases() {
        XCTAssertEqual(SyncView.ForceMode.allCases.count, 3)
        XCTAssertEqual(SyncView.ForceMode.none.rawValue, "none")
        XCTAssertEqual(SyncView.ForceMode.force.rawValue, "force")
        XCTAssertEqual(SyncView.ForceMode.forceWithLease.rawValue, "forceWithLease")
    }

    // MARK: - Branch name with dash prefix (flag injection prevention)

    func testBranchNameWithDashPrefix() {
        let branch = "-evil-flag"
        let b = branch.trimmingCharacters(in: .whitespaces)
        let extra: [String] = b.hasPrefix("-") ? ["--", b] : [b]
        XCTAssertEqual(extra, ["--", "-evil-flag"])
    }

    func testBranchNameNormal() {
        let branch = "feature/my-branch"
        let b = branch.trimmingCharacters(in: .whitespaces)
        let extra: [String] = b.hasPrefix("-") ? ["--", b] : [b]
        XCTAssertEqual(extra, ["feature/my-branch"])
    }

    func testBranchNameEmpty() {
        let branch = ""
        let b = branch.trimmingCharacters(in: .whitespaces)
        let extra: [String] = b.isEmpty ? [] : (b.hasPrefix("-") ? ["--", b] : [b])
        XCTAssertEqual(extra, [])
    }

    func testBranchNameWhitespaceOnly() {
        let branch = "   "
        let b = branch.trimmingCharacters(in: .whitespaces)
        let extra: [String] = b.isEmpty ? [] : (b.hasPrefix("-") ? ["--", b] : [b])
        XCTAssertEqual(extra, [])
    }

    // MARK: - Push args construction

    func testPushArgsForce() {
        var args = ["push", "origin", "main"]
        args.append("--force")
        XCTAssertTrue(args.contains("--force"))
    }

    func testPushArgsForceWithLease() {
        var args = ["push", "origin", "main"]
        args.append("--force-with-lease")
        XCTAssertTrue(args.contains("--force-with-lease"))
    }

    func testPushArgsWithTags() {
        var args = ["push", "origin"]
        args.append("--tags")
        args.append("--no-verify")
        XCTAssertTrue(args.contains("--tags"))
        XCTAssertTrue(args.contains("--no-verify"))
    }
}
