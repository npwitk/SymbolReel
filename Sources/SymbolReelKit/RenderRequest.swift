import AppKit

/// Everything needed to render one symbol animation.
public struct RenderRequest: Sendable {
    /// The symbol to animate: a system symbol such as `"wifi"`, a custom symbol from the SF Symbols
    /// app's library, or the path to an SVG template exported from the SF Symbols app.
    public var symbolName: String
    public var effect: SymbolEffectSpec
    /// The symbol to transition to; required for content transitions like `replace`.
    public var targetSymbolName: String?
    public var appearance: SymbolAppearance
    public var canvas: Canvas
    public var timing: Timing

    public init(
        symbolName: String,
        effect: SymbolEffectSpec,
        targetSymbolName: String? = nil,
        appearance: SymbolAppearance = .init(),
        canvas: Canvas = .init(),
        timing: Timing = .init()
    ) {
        self.symbolName = symbolName
        self.effect = effect
        self.targetSymbolName = targetSymbolName
        self.appearance = appearance
        self.canvas = canvas
        self.timing = timing
    }

    /// A filesystem-friendly base name such as `wifi_variable-color-iterative`.
    public var suggestedBaseName: String {
        var name = "\(SymbolReference.displayName(symbolName))_\(effect.slug)"
        if let targetSymbolName { name += "_to_\(SymbolReference.displayName(targetSymbolName))" }
        return name
    }
}

/// How the symbol itself looks.
public struct SymbolAppearance: Sendable {
    public enum RenderingMode: String, CaseIterable, Sendable {
        case monochrome, hierarchical, palette, multicolor
    }

    public var renderingMode: RenderingMode
    /// The tint color, or the palette colors in `palette` mode (primary first).
    public var colors: [RGBAColor]
    public var weight: NSFont.Weight
    public var scale: NSImage.SymbolScale
    /// The value for symbols with variable rendering, from 0 to 1.
    public var variableValue: Double?

    public init(
        renderingMode: RenderingMode = .monochrome,
        colors: [RGBAColor] = [.black],
        weight: NSFont.Weight = .regular,
        scale: NSImage.SymbolScale = .large,
        variableValue: Double? = nil
    ) {
        self.renderingMode = renderingMode
        self.colors = colors
        self.weight = weight
        self.scale = scale
        self.variableValue = variableValue
    }
}

/// The frame the symbol is drawn into.
public struct Canvas: Sendable {
    /// Output width in pixels.
    public var width: Int
    /// Output height in pixels.
    public var height: Int
    /// Empty space around the symbol as a fraction of the shorter side, leaving room for
    /// effects such as bounce and wiggle that move outside the symbol's resting bounds.
    public var padding: Double
    /// The background, or `nil` for a transparent background. Formats without alpha
    /// fall back to ``opaqueFallbackBackground``.
    public var background: RGBAColor?

    public init(width: Int = 512, height: Int = 512, padding: Double = 0.2, background: RGBAColor? = nil) {
        self.width = width
        self.height = height
        self.padding = padding
        self.background = background
    }

    public static let opaqueFallbackBackground = RGBAColor.white
}

/// When frames are sampled.
public struct Timing: Sendable {
    public enum Repeat: Hashable, Sendable {
        case count(Int)
        case forever
    }

    public var framesPerSecond: Int
    /// How long to hold the resting symbol before the effect starts, in seconds.
    public var leadIn: Double
    /// The length of the animation in seconds, or `nil` to stop once the effect settles.
    public var duration: Double?
    /// How long to hold the final frame after the effect settles, in seconds.
    public var tail: Double
    public var repeatBehavior: Repeat
    /// The pause between repetitions, in seconds.
    public var repeatDelay: Double?
    /// The playback speed multiplier of the effect.
    public var speed: Double

    public init(
        framesPerSecond: Int = 60,
        leadIn: Double = 0.25,
        duration: Double? = nil,
        tail: Double = 0.25,
        repeatBehavior: Repeat = .count(1),
        repeatDelay: Double? = nil,
        speed: Double = 1
    ) {
        self.framesPerSecond = framesPerSecond
        self.leadIn = leadIn
        self.duration = duration
        self.tail = tail
        self.repeatBehavior = repeatBehavior
        self.repeatDelay = repeatDelay
        self.speed = speed
    }

    /// The duration used for endless effects when none is given.
    public static let defaultEndlessDuration = 3.0
    /// A safety limit for effects that never report that they've settled.
    public static let maximumAutomaticDuration = 30.0
}
