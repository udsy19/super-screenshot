import AppKit
import UniformTypeIdentifiers

/// Share-menu extension ("Annotate with Super Screenshot" / "Pin to the Screen"). Receives one image, stores it where the
/// main app can read it, and hands it over via the URL scheme. Compiled twice: with `-D PIN` for the pin variant.
final class ShareViewController: NSViewController {
    #if PIN
    private let command = "pin"
    #else
    private let command = "open-annotate"
    #endif

    override func loadView() {
        let spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 60))
        spinner.frame.origin = NSPoint(x: 24, y: 14)
        view.addSubview(spinner)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
              let provider = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            finish(); return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] obj, _ in
                let url = (obj as? URL) ?? (obj as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                DispatchQueue.main.async { self?.handOff(url) }
            }
        } else {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                var url: URL?
                if let data, let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) {
                    let dest = FileManager.default.temporaryDirectory.appendingPathComponent("Shared \(UUID().uuidString.prefix(8)).png")
                    if (try? png.write(to: dest)) != nil { url = dest }
                }
                DispatchQueue.main.async { self?.handOff(url) }
            }
        }
    }

    #if APP_STORE
    /// The sandboxed app can't read this extension's files, so the image travels on a named pasteboard with a one-time
    /// token (checked by `ShareHandoff` in the app; the names below must match it), and the URL goes to the containing
    /// app explicitly (the direct edition may also be installed and own the scheme).
    private func handOff(_ file: URL?) {
        guard let file, let data = try? Data(contentsOf: file),
              let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) else { finish(); return }
        let pb = NSPasteboard(name: NSPasteboard.Name("com.udsy.superscreenshot.share"))
        let token = UUID().uuidString
        pb.clearContents()
        pb.setData(png, forType: .png)
        pb.setString(token, forType: NSPasteboard.PasteboardType("com.udsy.superscreenshot.share.token"))
        pb.setString(String(Date().timeIntervalSince1970), forType: NSPasteboard.PasteboardType("com.udsy.superscreenshot.share.time"))
        var c = URLComponents(string: "superscreenshot://\(command)")
        c?.queryItems = [URLQueryItem(name: "pasteboard", value: "share"), URLQueryItem(name: "token", value: token),
                         URLQueryItem(name: "change", value: String(pb.changeCount))]
        guard let url = c?.url else { pb.clearContents(); finish(); return }
        let app = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if error != nil { pb.clearContents() }   // the app never got it: don't leave the image lying around
        }
        finish()
    }
    #else
    private func handOff(_ file: URL?) {
        if let file, var c = URLComponents(string: "superscreenshot://\(command)") {
            c.queryItems = [URLQueryItem(name: "filepath", value: file.path)]
            if let url = c.url { NSWorkspace.shared.open(url) }
        }
        finish()
    }
    #endif

    private func finish() { extensionContext?.completeRequest(returningItems: nil) }
}
