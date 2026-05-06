import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFile fileName: String) -> Bool {
        NotificationCenter.default.post(name: .audioXOpenFromFinder, object: fileName)
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
