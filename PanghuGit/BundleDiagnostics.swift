import Foundation
import FinderSync
import os.log

/// 主 App 启动时对安装环境做自检并修复常见问题：
///
/// 1. **App Translocation**：从 DMG 直接双击运行而未拖到 /Applications，macOS 会将 App 复制到
///    `/private/var/folders/.../AppTranslocation/<UUID>/PanghuGit.app` 漂浮路径运行，导致扩展
///    所在路径不固定、pluginkit 无法稳定注册、重启后失效 —— 右键菜单将不出现在 Finder 中。
/// 2. **com.apple.quarantine 隔离属性**：从网络下载的 DMG/App 携带 quarantine，ad-hoc 签名 / 未
///    Developer ID 公证的 Finder Sync 扩展会因 Gatekeeper 拒绝加载而无法在右键菜单出现。主 App
///    非 sandbox，可对自身 bundle 执行 `xattr -dr com.apple.quarantine` 做自愈。
/// 3. **扩展未注册到 pluginkit**：极端情况下扩展未成功登记；通过 `pluginkit -m -p` 检测以引导
///    用户去系统设置勾选。
///
/// 检测结果以 `Snapshot` 形式暴露给 UI 引导用户。
enum BundleDiagnostics {

    static let extensionBundleID = "com.lucy.panghugit.finder-sync"

    private static let log = OSLog(subsystem: "com.lucy.panghugit", category: "Diagnostics")

    struct Snapshot: Sendable, Equatable {
        /// 主 App bundle 绝对路径
        let bundlePath: String
        /// 是否在 App Translocation 临时路径下
        let isTranslocated: Bool
        /// 是否在 /Applications 下
        let isInApplications: Bool
        /// 是否成功清掉自身 com.apple.quarantine 属性
        let quarantineStripped: Bool
        /// pluginkit 是否能看到本扩展
        let extensionRegistered: Bool
    }

    /// 在主 App 启动时计算一次快照，同时执行 quarantine 自愈。
    static func snapshot() -> Snapshot {
        let bundlePath = Bundle.main.bundlePath
        let isTranslocated = bundlePath.contains("/AppTranslocation/")
        let isInApplications = bundlePath.hasPrefix("/Applications/")
        let quarantineStripped = stripQuarantine(at: bundlePath)
        let extensionRegistered = checkExtensionRegistered()
        os_log("bundlePath=%{public}@ translocated=%{bool}d inApps=%{bool}d quarantineStripped=%{bool}d extRegistered=%{bool}d",
               log: log, type: .info,
               bundlePath, isTranslocated, isInApplications, quarantineStripped, extensionRegistered)
        return Snapshot(bundlePath: bundlePath,
                        isTranslocated: isTranslocated,
                        isInApplications: isInApplications,
                        quarantineStripped: quarantineStripped,
                        extensionRegistered: extensionRegistered)
    }

    /// 主 App 非 sandbox，可对自身 bundle 执行 `xattr -dr com.apple.quarantine`。
    /// 即便 App 已经在 /Applications 拖入（GitHub Releases / 本机制作的 DMG），此调用无副作用。
    @discardableResult
    static func stripQuarantine(at path: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        p.arguments = ["-dr", "com.apple.quarantine", path]
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            os_log("xattr invocation failed: %{public}@", log: log, type: .error, String(describing: error))
            return false
        }
    }

    /// 通过 `pluginkit -m -p com.apple.FinderSync` 列出已注册的 Finder Sync 扩展，查看本扩展是否在内。
    static func checkExtensionRegistered() -> Bool {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        p.arguments = ["-m", "-p", "com.apple.FinderSync"]
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return false }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            return out.contains(extensionBundleID)
        } catch {
            os_log("pluginkit invocation failed: %{public}@", log: log, type: .error, String(describing: error))
            return false
        }
    }

    /// 重启 Finder，使刚启动的扩展菜单立即生效，避免用户手动 `killall Finder`。
    static func restartFinder() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Finder"]
        try? p.run()
    }

    /// 调用系统标准 UI 引导用户启用 Finder Sync 扩展。
    /// 这是 Apple 官方推荐的方式：弹出系统级对话框，用户确认后直接启用，
    /// 比手动在系统设置中翻找更可靠（尤其 macOS 26 把 Finder Sync 归在"文件提供程序"下）。
    @MainActor
    static func showExtensionManagementInterface() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    /// 清理 PanghuGit Finder Sync 扩展的旧注册残留。
    /// 只移除本扩展（com.lucy.panghugit.finder-sync），不影响 WPS / 百度网盘 / 豆包 等其他 Finder Sync 扩展。
    @discardableResult
    static func cleanupOldExtensions() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        p.arguments = ["-r", "-i", extensionBundleID]
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            os_log("pluginkit cleanup failed: %{public}@", log: log, type: .error, String(describing: error))
            return false
        }
    }

    /// 尝试用 pluginkit 启用本扩展（macOS 26 上仍可能需要用户在系统设置中手动确认）。
    @discardableResult
    static func enableExtension() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        p.arguments = ["-e", "-i", extensionBundleID]
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            os_log("pluginkit enable failed: %{public}@", log: log, type: .error, String(describing: error))
            return false
        }
    }
}