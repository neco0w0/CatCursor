import Cocoa

/// Draws the cat cursor into a single CALayer and drives its animations.
///
/// Everything is expressed as layer animations so the GPU does the per-frame
/// work; the tracker only ever updates `position`.
final class CursorRenderer {
    private let layer = CALayer()
    private let animations: [String: CursorAnimation]
    private let arrow: CursorAnimation
    private let click: CursorAnimation?
    private var multiplier: CGFloat
    /// Whichever animation the layer is currently shaped for; rescaling has to
    /// know which artwork's dimensions to apply.
    private var currentAnimation: CursorAnimation

    /// Guards against a completion block from a superseded animation stomping
    /// on whatever is playing now (e.g. release finishing after a new press).
    private var generation = 0

    private static let animationKey = "cursorFrames"

    /// Presses are deliberately quicker than the artwork's authored 30fps: a
    /// click reaction that takes ~0.9s would still be unfolding after the
    /// button is already back up.
    private static let pressDuration = 0.30
    private static let releaseDuration = 0.30

    var hostLayer: CALayer { layer }

    init(animations: [String: CursorAnimation], multiplier: CGFloat) throws {
        guard let arrow = animations["arrow"] else {
            throw CursorAssetsError.framesMissing("arrow")
        }
        self.animations = animations
        self.arrow = arrow
        self.click = animations["click"]
        self.multiplier = multiplier
        self.currentAnimation = arrow

        layer.contentsGravity = .resizeAspect
        layer.magnificationFilter = .trilinear
        layer.minificationFilter = .trilinear
        layer.contentsScale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        layer.isOpaque = false
        layer.zPosition = 1
    }

    // MARK: - Geometry

    func setSizeMultiplier(_ newMultiplier: CGFloat) {
        guard newMultiplier != multiplier else { return }
        multiplier = newMultiplier
        applyBounds(for: currentAnimation)
    }

    /// Position is in the overlay window's coordinate space.
    func move(to point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)   // never interpolate pointer motion
        layer.position = point
        CATransaction.commit()
    }

    private func applyBounds(for animation: CursorAnimation) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.bounds = CGRect(origin: .zero,
                              size: animation.displaySize(multiplier: multiplier))
        layer.anchorPoint = animation.anchorPoint
        CATransaction.commit()
    }

    // MARK: - Playback

    func showIdle() { show("arrow") }

    /// Shows a named cursor from the manifest. Animated artwork loops; static
    /// artwork is a single frame with no animation attached.
    func show(_ name: String) {
        guard let animation = animations[name] else { return }
        generation += 1
        if animation.isAnimated {
            play(animation, frames: animation.frames,
                 duration: animation.duration, repeats: true)
        } else {
            currentAnimation = animation
            applyBounds(for: animation)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.removeAnimation(forKey: Self.animationKey)
            layer.contents = animation.frames[0]
            CATransaction.commit()
        }
    }

    var availableCursors: [String] { animations.keys.sorted() }

    func beginPress() {
        guard let click, let intro = click.frames(in: "intro") else { return }
        generation += 1
        let token = generation

        play(click, frames: intro, duration: Self.pressDuration, repeats: false) { [weak self] in
            guard let self, self.generation == token else { return }
            guard let hold = click.frames(in: "hold") else { return }
            // The artwork's breathing cycle is authored at 30fps and loops exactly.
            self.play(click, frames: hold,
                      duration: Double(hold.count) / click.fps, repeats: true)
        }
    }

    func endPress() {
        guard let click, let outro = click.frames(in: "outro") else {
            showIdle()
            return
        }
        generation += 1
        let token = generation

        play(click, frames: outro, duration: Self.releaseDuration, repeats: false) { [weak self] in
            guard let self, self.generation == token else { return }
            self.showIdle()
        }
    }

    /// Swaps the layer to `animation`'s geometry and runs `frames` over it.
    ///
    /// The layer's model `contents` is set to the frame that should remain once
    /// the animation is gone, so nothing snaps when it is removed.
    private func play(_ animation: CursorAnimation,
                      frames: [CGImage],
                      duration: Double,
                      repeats: Bool,
                      completion: (() -> Void)? = nil) {
        guard !frames.isEmpty else { return }
        currentAnimation = animation
        applyBounds(for: animation)

        let keyframes = CAKeyframeAnimation(keyPath: "contents")
        keyframes.values = frames
        keyframes.calculationMode = .discrete
        keyframes.duration = duration
        keyframes.repeatCount = repeats ? .infinity : 1

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let completion { CATransaction.setCompletionBlock(completion) }
        layer.contents = repeats ? frames[0] : frames[frames.count - 1]
        layer.removeAnimation(forKey: Self.animationKey)
        layer.add(keyframes, forKey: Self.animationKey)
        CATransaction.commit()
    }
}
