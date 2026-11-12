import AppKit

/// How the App Store edition's share extensions hand an image to the sandboxed app, which can't read the
/// extension's files. The extension writes the PNG, a one-time random token and a timestamp to a named pasteboard,
/// then opens `superscreenshot://<command>?pasteboard=share&token=<token>&change=<changeCount>` in its containing app.
///
/// The app accepts the image only when all of these hold: the token matches, the pasteboard's change count is the
/// one the extension saw (nobody wrote to it since), and the data is younger than `ttl`. Every attempt clears the
/// pasteboard, whether it is accepted or rejected. Named pasteboards are readable by any local process, so this
/// guards against stale, replayed and overwritten data, not against a process that reads the image while it is in
/// transit. The extension (Extensions/Share) can't import this module and repeats these names.
public enum ShareHandoff {
    public static let pasteboardName = NSPasteboard.Name("com.udsy.superscreenshot.share")
    public static let tokenType = NSPasteboard.PasteboardType("com.udsy.superscreenshot.share.token")
    public static let timeType = NSPasteboard.PasteboardType("com.udsy.superscreenshot.share.time")
    public static let ttl: TimeInterval = 30

    public enum Rejection: Error, Equatable { case missingToken, tokenMismatch, overwritten, expired, noImage }

    /// The PNG on `pb` if the handoff is genuine. Always clears `pb`.
    public static func take(from pb: NSPasteboard, token: String?, changeCount: Int?, now: Date = Date()) -> Result<Data, Rejection> {
        let observedChange = pb.changeCount
        defer { pb.clearContents() }
        guard let token, !token.isEmpty else { return .failure(.missingToken) }
        guard pb.string(forType: tokenType) == token else { return .failure(.tokenMismatch) }
        guard changeCount == observedChange else { return .failure(.overwritten) }
        guard let written = pb.string(forType: timeType).flatMap(Double.init),
              now.timeIntervalSince1970 - written >= -1, now.timeIntervalSince1970 - written <= ttl else { return .failure(.expired) }
        guard let data = pb.data(forType: .png),
              let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) else { return .failure(.noImage) }
        return .success(png)
    }
}
