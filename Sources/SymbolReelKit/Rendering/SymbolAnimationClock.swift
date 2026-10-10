import AppKit
import QuartzCore

/// Drives symbol effects at explicit timestamps instead of in real time.
///
/// AppKit renders symbol effects with a private RenderBox layer (`RBSymbolLayer`) that normally
/// advances its animations from the display link. The layer also responds to
/// `runAnimationAtTime:`, which evaluates every running effect at a given media time and redraws
/// the layer. Calling it for each frame timestamp gives frame-accurate output that doesn't depend
/// on how fast the Mac can render.
///
/// This is the only place in SymbolReel that relies on private API. Everything else uses public
/// AppKit, Symbols and AVFoundation interfaces.
@MainActor
struct SymbolAnimationClock {
    private typealias RunAnimationFunction = @convention(c) (AnyObject, Selector, CFTimeInterval) -> Void

    private static let symbolLayerClassName = "RBSymbolLayer"
    private static let runAnimationSelector = NSSelectorFromString("runAnimationAtTime:")

    private let symbolLayer: CALayer
    private let runAnimation: RunAnimationFunction

    /// Finds the symbol layer inside an image view's layer tree.
    ///
    /// AppKit installs the layer the first time an effect is added to the view.
    init(view: NSImageView) throws(SymbolReelError) {
        guard
            let rootLayer = view.layer,
            let symbolLayer = Self.findSymbolLayer(in: rootLayer),
            symbolLayer.responds(to: Self.runAnimationSelector)
        else {
            throw .animationClockUnavailable
        }
        self.symbolLayer = symbolLayer
        self.runAnimation = unsafeBitCast(symbolLayer.method(for: Self.runAnimationSelector), to: RunAnimationFunction.self)
    }

    /// Evaluates the symbol's effects at `time`, a `CACurrentMediaTime()`-based timestamp.
    func advance(to time: CFTimeInterval) {
        runAnimation(symbolLayer, Self.runAnimationSelector, time)
    }

    /// Applies pending changes, such as newly added effects, to the symbol layer.
    ///
    /// The layer registers new effects when it lays out, and they start at the current media time.
    func layOut() {
        symbolLayer.layoutIfNeeded()
    }

    /// Whether any effect is still in motion after the last call to ``advance(to:)``.
    var isAnimating: Bool {
        (symbolLayer.value(forKeyPath: "animator.animating") as? Bool) ?? false
    }

    private static func findSymbolLayer(in layer: CALayer) -> CALayer? {
        if NSStringFromClass(type(of: layer)) == symbolLayerClassName {
            return layer
        }
        for sublayer in layer.sublayers ?? [] {
            if let match = findSymbolLayer(in: sublayer) {
                return match
            }
        }
        return nil
    }
}
