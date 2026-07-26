import Cocoa
import FinderSync
import os.log

/// 在 Finder Sync 扩展内异步计算目录的 Git 状态并设置角标。
///
/// 策略：
/// - 进入目录（beginObservingDirectory）时，在后台执行 `git status --porcelain=v1 -z`，
///   把每个条目映射为 badge identifier 并 `setBadge`。
/// - requestBadgeIdentifier 使用缓存快照；缓存键为文件 URL。
final class BadgeWatcher {
    private let parser = GitStatusParser()
    private let cacheLock = NSLock()
    private var cache: [URL: String] = [:]
    private let queue = DispatchQueue(label: "com.lucy.panghugit.badge", qos: .utility)
    private let dirsLock = NSLock()
    private var observedDirs: Set<URL> = []
    private var timer: DispatchSourceTimer?
    private let log = OSLog(subsystem: "com.lucy.panghugit.finder-sync", category: "BadgeWatcher")

    static let badgeRefreshNotification = Notification.Name("com.lucy.panghugit.refreshBadges")

    func startListeningForRefreshRequests() {
        DistributedNotificationCenter.default().addObserver(
            forName: Self.badgeRefreshNotification, object: nil, queue: OperationQueue()) { [weak self] _ in
            self?.queue.async { self?.refreshAll() }
        }
    }

    private func refreshAll() {
        dirsLock.lock()
        let dirs = self.observedDirs
        dirsLock.unlock()
        for dir in dirs {
            self.refresh(at: dir)
        }
    }

    func badge(for url: URL) -> String? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        return cache[url]
    }

    func refresh(at dir: URL) {
        queue.async { [self] in
            if Self.isSandboxed {
                return
            }
            let runner = GitRunner.configuredWithTimeout(15)
            let probe = try? runner.run(["rev-parse", "--is-inside-work-tree"], in: dir)
            guard let probe, probe.isSuccess, probe.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
                let reason = probe?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? "no-git"
                os_log("refresh skip (not a repo): %{public}@", log: self.log, type: .debug, reason)
                return
            }
            let result = try? runner.run(["status", "--porcelain=v1", "-z"], in: dir)
            guard let result, result.isSuccess else { return }

            let entries = self.parser.parse(result.stdout)
            let ctrl = FIFinderSyncController.default()

            var localCache: [URL: String] = [:]
            for e in entries {
                let fileURL = dir.appendingPathComponent(e.path)
                localCache[fileURL] = e.primaryBadge
            }
            cacheLock.lock()
            for (url, id) in localCache {
                self.cache[url] = id
            }
            let removed = self.cache.keys.filter { k in
                k.deletingLastPathComponent() == dir && !localCache.keys.contains(k)
            }
            for k in removed { self.cache.removeValue(forKey: k) }
            cacheLock.unlock()

            DispatchQueue.main.async {
                for (url, id) in localCache {
                    if id.isEmpty {
                        ctrl.setBadgeIdentifier("", for: url)
                    } else {
                        ctrl.setBadgeIdentifier(id, for: url)
                    }
                }
            }
        }
    }

    private static var isSandboxed: Bool {
        FileManager.default.homeDirectoryForCurrentUser.path.contains("/Containers/")
    }

    /// 开始定时刷新：按 SettingsStore.refreshInterval 间隔刷新所有观察中的目录。
    func startTimer() {
        let interval = SettingsStore.shared.refreshInterval
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [self] in
            self.dirsLock.lock()
            let dirs = self.observedDirs
            self.dirsLock.unlock()
            for dir in dirs {
                self.refresh(at: dir)
            }
        }
        t.resume()
        timer = t
    }

    func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    func startObserving(_ dir: URL) {
        dirsLock.lock(); defer { dirsLock.unlock() }
        observedDirs.insert(dir)
        if timer == nil { startTimer() }
    }

    func stopObserving(_ dir: URL) {
        dirsLock.lock(); defer { dirsLock.unlock() }
        observedDirs.remove(dir)
        if observedDirs.isEmpty { stopTimer() }
    }

    func clear(at dir: URL) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache.removeValue(forKey: dir)
        stopObserving(dir)
    }
}