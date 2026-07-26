import AppKit
import SwiftUI

class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
enum HostWindow {
    private static var registry: [String: NSWindowController] = [:]

    static func close(id: String) {
        guard let existing = registry[id] else { return }
        existing.window?.close()
    }

    static func show(id: String, title: String, size: NSSize = NSSize(width: 960, height: 600), @ViewBuilder content: () -> some View) {
        let view = AnyView(content())
        if let existing = registry[id] {
            existing.window?.title = title
            existing.window?.contentViewController = NSHostingController(rootView: view)
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let window = KeyWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        registry[id] = controller

        _ = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                     object: window,
                                                     queue: .main) { [weak window] _ in
            guard let window else { return }
            MainActor.assumeIsolated {
                registry.filter { $0.value.window === window }.keys.forEach { key in
                    registry.removeValue(forKey: key)
                }
            }
        }
    }
}