import AppKit
import UniformTypeIdentifiers

/// "Import from Super Screenshot (direct download)" for the sandboxed App Store edition: the user points open panels
/// at the direct edition's library folder and preferences file, and their contents are COPIED into this edition's
/// container. The direct edition's files are never moved, changed or deleted.
public enum DirectEditionImport {
    public static let directBundleID = "com.udsy.superscreenshot"

    /// Settings that are not carried over: folders outside the container (unreachable until chosen again in Settings),
    /// login-item and updater state of the other edition, and this edition's own access grants.
    static let skippedKeys: Set<String> = [
        "exportLocation", "uploadFolderPath", "customWallpaperPath", "launchAtLogin",
        "installUpdatesAutomatically", "lastUpdateCheck", "securityScopedBookmarks",
    ]

    /// The direct edition's library: ~/Library/Application Support/SuperScreenshot.
    public static var directLibrary: URL {
        SecurityScope.realHome.appendingPathComponent("Library/Application Support/\(AppPaths.folderName)", isDirectory: true)
    }
    public static var directPreferences: URL {
        SecurityScope.realHome.appendingPathComponent("Library/Preferences/\(directBundleID).plist")
    }

    /// Copies every item of `source` missing from `destination` and re-points History / project paths. Returns the
    /// number of items copied.
    @discardableResult
    public static func importLibrary(from source: URL, to destination: URL) throws -> Int {
        // "Updates" holds the direct edition's downloaded updates; meaningless here.
        let count = try LegacyMigration.merge(from: source, to: destination, copying: true, skipping: ["Updates"])
        LegacyMigration.rewriteStoredPaths(in: destination, from: source.standardizedFileURL.path,
                                           to: destination.standardizedFileURL.path)
        return count
    }

    /// Writes the settings in the property list at `plist` into `defaults` (except `skippedKeys`), re-pointing paths
    /// from `oldLibrary` to `newLibrary`. Returns the imported key names.
    @discardableResult
    public static func importSettings(fromPlist plist: URL, into defaults: UserDefaults,
                                      oldLibrary: String, newLibrary: String) throws -> [String] {
        let data = try Data(contentsOf: plist)
        guard let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        var imported: [String] = []
        for (key, value) in dict where !skippedKeys.contains(key) {
            defaults.set(LegacyMigration.rewritingPaths(in: value, from: oldLibrary, to: newLibrary), forKey: key)
            imported.append(key)
        }
        return imported.sorted()
    }

    /// The user-facing flow (Settings → About).
    @MainActor
    public static func runInteractively() {
        guard Alerts.confirm("Import from Super Screenshot (direct download)?",
                             info: "Choose the direct edition's “\(AppPaths.folderName)” folder (captures, history, recordings, projects), then optionally its settings file. Everything is copied; the originals are not changed.",
                             confirmTitle: "Choose Folder…", cancelTitle: "Cancel") else { return }
        let folderPanel = NSOpenPanel()
        folderPanel.canChooseDirectories = true
        folderPanel.canChooseFiles = false
        folderPanel.showsHiddenFiles = true
        folderPanel.directoryURL = directLibrary
        folderPanel.message = "Select the “\(AppPaths.folderName)” folder in Library/Application Support (it is already open; click Import)."
        folderPanel.prompt = "Import"
        NSApp.activate()
        var copied = 0
        var oldLibrary = directLibrary.path
        if folderPanel.runModal() == .OK, let src = folderPanel.url {
            do {
                copied = try importLibrary(from: src, to: AppPaths.support)
                oldLibrary = src.standardizedFileURL.path
                // The running History owns history.json in memory; merge the imported index into it.
                if let data = try? Data(contentsOf: src.appendingPathComponent("History/history.json")) {
                    let out = (LegacyMigration.rewritten(data, from: oldLibrary, to: AppPaths.support.path) as? Data) ?? data
                    let tmp = AppPaths.temporary.appendingPathComponent("imported-history.json")
                    if (try? out.write(to: tmp, options: .atomic)) != nil { Services.history?.merge(indexAt: tmp) }
                    try? FileManager.default.removeItem(at: tmp)
                }
            } catch {
                Alerts.error("Couldn't import the library.", error); return
            }
        }

        var settings = 0
        if Alerts.confirm("Import settings too?", info: "Choose “\(directBundleID).plist” in Library/Preferences. Shortcuts, capture and annotation settings are copied; save and upload folders must be chosen again.",
                          confirmTitle: "Choose Settings File…", cancelTitle: "Skip") {
            let filePanel = NSOpenPanel()
            filePanel.canChooseFiles = true
            filePanel.canChooseDirectories = false
            filePanel.showsHiddenFiles = true
            filePanel.allowedContentTypes = [.propertyList]
            filePanel.directoryURL = directPreferences.deletingLastPathComponent()
            filePanel.message = "Select “\(directBundleID).plist”."
            filePanel.prompt = "Import"
            if filePanel.runModal() == .OK, let plist = filePanel.url {
                do {
                    let keys = try importSettings(fromPlist: plist, into: Defaults.store,
                                                  oldLibrary: oldLibrary, newLibrary: AppPaths.support.path)
                    keys.forEach { Defaults.changes.send($0) }
                    settings = keys.count
                } catch {
                    Alerts.error("Couldn't import the settings.", error)
                }
            }
        }
        Alerts.info("Import finished", info: "\(copied) item(s) copied from the library, \(settings) setting(s) imported. Nothing was changed in the direct download edition.")
    }
}
