import AppKit
import SwiftUI

/// The supplied atmosphere artwork: the calligraphic 23, gold slash, and star.
/// Empty pixels stay transparent, so the panel does not gain a black plate.
struct BrandMarkView: View {
    var width: CGFloat

    private var height: CGFloat {
        guard let image = BrandAtmosphere.image, image.size.width > 0 else { return 0 }
        return width * image.size.height / image.size.width
    }

    var body: some View {
        Group {
            if let image = BrandAtmosphere.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: max(width, 0), height: max(height, 0))
            }
        }
        .opacity(width > 8 && BrandAtmosphere.image != nil ? 1 : 0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

@MainActor
enum BrandAtmosphere {
    static let image: NSImage? = load()

    private static func load() -> NSImage? {
        for url in candidateURLs() {
            guard let image = NSImage(contentsOf: url),
                  let cropped = artwork(in: image) else { continue }
            return cropped
        }
        return nil
    }

    /// Drops the transparent margin around the 23. Any other file is shown whole.
    private static func artwork(in image: NSImage) -> NSImage? {
        guard let rep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()),
              let cgImage = rep.cgImage else {
            return image
        }
        guard cgImage.width == 1536, cgImage.height == 1024 else { return image }
        let crop = CGRect(x: 473, y: 214, width: 666, height: 527)
        guard let cropped = cgImage.cropping(to: crop) else { return image }
        return NSImage(cgImage: cropped, size: NSSize(width: crop.width, height: crop.height))
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []
        if let bundled = Bundle.main.url(forResource: "PeekMeowAtmosphere", withExtension: "png") {
            urls.append(bundled)
        }
        let fileManager = FileManager.default
        urls.append(
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent("Brand/PeekMeow-Atmosphere.png")
        )
        if let executable = Bundle.main.executableURL {
            var directory = executable.deletingLastPathComponent()
            for _ in 0..<8 {
                urls.append(directory.appendingPathComponent("Brand/PeekMeow-Atmosphere.png"))
                urls.append(directory.appendingPathComponent("PeekMeowAtmosphere.png"))
                directory.deleteLastPathComponent()
            }
        }
        return urls
    }
}
