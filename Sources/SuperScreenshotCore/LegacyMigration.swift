import Foundation

/// One-time move from the app's previous name, Shotcraft (bundle id `com.udsy.shotcraft`): the Application Support
/// folder, the preferences, and stored paths that pointed into the old folder. Call it first thing at launch,
/// before anything touches `AppPaths` (which creates the new folder).
public enum LegacyMigration {
    static let legacyBundleID = "com.udsy.shotcraft"
    static let legacyFolderName = "Shotcraft"
    static let legacyDocumentExtension = "shotcraft"

    /// Whether this launch copied the old preferences into the new domain.
    public private(set) nonisolated(unsafe) static var didMigratePreferences = false

    public static func runIfNeeded() {
        guard let bundleID = Bundle.main.bundleIdentifier, bundleID != legacyBundleID else { return }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        didMigratePreferences = migrate(supportBase: base, domain: bundleID, legacyDomain: legacyBundleID)
    }

    /// Moves `<base>/Shotcraft` into `<base>/<AppPaths.folderName>` and copies the `legacyDomain` preferences
    /// into `domain` if that is empty. Returns whether preferences were copied.
    ///
    /// Resumable: a whole-folder rename when the new folder doesn't exist yet; otherwise (a launch was interrupted,
    /// or the new folder was created before the old one was found) the old folder's files are merged in one by
    /// one, skipping names that already exist. The old folder is deleted only once it is empty, so an interrupted
    /// move never loses anything.
    @discardableResult
    public static func migrate(supportBase base: URL, domain: String, legacyDomain: String) -> Bool {
        let fm = FileManager.default
        let oldDir = base.appendingPathComponent(legacyFolderName, isDirectory: true)
        let newDir = base.appendingPathComponent(AppPaths.folderName, isDirectory: true)
        let (old, new) = (oldDir.path, newDir.path)

        if fm.fileExists(atPath: old) {
            do {
                if fm.fileExists(atPath: new) { try merge(from: oldDir, to: newDir) } else { try fm.moveItem(at: oldDir, to: newDir) }
                rewriteStoredPaths(in: newDir, from: old, to: new)
            } catch {
                Log.app.error("Couldn't move \(old, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        let defaults = UserDefaults.standard
        guard (defaults.persistentDomain(forName: domain) ?? [:]).isEmpty,
              let legacy = defaults.persistentDomain(forName: legacyDomain), !legacy.isEmpty else { return false }
        defaults.setPersistentDomain(rewritingPaths(in: legacy, from: old, to: new) as? [String: Any] ?? legacy,
                                     forName: domain)
        return true
    }

    /// Moves (or with `copying`, copies) every item of `source` that doesn't exist in `destination`, recursing into
    /// folders present in both. When moving, `source` is removed once nothing is left in it; items that exist on both
    /// sides stay in `source`. Copying never changes `source`. Top-level names in `skipping` are left alone.
    /// Returns how many items were transferred.
    @discardableResult
    static func merge(from source: URL, to destination: URL, copying: Bool = false, skipping: Set<String> = []) throws -> Int {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        var count = 0
        for name in try fm.contentsOfDirectory(atPath: source.path) {
            let from = source.appendingPathComponent(name), to = destination.appendingPathComponent(name)
            var fromIsDir: ObjCBool = false, toIsDir: ObjCBool = false
            if skipping.contains(name) { continue }
            if name == ".DS_Store" { if !copying { try? fm.removeItem(at: from) }; continue }   // Finder's, never user data
            guard fm.fileExists(atPath: from.path, isDirectory: &fromIsDir) else { continue }
            if !fm.fileExists(atPath: to.path, isDirectory: &toIsDir) {
                if copying { try fm.copyItem(at: from, to: to) } else { try fm.moveItem(at: from, to: to) }
                count += 1
            } else if fromIsDir.boolValue, toIsDir.boolValue {
                count += try merge(from: from, to: to, copying: copying)
            }
        }
        if !copying, (try fm.contentsOfDirectory(atPath: source.path)).isEmpty { try fm.removeItem(at: source) }
        return count
    }

    /// Capture History and Annotate's sidecar projects store absolute paths into the library folder `dir`; re-point
    /// the ones under `old` to `new`.
    static func rewriteStoredPaths(in dir: URL, from old: String, to new: String) {
        let projects = dir.appendingPathComponent("Projects", isDirectory: true)
        let sidecars = ((try? FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)) ?? [])
            .filter { [legacyDocumentExtension, "superscreenshot"].contains($0.pathExtension) }
        for file in [dir.appendingPathComponent("History/history.json")] + sidecars {
            guard let data = try? Data(contentsOf: file),
                  let out = rewritten(data, from: old, to: new) as? Data else { continue }
            try? out.write(to: file, options: .atomic)
        }
    }

    /// `value` with every path or `file://` URL inside the folder `old` re-pointed into `new`. Walks strings, arrays,
    /// dictionaries and JSON-encoded `Data` (how `Defaults` stores structured values); anything else is unchanged.
    public static func rewritingPaths(in value: Any, from old: String, to new: String) -> Any {
        rewritten(value, from: old, to: new) ?? value
    }

    /// The rewritten value, or nil when nothing inside it changed.
    static func rewritten(_ value: Any, from old: String, to new: String) -> Any? {
        switch value {
        case let s as String:
            if s == old || s.hasPrefix(old + "/") { return new + s.dropFirst(old.count) }
            guard s.hasPrefix("file:"), let url = URL(string: s), url.isFileURL,
                  let path = rewritten(url.path, from: old, to: new) as? String else { return nil }
            return URL(fileURLWithPath: path, isDirectory: s.hasSuffix("/")).absoluteString
        case let array as [Any]:
            let items = array.map { rewritten($0, from: old, to: new) }
            guard items.contains(where: { $0 != nil }) else { return nil }
            return zip(array, items).map { $1 ?? $0 }
        case let dict as [String: Any]:
            var out = dict, changed = false
            for (key, v) in dict {
                if let r = rewritten(v, from: old, to: new) { out[key] = r; changed = true }
            }
            return changed ? out : nil
        case let data as Data:
            guard let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
                  let r = rewritten(json, from: old, to: new) else { return nil }
            return try? JSONSerialization.data(withJSONObject: r, options: .fragmentsAllowed)
        default:
            return nil
        }
    }
}
