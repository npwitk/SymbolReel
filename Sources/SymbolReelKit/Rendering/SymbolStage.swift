import AppKit
import Symbols

/// Hosts an `NSImageView` in an offscreen window and draws it into bitmaps.
@MainActor
final class SymbolStage {
    private let view: NSImageView
    /// The symbol to transition to, for content transitions such as `replace`.
    private let targetImage: NSImage?
    private let window: NSWindow
    private var clock: SymbolAnimationClock?
    private let canvas: Canvas
    private let context: CGContext

    init(request: RenderRequest) throws(SymbolReelError) {
        Self.bootstrapApplication()

        canvas = request.canvas
        let appearance = request.appearance
        let image = try Self.symbolImage(named: request.symbolName, variableValue: appearance.variableValue)
        targetImage = try request.targetSymbolName.map { name throws(SymbolReelError) in
            try Self.symbolImage(named: name, variableValue: appearance.variableValue)
        }

        let frame = NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height)

        view = NSImageView(frame: frame)
        view.wantsLayer = true
        view.imageScaling = .scaleNone
        view.imageAlignment = NSImageAlignment(rawValue: UInt(ProcessInfo.processInfo.environment["DBG_ALIGN"] ?? "0")!)!
        view.contentTintColor = appearance.colors.first?.nsColor
        view.image = image

        // The window is never shown; it gives the view a layer-backed hierarchy to draw into.
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view

        guard let context = CGContext(
            data: nil,
            width: canvas.width,
            height: canvas.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw .invalidRequest("Couldn't create a \(canvas.width)×\(canvas.height) drawing context.")
        }
        self.context = context

        fitSymbol(images: [image] + [targetImage].compactMap(\.self), appearance: appearance)
        view.image = image
    }

    /// Puts the symbol into the state the effect starts from, ready to animate.
    func prepare(_ effect: SymbolEffectSpec) throws(SymbolReelError) {
        try effect.prepare(view)
        settle()

        // The first effect added to a view makes AppKit install the animatable symbol layer and
        // build the glyph's animation data, which takes several milliseconds. Do that with a
        // throwaway effect now, so adding the real effect is quick and its start time is precise.
        view.addSymbolEffect(.bounce, options: .nonRepeating)
        let clock = try SymbolAnimationClock(view: view)
        clock.advance(to: CACurrentMediaTime())
        clock.layOut()

        view.removeAllSymbolEffects(animated: false)
        try effect.prepare(view)
        clock.advance(to: CACurrentMediaTime())
        clock.layOut()
        self.clock = clock
    }

    /// Adds the effect and returns the media time its animation starts at.
    func start(_ effect: SymbolEffectSpec, options: SymbolEffectOptions) throws(SymbolReelError) -> CFTimeInterval {
        clock?.advance(to: CACurrentMediaTime())
        try effect.start(on: view, target: targetImage, options: options)
        if ProcessInfo.processInfo.environment["DBG_LAYOUT"] != nil {
            view.layoutSubtreeIfNeeded()
            view.layer?.layoutIfNeeded()
        }

        let clock = try SymbolAnimationClock(view: view)
        self.clock = clock
        clock.advance(to: CACurrentMediaTime())

        // The effect is registered during layout, stamped with the media time at that moment.
        let startTime = CACurrentMediaTime()
        clock.layOut()

        // Layout reads the clock a few microseconds after `startTime`. Sampling slightly later keeps
        // the first frame from landing before the effect begins.
        return startTime + Self.startTimeTolerance
    }

    /// Evaluates the effect at `time` and returns whether it's still in motion.
    func advance(to time: CFTimeInterval) -> Bool {
        guard let clock else { return false }
        clock.advance(to: time)
        return clock.isAnimating
    }

    private static let startTimeTolerance: CFTimeInterval = 0.001

    /// Lets AppKit commit the view's layer tree.
    ///
    /// Symbol effects only animate once the symbol has been displayed at least once.
    private func settle() {
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        for _ in 0..<3 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
    }

    /// Draws the view's current state into a new image.
    func snapshot() -> CGImage {
        let bounds = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
        context.clear(bounds)
        if let background = canvas.background {
            context.setFillColor(background.cgColor)
            context.fill(bounds)
        }
        view.layer?.render(in: context)
        return context.makeImage()!
    }

    // MARK: - Setup helpers

    private static func bootstrapApplication() {
        let application = NSApplication.shared
        if application.activationPolicy() != .prohibited {
            application.setActivationPolicy(.prohibited)
        }
    }

    private static func symbolImage(named name: String, variableValue: Double?) throws(SymbolReelError) -> NSImage {
        let image = if let variableValue {
            NSImage(systemSymbolName: name, variableValue: variableValue, accessibilityDescription: nil)
        } else {
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        guard let image else { throw .unknownSymbol(name) }
        return image
    }

    private static func configuration(for appearance: SymbolAppearance, pointSize: CGFloat) -> NSImage.SymbolConfiguration {
        let base = NSImage.SymbolConfiguration(pointSize: pointSize, weight: appearance.weight, scale: appearance.scale)
        let colors = appearance.colors.map(\.nsColor)

        return switch appearance.renderingMode {
        case .monochrome:
            base.applying(.preferringMonochrome())
        case .hierarchical:
            base.applying(.init(hierarchicalColor: colors.first ?? .black))
        case .palette:
            base.applying(.init(paletteColors: colors.isEmpty ? [.black] : colors))
        case .multicolor:
            base.applying(.preferringMulticolor())
        }
    }

    /// Sizes the symbol so the largest of `images` fills the canvas inside the padding.
    ///
    /// A symbol's image size includes alignment margins, so the drawn pixels are measured instead:
    /// each image is rendered once at a reference size and scaled to fit.
    private func fitSymbol(images: [NSImage], appearance: SymbolAppearance) {
        let inset = CGFloat(canvas.padding) * CGFloat(min(canvas.width, canvas.height))
        let available = CGSize(width: CGFloat(canvas.width) - 2 * inset, height: CGFloat(canvas.height) - 2 * inset)
        let referencePointSize = CGFloat(min(canvas.width, canvas.height)) / 4

        view.symbolConfiguration = Self.configuration(for: appearance, pointSize: referencePointSize)
        var factor = CGFloat.greatestFiniteMagnitude
        for image in images {
            view.image = image
            settle()
            guard let ink = inkBounds() else { continue }
            factor = min(factor, available.width / ink.width, available.height / ink.height)
        }
        if factor == .greatestFiniteMagnitude { factor = 1 }

        view.symbolConfiguration = Self.configuration(for: appearance, pointSize: max(1, (referencePointSize * factor).rounded(.down)))
    }

    /// The bounds of the pixels the view currently draws, ignoring the background.
    private func inkBounds() -> CGRect? {
        let width = canvas.width, height = canvas.height
        guard let mask = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        view.layer?.render(in: mask)

        guard let data = mask.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where data[y * mask.bytesPerRow + x] > 0 {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
