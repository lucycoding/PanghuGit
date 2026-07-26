import XCTest
@testable import PanghuGit

final class SettingsStoreTests: XCTestCase {

    func testMenuStyleRawValues() {
        XCTAssertEqual(SettingsStore.MenuStyle.flat.rawValue, "flat")
        XCTAssertEqual(SettingsStore.MenuStyle.submenu.rawValue, "submenu")
    }

    func testMenuStyleAllCases() {
        XCTAssertEqual(SettingsStore.MenuStyle.allCases.count, 2)
    }

    func testLanguageRawValues() {
        XCTAssertEqual(SettingsStore.Language.followSystem.rawValue, "")
        XCTAssertEqual(SettingsStore.Language.zh.rawValue, "zh-Hans")
        XCTAssertEqual(SettingsStore.Language.en.rawValue, "en")
    }

    func testLanguageAllCases() {
        XCTAssertEqual(SettingsStore.Language.allCases.count, 3)
    }

    func testDefaultConventionalTypes() {
        let types = SettingsStore.defaultConventionalTypes
        XCTAssertEqual(types.count, 11)
        XCTAssertEqual(types[0], "feat")
        XCTAssertEqual(types[1], "fix")
        XCTAssertTrue(types.contains("revert"))
    }

    func testKeyRawValues() {
        XCTAssertEqual(SettingsStore.Key.gitPath.rawValue, "gitPath")
        XCTAssertEqual(SettingsStore.Key.diffTool.rawValue, "diffTool")
        XCTAssertEqual(SettingsStore.Key.menuStyle.rawValue, "menuStyle")
        XCTAssertEqual(SettingsStore.Key.language.rawValue, "language")
    }

    func testTemplateRoundTrip() {
        let templates = ["feat: new feature", "fix: bug fix", "chore: cleanup"]
        guard let data = try? JSONEncoder().encode(templates),
              let s = String(data: data, encoding: .utf8),
              let d = s.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: d) else {
            XCTFail("Template round-trip failed"); return
        }
        XCTAssertEqual(decoded, templates)
    }
}
