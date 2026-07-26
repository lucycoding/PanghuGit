import XCTest
@testable import PanghuGit

final class ActionRouterTests: XCTestCase {

    func testAllActionsHandledByRouter() {
        let handledActions: Set<PanghuGitAction> = [
            .initRepo, .clone, .commit, .modifications, .sync, .switch,
            .log, .diff, .branch, .ignore, .stash, .tag, .revert,
            .settings, .merge, .rebase, .blame, .submodule, .repoSettings,
            .openTerminal, .fileLog, .reflog, .patch, .export, .cleanup,
            .bisect, .worktree
        ]
        for action in PanghuGitAction.allCases {
            if !handledActions.contains(action) {
                XCTFail("PanghuGitAction.\(action.rawValue) is not handled by ActionRouter.present")
            }
        }
    }

    func testURLSchemeRoundTripForAllActions() {
        let target = URL(fileURLWithPath: "/tmp/testrepo")
        for action in PanghuGitAction.allCases {
            let inv = PanghuGitInvocation(action: action, target: target, selected: [])
            guard let url = PanghuGitURLScheme.makeURL(for: inv) else {
                XCTFail("makeURL returned nil for action \(action.rawValue)")
                continue
            }
            let parsed = PanghuGitURLScheme.parse(url)
            XCTAssertNotNil(parsed, "parse returned nil for action \(action.rawValue)")
            XCTAssertEqual(parsed?.action, action, "action mismatch for \(action.rawValue)")
            XCTAssertEqual(parsed?.target?.path, target.path, "target mismatch for \(action.rawValue)")
        }
    }

    func testURLSchemeRoundTripWithSelectedPaths() {
        let target = URL(fileURLWithPath: "/tmp/repo")
        let selected = [
            URL(fileURLWithPath: "/tmp/repo/a.swift"),
            URL(fileURLWithPath: "/tmp/repo/b.swift")
        ]
        for action in PanghuGitAction.allCases {
            let inv = PanghuGitInvocation(action: action, target: target, selected: selected)
            guard let url = PanghuGitURLScheme.makeURL(for: inv) else {
                XCTFail("makeURL returned nil for action \(action.rawValue) with selected")
                continue
            }
            let parsed = PanghuGitURLScheme.parse(url)
            XCTAssertEqual(parsed?.selected.count, 2, "selected count mismatch for \(action.rawValue)")
        }
    }

    func testInvalidURLReturnsNil() {
        let url = URL(string: "https://example.com")!
        XCTAssertNil(PanghuGitURLScheme.parse(url))
    }

    func testInvalidSchemeReturnsNil() {
        let url = URL(string: "http://commit?target=/foo")!
        XCTAssertNil(PanghuGitURLScheme.parse(url))
    }

    func testUnknownActionReturnsNil() {
        let url = URL(string: "panghugit://nonexistent?target=/foo")!
        XCTAssertNil(PanghuGitURLScheme.parse(url))
    }

    func testMalformedURLReturnsNil() {
        let url = URL(string: "panghugit://")!
        XCTAssertNil(PanghuGitURLScheme.parse(url))
    }
}
