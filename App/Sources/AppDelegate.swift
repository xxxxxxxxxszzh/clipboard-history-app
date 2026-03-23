import AppKit
import Carbon
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var hotKeyMonitor: GlobalHotKeyMonitor?
    private var storeSubscriptions = Set<AnyCancellable>()

    weak var window: NSWindow?
    private weak var store: ClipboardHistoryStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        hotKeyMonitor = GlobalHotKeyMonitor(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.toggleWindowVisibility()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func attach(window: NSWindow, store: ClipboardHistoryStore) {
        self.window = window
        self.store = store
        window.delegate = self
        window.title = "Clipboard History"
        window.tabbingMode = .disallowed
        rebuildMenu()

        storeSubscriptions.removeAll()

        store.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &storeSubscriptions)

        store.$stats
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &storeSubscriptions)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    @objc func showWindowFromMenu() {
        showWindow()
    }

    @objc func clearUnpinned() {
        store?.clearUnpinned()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func copyRecent(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let id = UUID(uuidString: rawValue),
              let item = store?.item(for: id) else {
            return
        }
        store?.copy(item)
    }

    func toggleWindowVisibility() {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Clip"
        item.button?.font = .systemFont(ofSize: 12, weight: .semibold)
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Clipboard History", action: #selector(showWindowFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        if let store {
            let subtitle = NSMenuItem(title: "Hotkey: \(store.hotKeyDisplay)", action: nil, keyEquivalent: "")
            subtitle.isEnabled = false
            menu.addItem(subtitle)
        }

        menu.addItem(.separator())

        if let store {
            let recentItems = store.recentItems(limit: 8)
            if recentItems.isEmpty {
                let emptyItem = NSMenuItem(title: "No clipboard history yet", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                menu.addItem(emptyItem)
            } else {
                for item in recentItems {
                    let titlePrefix = item.kind == .image ? "Image" : "Text"
                    let menuItem = NSMenuItem(title: "\(titlePrefix): \(item.title)", action: #selector(copyRecent(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.representedObject = item.id.uuidString
                    menu.addItem(menuItem)
                }
            }

            menu.addItem(.separator())

            let statsItem = NSMenuItem(
                title: "Disk \(store.formattedDiskUsage())  |  Memory \(store.formattedMemoryUsage())",
                action: nil,
                keyEquivalent: ""
            )
            statsItem.isEnabled = false
            menu.addItem(statsItem)
        }

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear Unpinned", action: #selector(clearUnpinned), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }
}
