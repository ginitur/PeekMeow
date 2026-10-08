import AppKit
import PeekMeowCore

/// Optional corner file used by the smoke check. The panel draws PeekMeowAtmosphere.png.
/// A missing file must not trap.
@MainActor
enum AtmosphereArtwork {
    static let image: NSImage? = load()

    static func load() -> NSImage? {
        for url in candidateURLs() {
            guard let image = NSImage(contentsOf: url), hasPixels(image) else { continue }
            return image
        }
        return nil
    }

    static func smokeReport() -> String {
        let loaded = image
        let layout = AtmosphereMark.layout(panelWidth: 340, panelHeight: 460, lightBackground: false)
        let pixels = loaded.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none"
        return """
        \(AppIdentity.report)
        mark: \(loaded == nil ? "no" : "yes")
        markPixels: \(pixels)
        layoutWidth: \(layout.width)
        layoutOpacity: \(layout.opacity)
        """
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []
        if let bundled = Bundle.main.url(forResource: "PeekMeowMark", withExtension: "png") {
            urls.append(bundled)
        }
        let fileManager = FileManager.default
        urls.append(URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Brand/PeekMeow-Mark.png"))
        if let executable = Bundle.main.executableURL {
            var directory = executable.deletingLastPathComponent()
            for _ in 0..<8 {
                urls.append(directory.appendingPathComponent("Brand/PeekMeow-Mark.png"))
                urls.append(directory.appendingPathComponent("PeekMeowMark.png"))
                directory.deleteLastPathComponent()
            }
        }
        return urls
    }

    private static func hasPixels(_ image: NSImage) -> Bool {
        image.representations.contains { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
    }
}
