import Cocoa

/// One decoded animation: every frame in memory, plus the geometry needed to
/// place it under the pointer and the named segments it can be played in.
struct CursorAnimation {
    let frames: [CGImage]
    let fps: Double
    /// Source artwork size in pixels.
    let size: CGSize
    /// Hotspot in pixels, measured from the top-left of the artwork.
    let hotspot: CGPoint
    /// Named frame ranges, e.g. "intro" / "hold" / "outro". Empty for cursors
    /// that are simply looped end to end.
    let segments: [String: ClosedRange<Int>]
    /// On-screen width in points at the "medium" size setting.
    ///
    /// Per-cursor rather than one global pixels-to-points factor: the animated
    /// artwork is drawn at ~110px while the static cursors only exist at 32x32,
    /// so a single factor would render the static ones less than half the size
    /// of the cat.
    let mediumWidthPoints: CGFloat

    var isAnimated: Bool { frames.count > 1 && fps > 0 }

    var duration: Double { fps > 0 ? Double(frames.count) / fps : 0 }

    /// Display size in points for a given size-setting multiplier, preserving
    /// the artwork's aspect ratio.
    func displaySize(multiplier: CGFloat) -> CGSize {
        let width = mediumWidthPoints * multiplier
        return CGSize(width: width, height: width * size.height / size.width)
    }

    /// Hotspot expressed as a CALayer anchor point, which keeps the pointer
    /// aligned at any display scale without per-frame offset arithmetic.
    /// Layer geometry is bottom-left origin, hence the flipped Y.
    var anchorPoint: CGPoint {
        CGPoint(x: hotspot.x / size.width,
                y: 1 - hotspot.y / size.height)
    }

    func frames(in segment: String) -> [CGImage]? {
        guard let range = segments[segment],
              range.lowerBound >= 0, range.upperBound < frames.count else { return nil }
        return Array(frames[range])
    }
}

enum CursorAssetsError: Error, LocalizedError {
    case resourcesMissing
    case manifestUnreadable(String)
    case framesMissing(String)

    var errorDescription: String? {
        switch self {
        case .resourcesMissing:
            return "Could not locate the Cursors resource folder."
        case .manifestUnreadable(let detail):
            return "Cursor manifest could not be read: \(detail)"
        case .framesMissing(let name):
            return "No frames found for cursor \"\(name)\"."
        }
    }
}

enum CursorAssets {
    private struct ManifestEntry: Decodable {
        let frameCount: Int
        let fps: Double
        let width: Double
        let height: Double
        let hotspotX: Double
        let hotspotY: Double
        let mediumWidthPoints: Double
        let segments: [String: [Int]]?
    }

    /// Works both from inside the built .app and when running the raw SwiftPM
    /// binary during development.
    private static func resourceRoot() throws -> URL {
        var candidates: [URL] = []
        if let bundled = Bundle.main.resourceURL {
            candidates.append(bundled.appendingPathComponent("Cursors"))
        }
        let executableDir = Bundle.main.bundleURL.deletingLastPathComponent()
        candidates.append(executableDir.appendingPathComponent("Cursors"))
        // Development fallback: <project>/Resources/Cursors
        candidates.append(executableDir
            .deletingLastPathComponent()   // release/
            .deletingLastPathComponent()   // .build/
            .appendingPathComponent("Resources/Cursors"))

        for candidate in candidates
        where FileManager.default.fileExists(
            atPath: candidate.appendingPathComponent("manifest.json").path) {
            return candidate
        }
        throw CursorAssetsError.resourcesMissing
    }

    /// Decodes every frame of every cursor. Costs a few hundred milliseconds,
    /// so callers should do this off the main thread.
    static func loadAll() throws -> [String: CursorAnimation] {
        let root = try resourceRoot()
        let manifestURL = root.appendingPathComponent("manifest.json")

        let manifest: [String: ManifestEntry]
        do {
            let data = try Data(contentsOf: manifestURL)
            manifest = try JSONDecoder().decode([String: ManifestEntry].self, from: data)
        } catch {
            throw CursorAssetsError.manifestUnreadable(error.localizedDescription)
        }

        var result: [String: CursorAnimation] = [:]
        for (name, entry) in manifest {
            let directory = root.appendingPathComponent(name)
            var frames: [CGImage] = []
            frames.reserveCapacity(entry.frameCount)

            for index in 0..<entry.frameCount {
                let url = directory.appendingPathComponent(String(format: "%04d.png", index))
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
                frames.append(image)
            }
            guard !frames.isEmpty else { throw CursorAssetsError.framesMissing(name) }

            var segments: [String: ClosedRange<Int>] = [:]
            for (key, bounds) in entry.segments ?? [:]
            where bounds.count == 2 && bounds[0] <= bounds[1] {
                segments[key] = bounds[0]...bounds[1]
            }

            result[name] = CursorAnimation(
                frames: frames,
                fps: entry.fps,
                size: CGSize(width: entry.width, height: entry.height),
                hotspot: CGPoint(x: entry.hotspotX, y: entry.hotspotY),
                segments: segments,
                mediumWidthPoints: entry.mediumWidthPoints)
        }
        return result
    }
}
