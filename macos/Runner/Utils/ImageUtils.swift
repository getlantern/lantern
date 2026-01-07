//
//  ImageUtils.swift
//  Lantern
//

import Cocoa

extension NSImage {
    /// Returns PNG data for the image resized to `targetSize`
    @MainActor
    func pngData(resizeTo targetSize: CGSize) -> Data? {
        // Fast path with CGImage-backed conversion
        var rect = NSRect(origin: .zero, size: targetSize)
        if let cg = self.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = targetSize
            return rep.representation(using: .png, properties: [:])
        }

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }

        rep.size = targetSize
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high

        self.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        return rep.representation(using: .png, properties: [:])
    }
}
