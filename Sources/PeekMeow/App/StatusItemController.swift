import AppKit

/// Accessory-app status item. The icon stays visible so Settings and Quit remain reachable.
@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let onShow: () -> Void
    private let onHide: () -> Void
    private let onReset: () -> Void
    private let onOpenSettings: () -> Void
    private let onToggleHitRegions: () -> Void
    private let onToggleAnchorGeometry: () -> Void
    private let onToggleInteractionRegions: () -> Void

    init(
        onShow: @escaping () -> Void,
        onHide: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onToggleHitRegions: @escaping () -> Void = {},
        onToggleAnchorGeometry: @escaping () -> Void = {},
        onToggleInteractionRegions: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.onShow = onShow
        self.onHide = onHide
        self.onReset = onReset
        self.onToggleHitRegions = onToggleHitRegions
        self.onToggleAnchorGeometry = onToggleAnchorGeometry
        self.onToggleInteractionRegions = onToggleInteractionRegions
        self.onOpenSettings = onOpenSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.menuBarImage()
            button.image?.isTemplate = false
            button.toolTip = "PeekMeow"
        }
        item.menu = makeMenu()
    }

    /// The cat logo at menu-bar size. A missing file falls back to the note symbol.
    private static func menuBarImage() -> NSImage {
        for url in menuBarURLs() {
            guard let image = NSImage(contentsOf: url),
                  image.size.width > 0,
                  image.size.height > 0
            else { continue }
            let height: CGFloat = 18
            let width = (height * image.size.width / image.size.height).rounded()
            image.size = NSSize(width: width, height: height)
            image.isTemplate = false
            return image
        }
        let symbol = NSImage(systemSymbolName: "note.text", accessibilityDescription: "PeekMeow") ?? NSImage()
        symbol.isTemplate = true
        return symbol
    }

    private static func menuBarURLs() -> [URL] {
        var urls: [URL] = []
        if let bundled = Bundle.main.url(forResource: "PeekMeowMenuBar", withExtension: "png") {
            urls.append(bundled)
        }
        let fileManager = FileManager.default
        urls.append(URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Brand/PeekMeow-MenuBar.png"))
        if let executable = Bundle.main.executableURL {
            var directory = executable.deletingLastPathComponent()
            for _ in 0..<8 {
                urls.append(directory.appendingPathComponent("Brand/PeekMeow-MenuBar.png"))
                urls.append(directory.appendingPathComponent("PeekMeowMenuBar.png"))
                directory.deleteLastPathComponent()
            }
        }
        return urls
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let header = NSMenuItem(title: "PeekMeow", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let show = NSMenuItem(title: "Show PeekMeow", action: #selector(showPanel), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let hide = NSMenuItem(title: "Hide PeekMeow", action: #selector(hidePanel), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        let reset = NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        #if DEBUG
        menu.addItem(.separator())
        let hits = NSMenuItem(
            title: "Show Hit Regions",
            action: #selector(toggleHitRegions),
            keyEquivalent: ""
        )
        hits.target = self
        hits.state = DebugFlags.showHitRegions ? .on : .off
        menu.addItem(hits)

        let anchor = NSMenuItem(
            title: "Show Anchor Geometry",
            action: #selector(toggleAnchorGeometry),
            keyEquivalent: ""
        )
        anchor.target = self
        anchor.state = DebugFlags.showAnchorGeometry ? .on : .off
        menu.addItem(anchor)

        let regions = NSMenuItem(
            title: "Show Interaction Regions",
            action: #selector(toggleInteractionRegions),
            keyEquivalent: ""
        )
        regions.target = self
        regions.state = DebugFlags.showInteractionRegions ? .on : .off
        menu.addItem(regions)
        #endif

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit PeekMeow",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func showPanel() {
        onShow()
    }

    @objc private func hidePanel() {
        onHide()
    }

    @objc private func resetPosition() {
        onReset()
    }

    #if DEBUG
    @objc private func toggleHitRegions() {
        onToggleHitRegions()
        item.menu = makeMenu()
    }

    @objc private func toggleAnchorGeometry() {
        onToggleAnchorGeometry()
        item.menu = makeMenu()
    }

    @objc private func toggleInteractionRegions() {
        onToggleInteractionRegions()
        item.menu = makeMenu()
    }
    #endif
}
