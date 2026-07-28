import Cocoa

/// Offscreen self-check, run with `--render-test <out.png> [segment] [size]`.
///
/// Renders the real CursorRenderer into a bitmap with a crosshair drawn at the
/// exact point the cursor was asked to sit on. If the artwork's pointer tip
/// lands anywhere other than that intersection, the hotspot anchoring or the
/// scaling is wrong -- a defect that is otherwise very hard to spot by eye but
/// makes every click land slightly off from where the pointer appears to be.
enum RenderTest {
    private static let canvas = CGSize(width: 200, height: 200)
    private static let hotspot = CGPoint(x: 100, y: 100)

    static func run(outputPath: String, segment: String, size: CursorSize) -> Int32 {
        do {
            let animations = try CursorAssets.loadAll()
            let renderer = try CursorRenderer(animations: animations, multiplier: size.multiplier)

            let container = CALayer()
            container.frame = CGRect(origin: .zero, size: canvas)
            container.backgroundColor = NSColor.white.cgColor
            addCrosshair(to: container)
            container.addSublayer(renderer.hostLayer)

            switch segment {
            case "press": renderer.beginPress()
            case "release": renderer.endPress()
            case "idle": renderer.showIdle()
            default: renderer.show(segment)   // any cursor name from the manifest
            }
            renderer.move(to: hotspot)

            try write(container, to: outputPath)
            let bounds = renderer.hostLayer.bounds.size
            print("rendered \(segment) at \(size.rawValue): "
                  + "layer \(Int(bounds.width))x\(Int(bounds.height))pt, "
                  + "anchor \(renderer.hostLayer.anchorPoint), "
                  + "hotspot requested at \(hotspot) -> \(outputPath)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("render-test failed: \(error)\n".utf8))
            return 1
        }
    }

    private static func addCrosshair(to container: CALayer) {
        let colour = NSColor.systemBlue.cgColor
        let horizontal = CALayer()
        horizontal.frame = CGRect(x: 0, y: hotspot.y, width: canvas.width, height: 1)
        horizontal.backgroundColor = colour
        let vertical = CALayer()
        vertical.frame = CGRect(x: hotspot.x, y: 0, width: 1, height: canvas.height)
        vertical.backgroundColor = colour
        container.addSublayer(horizontal)
        container.addSublayer(vertical)
    }

    private static func write(_ layer: CALayer, to path: String) throws {
        let scale: CGFloat = 2
        guard let context = CGContext(
            data: nil,
            width: Int(canvas.width * scale),
            height: Int(canvas.height * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CursorAssetsError.resourcesMissing }

        context.scaleBy(x: scale, y: scale)
        layer.render(in: context)

        guard let image = context.makeImage() else {
            throw CursorAssetsError.resourcesMissing
        }
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil) else {
            throw CursorAssetsError.resourcesMissing
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
