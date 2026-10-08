import Foundation

/// Version shown in Settings and `--version`. A packaged app reads Info.plist.
/// `swift run` has no app plist, so it uses the source fallback.
enum AppIdentity {
    static let fallbackVersion = "0.1.0-rc.4"
    static let fallbackBuild = "4"

    static var version: String { packaged("CFBundleShortVersionString") ?? fallbackVersion }
    static var build: String { packaged("CFBundleVersion") ?? fallbackBuild }
    static var commit: String { packaged("PeekMeowCommit") ?? "unknown" }

    static var report: String {
        """
        PeekMeow \(version)
        commit: \(commit)
        build: \(build)
        """
    }

    private static func packaged(_ key: String) -> String? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
