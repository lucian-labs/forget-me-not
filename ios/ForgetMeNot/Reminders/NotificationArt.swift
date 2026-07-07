import UIKit

/// Builds the image shown on a task's reminder. The task's gold-ink icon, or — when the task
/// has none yet — the app's gold monogram, either way centered on the logo's black field so
/// the transparent gold strokes actually read (raw, they render as a blank thumbnail). Returns
/// a temp PNG URL that UNNotificationAttachment consumes.
enum NotificationArt {
    // Computed (not a stored static) to sidestep Swift 6 non-Sendable global state; UIKit
    // caches named images, so repeated lookups are cheap.
    private static var logo: UIImage? { UIImage(named: "NotifLogo") }

    @MainActor static func file(taskIcon: Data?, key: String) -> URL? {
        guard let art = taskIcon.flatMap(UIImage.init(data:)) ?? logo else { return nil }
        let side: CGFloat = 512
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            UIColor.black.setFill()                       // the logo's field — makes the gold pop
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let pad: CGFloat = 56
            art.draw(in: aspectFit(art.size, into: CGRect(x: pad, y: pad, width: side - 2 * pad, height: side - 2 * pad)))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fmn-notif-\(key).png")
        guard let data = image.pngData(), (try? data.write(to: url)) != nil else { return nil }
        return url
    }

    private static func aspectFit(_ size: CGSize, into box: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        let w = size.width * scale, h = size.height * scale
        return CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h)
    }
}
