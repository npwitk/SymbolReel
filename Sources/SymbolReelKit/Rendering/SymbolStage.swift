import AppKit
import SwiftUI

/// Hosts the symbol in an offscreen SwiftUI view and renders it one frame at a time.
///
/// `NSHostingView._renderForTest(interval:)` advances SwiftUI's animation clock by an exact
/// interval and renders synchronously. SwiftUI uses it in its own performance tests. Stepping
/// with it makes every frame land on an exact timestamp, so output is identical from run to run
/// and independent of how fast the Mac renders.
@MainActor
final class SymbolStage {
    private let host: NSHostingView<SymbolScene>
    private let window: NSWindow
    private let state: SceneState
    private let effect: SymbolEffectSpec
    private let canvas: Canvas
    private let frameInterval: Double
    private let context: CGContext
    private var previousFrame: [UInt8] = []

    init(request: RenderRequest, options: SymbolEffectOptions, isEndless: Bool) throws(SymbolReelError) {
        Self.bootstrapApplication()

        effect = request.effect
        canvas = request.canvas
        frameInterval = 1 / Double(request.timing.framesPerSecond)

        let symbols = try ResolvedSymbol.resolve([request.symbolName] + [request.targetSymbolName].compactMap(\.self))
        let symbol = symbols[0]
        let targetSymbol = symbols.count > 1 ? symbols[1] : nil

        guard let context = Self.makeContext(width: canvas.width, height: canvas.height) else {
            throw .invalidRequest("Couldn't create a \(canvas.width)×\(canvas.height) drawing context.")
        }
        self.context = context

        let canvasSize = CGSize(width: canvas.width, height: canvas.height)
        let pointSize = Self.fittingPointSize(for: symbols, appearance: request.appearance, canvas: canvas)

        // Effects that bring the symbol into view start with it hidden.
        state = SceneState(isVisible: ![.appear, .drawOn].contains(effect.kind))
        host = NSHostingView(rootView: SymbolScene(
            symbol: symbol,
            targetSymbol: targetSymbol,
            effect: effect,
            options: options,
            isEndless: isEndless,
            appearance: request.appearance,
            pointSize: pointSize,
            canvasSize: canvasSize,
            state: state
        ))
        window = Self.mount(host, size: canvasSize)
        host._renderForTest(interval: frameInterval)
    }

    /// Changes the scene's state to play the effect. It animates over the following frames.
    func start() {
        withAnimation {
            switch effect.kind {
            case .scale:
                state.isActive = true
            case .appear, .drawOn:
                state.isVisible = true
            case .disappear, .drawOff:
                state.isVisible = false
            case .replace:
                state.showsTarget = true
            case .bounce, .pulse, .variableColor, .wiggle, .rotate, .breathe:
                state.isActive = true
                state.trigger += 1
            }
        }
    }

    /// Advances the animation by one frame interval.
    func advance() {
        host._renderForTest(interval: frameInterval)
    }

    /// Draws the current state into a new image, and reports whether it differs from the last one.
    func snapshot() -> (image: CGImage, changed: Bool) {
        let bounds = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
        context.clear(bounds)
        if let background = canvas.background {
            context.setFillColor(background.cgColor)
            context.fill(bounds)
        }
        context.saveGState()
        // The hosting view is flipped; Core Graphics contexts aren't.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        host.layer?.render(in: context)
        context.restoreGState()

        let byteCount = context.bytesPerRow * context.height
        let pixels = UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: byteCount)
        let changed = !previousFrame.elementsEqual(pixels)
        if changed {
            previousFrame = Array(pixels)
        }
        return (context.makeImage()!, changed)
    }

    // MARK: - Setup

    private static func bootstrapApplication() {
        let application = NSApplication.shared
        if application.activationPolicy() != .prohibited {
            application.setActivationPolicy(.prohibited)
        }
    }

    /// Puts a view in a window that's never shown, giving it a layer tree to render.
    private static func mount(_ view: NSView, size: CGSize) -> NSWindow {
        view.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        return window
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
    }

    /// Picks the point size that makes the drawn shape of the largest symbol fill the canvas
    /// inside the padding.
    ///
    /// A symbol's layout bounds include alignment margins, so each symbol is rendered once at a
    /// reference size and its drawn pixels are measured instead.
    private static func fittingPointSize(for symbols: [ResolvedSymbol], appearance: SymbolAppearance, canvas: Canvas) -> CGFloat {
        let inset = CGFloat(canvas.padding) * CGFloat(min(canvas.width, canvas.height))
        let available = CGSize(width: CGFloat(canvas.width) - 2 * inset, height: CGFloat(canvas.height) - 2 * inset)
        let referencePointSize = CGFloat(min(canvas.width, canvas.height)) / 4
        let canvasSize = CGSize(width: canvas.width, height: canvas.height)

        var factor = CGFloat.greatestFiniteMagnitude
        for symbol in symbols {
            let view = NSHostingView(rootView: SymbolScene(
                symbol: symbol,
                targetSymbol: nil,
                effect: SymbolEffectSpec(kind: .pulse),
                options: .default,
                isEndless: false,
                appearance: appearance,
                pointSize: referencePointSize,
                canvasSize: canvasSize,
                state: SceneState(isVisible: true)
            ))
            let window = mount(view, size: canvasSize)
            view._renderForTest(interval: 0)
            if let ink = inkBounds(of: view, size: canvasSize) {
                factor = min(factor, available.width / ink.width, available.height / ink.height)
            }
            window.contentView = nil
        }
        if factor == .greatestFiniteMagnitude { factor = 1 }
        return max(1, (referencePointSize * factor).rounded(.down))
    }

    /// The bounds of the pixels a view draws.
    private static func inkBounds(of view: NSView, size: CGSize) -> CGRect? {
        let width = Int(size.width), height = Int(size.height)
        guard let mask = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ), let layer = view.layer else { return nil }
        layer.render(in: mask)

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
