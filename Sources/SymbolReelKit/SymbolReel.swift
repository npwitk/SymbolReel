import AppKit
import Symbols

/// Renders SF Symbol animations to video and image files.
///
/// ```swift
/// let request = RenderRequest(symbolName: "wifi", effect: try SymbolEffectSpec(parsing: "variable-color.iterative"))
/// try SymbolReel.render(request, to: [OutputTarget(format: .prores, url: URL(filePath: "wifi.mov"))])
/// ```
///
/// Rendering uses AppKit, so it must run on the main thread of a process with a main run loop,
/// such as a command-line tool or an app.
@MainActor
public enum SymbolReel {
    public struct Result: Sendable {
        public var frameCount: Int
        public var framesPerSecond: Int
        public var outputs: [OutputTarget]

        public var duration: Double { Double(frameCount) / Double(framesPerSecond) }
    }

    @discardableResult
    public static func render(_ request: RenderRequest, to outputs: [OutputTarget]) throws(SymbolReelError) -> Result {
        try validate(request)

        let effect = request.effect
        let timing = request.timing
        let fps = timing.framesPerSecond

        let stage = try SymbolStage(request: request)
        try stage.prepare(effect)

        var sinks: [any FrameSink] = []
        var frameCount = 0
        func emit(_ frame: CGImage, times count: Int = 1) throws(SymbolReelError) {
            for _ in 0..<count {
                for sink in sinks { try sink.append(frame) }
                frameCount += 1
            }
        }

        do throws(SymbolReelError) {
            for output in outputs {
                sinks.append(try output.makeSink(canvas: request.canvas, framesPerSecond: fps))
            }

            // Hold the resting symbol before the effect starts.
            var lastFrame = stage.snapshot()
            try emit(lastFrame, times: frames(timing.leadIn, fps: fps))

            let startTime = try stage.start(effect, options: effectOptions(for: request))

            // Sample the animation at exact frame times, independent of how fast frames render.
            let fixedFrameCount = effectDuration(for: request).map { frames($0, fps: fps) }
            let frameLimit = fixedFrameCount ?? frames(Timing.maximumAutomaticDuration, fps: fps)

            for index in 0..<frameLimit {
                let isAnimating = stage.advance(to: startTime + Double(index) / Double(fps))
                lastFrame = stage.snapshot()
                try emit(lastFrame)

                if fixedFrameCount == nil, index > 0, !isAnimating {
                    break
                }
            }

            // Hold the final state.
            try emit(lastFrame, times: frames(timing.tail, fps: fps))

            for sink in sinks { try sink.finish() }
        } catch {
            for sink in sinks { sink.cancel() }
            throw error
        }

        return Result(frameCount: frameCount, framesPerSecond: fps, outputs: outputs)
    }

    // MARK: - Request handling

    private static func validate(_ request: RenderRequest) throws(SymbolReelError) {
        let canvas = request.canvas
        let timing = request.timing

        guard (16...8192).contains(canvas.width), (16...8192).contains(canvas.height) else {
            throw .invalidRequest("The canvas must be between 16 and 8192 pixels on each side.")
        }
        guard (0..<0.5).contains(canvas.padding) else {
            throw .invalidRequest("Padding must be at least 0 and less than 0.5.")
        }
        guard (1...240).contains(timing.framesPerSecond) else {
            throw .invalidRequest("The frame rate must be between 1 and 240.")
        }
        guard timing.speed > 0 else {
            throw .invalidRequest("Speed must be greater than 0.")
        }
        guard timing.leadIn >= 0, timing.tail >= 0, (timing.duration ?? 1) > 0, (timing.repeatDelay ?? 0) >= 0 else {
            throw .invalidRequest("Durations and delays can't be negative.")
        }
        if case .count(let count) = timing.repeatBehavior, count < 1 {
            throw .invalidRequest("The repeat count must be at least 1.")
        }

        let kind = request.effect.kind
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        guard macOSVersion >= kind.minimumMacOSVersion else {
            throw .effectUnavailable(kind, requiredMacOS: kind.minimumMacOSVersion)
        }
        if kind.isContentTransition, request.targetSymbolName == nil {
            throw .missingTargetSymbol(effect: kind)
        }
    }

    private static func effectOptions(for request: RenderRequest) -> SymbolEffectOptions {
        let timing = request.timing
        let options = SymbolEffectOptions.speed(timing.speed)
        guard request.effect.kind.isRepeatable else { return options }

        return switch timing.repeatBehavior {
        case .count(1):
            options.nonRepeating
        case .count(let count):
            options.repeat(.periodic(count, delay: timing.repeatDelay))
        case .forever:
            options.repeat(.periodic(delay: timing.repeatDelay))
        }
    }

    /// The fixed length of the effect section, or `nil` to stop once the symbol settles.
    private static func effectDuration(for request: RenderRequest) -> Double? {
        if let duration = request.timing.duration { return duration }
        if request.effect.kind.isRepeatable, request.timing.repeatBehavior == .forever {
            return Timing.defaultEndlessDuration
        }
        return nil
    }

    private static func frames(_ seconds: Double, fps: Int) -> Int {
        Int((seconds * Double(fps)).rounded())
    }
}
