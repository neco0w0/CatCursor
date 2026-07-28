import Cocoa

// Reads whichever cursor the system is currently showing, including cursors set
// by other applications, and keeps working while our own pointer is hidden.
//
// This is what makes shape switching possible without Accessibility access:
// rather than inferring intent from UI element roles -- slow, permission-gated
// and hopeless in web and Electron content -- we read the answer the frontmost
// app already gave the window server.

@_silgen_name("CGSCurrentCursorSeed")
private func CGSCurrentCursorSeed() -> Int32

@_silgen_name("CGSGetGlobalCursorDataSize")
private func CGSGetGlobalCursorDataSize(_ cid: CGSConnectionID,
                                        _ size: UnsafeMutablePointer<Int32>) -> CGError

@_silgen_name("CGSGetGlobalCursorData")
private func CGSGetGlobalCursorData(_ cid: CGSConnectionID,
                                    _ data: UnsafeMutablePointer<UInt8>,
                                    _ size: UnsafeMutablePointer<Int32>,
                                    _ bytesPerRow: UnsafeMutablePointer<Int32>,
                                    _ rect: UnsafeMutablePointer<CGRect>,
                                    _ hotspot: UnsafeMutablePointer<CGPoint>,
                                    _ depth: UnsafeMutablePointer<Int32>,
                                    _ components: UnsafeMutablePointer<Int32>,
                                    _ bitsPerComponent: UnsafeMutablePointer<Int32>) -> CGError

struct SystemCursorReading {
    let image: CGImage
    let size: CGSize
    let hotspot: CGPoint
}

enum SystemCursorReader {
    /// Cheap integer that changes whenever the cursor changes. Polling this
    /// every frame costs nothing; the bitmap is only read when it moves.
    static var seed: Int32 { CGSCurrentCursorSeed() }

    static func read() -> SystemCursorReading? {
        let cid = SystemCursor.connection
        var byteCount: Int32 = 0
        guard CGSGetGlobalCursorDataSize(cid, &byteCount) == .success, byteCount > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: Int(byteCount))
        var size = byteCount
        var bytesPerRow: Int32 = 0
        var rect = CGRect.zero
        var hotspot = CGPoint.zero
        var depth: Int32 = 0
        var components: Int32 = 0
        var bitsPerComponent: Int32 = 0

        let err = buffer.withUnsafeMutableBufferPointer { raw in
            CGSGetGlobalCursorData(cid, raw.baseAddress!, &size, &bytesPerRow, &rect,
                                   &hotspot, &depth, &components, &bitsPerComponent)
        }
        guard err == .success,
              rect.width > 0, rect.height > 0, bytesPerRow > 0,
              let provider = CGDataProvider(data: Data(buffer) as CFData),
              let image = CGImage(width: Int(rect.width), height: Int(rect.height),
                                  bitsPerComponent: Int(bitsPerComponent),
                                  bitsPerPixel: Int(depth),
                                  bytesPerRow: Int(bytesPerRow),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue:
                                    CGImageAlphaInfo.premultipliedFirst.rawValue
                                    | CGBitmapInfo.byteOrder32Little.rawValue),
                                  provider: provider, decode: nil,
                                  shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }

        return SystemCursorReading(image: image, size: rect.size, hotspot: hotspot)
    }

    /// Downsampled RGBA signature.
    ///
    /// Colour is not optional here: operationNotAllowed, dragCopy,
    /// contextualMenu and disappearingItem are all "arrow plus a badge" and are
    /// indistinguishable as alpha silhouettes -- the badge colour is the only
    /// thing separating "show the unavailable cat" from "leave the real cursor
    /// alone". Normalising to a fixed grid also keeps the signature independent
    /// of the artwork's pixel size.
    static func fingerprint(_ image: CGImage, side: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: side, height: side,
                                          bitsPerComponent: 8,
                                          bytesPerRow: side * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return pixels
    }
}
