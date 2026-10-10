import AppKit
import ArgumentParser
import SymbolReelKit

struct RenderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Render one or more symbols with one or more effects."
    )

    @Argument(help: "The SF Symbols to render, e.g. wifi or heart.fill.")
    var symbols: [String]

    @Option(name: .shortAndLong, help: "An effect to render; repeat for several. See `symbolreel effects`. (default: bounce)", transform: parseEffect)
    var effect: [SymbolEffectSpec] = [SymbolEffectSpec(kind: .bounce)]

    @Option(name: .long, help: "The symbol to transition to, for the replace effect.")
    var to: String?

    @Option(name: .shortAndLong, help: "Output formats, comma-separated: \(OutputFormat.allCases.map(\.rawValue).joined(separator: ", ")). (default: prores)", transform: parseFormats)
    var format: [[OutputFormat]] = [[.prores]]

    @Option(name: .shortAndLong, help: "An output folder, or a file path when rendering a single file.")
    var output: String = "."

    @OptionGroup(title: "Appearance")
    var appearance: AppearanceOptions

    @OptionGroup(title: "Canvas")
    var canvas: CanvasOptions

    @OptionGroup(title: "Timing")
    var timing: TimingOptions

    @Flag(name: .shortAndLong, help: "Only print errors.")
    var quiet = false

    private var formats: [OutputFormat] { format.flatMap(\.self).uniqued() }

    func validate() throws {
        if effect.contains(where: \.kind.isContentTransition), to == nil {
            throw ValidationError("The replace effect needs a target symbol. Pass one with --to.")
        }
        _ = try OutputPlanner(path: output, formats: formats, requestCount: symbols.count * effect.count)
    }

    func run() throws {
        let requests = symbols.flatMap { symbol in
            effect.map { effect in
                RenderRequest(
                    symbolName: symbol,
                    effect: effect,
                    targetSymbolName: effect.kind.isContentTransition ? to : nil,
                    appearance: appearance.appearance,
                    canvas: canvas.canvas,
                    timing: timing.timing
                )
            }
        }
        let destinations = try OutputPlanner(path: output, formats: formats, requestCount: requests.count)
        try destinations.createDirectories()

        try MainActor.assumeIsolated {
            for request in requests {
                let targets = try destinations.targets(for: request)
                let result = try SymbolReel.render(request, to: targets)
                guard !quiet else { continue }

                let title = [request.symbolName, request.targetSymbolName].compactMap(\.self).joined(separator: " → ")
                print("✓ \(title) · \(request.effect) · \(result.frameCount) frames, \(String(format: "%.2f", result.duration)) s")
                for target in targets {
                    print("    \(target.url.relativePath)")
                }
            }
        }
    }
}

// MARK: - Option groups

struct AppearanceOptions: ParsableArguments {
    @Option(help: "monochrome, hierarchical, palette or multicolor. (default: monochrome)", transform: parseRenderingMode)
    var rendering: SymbolAppearance.RenderingMode = .monochrome

    @Option(name: .shortAndLong, help: "The symbol color as hex or a name (blue, orange, …). Comma-separate several for palette mode. (default: black)", transform: parseColors)
    var color: [RGBAColor] = [.black]

    @Option(help: "ultralight, thin, light, regular, medium, semibold, bold, heavy or black. (default: regular)", transform: parseWeight)
    var weight: NSFont.Weight = .regular

    @Option(help: "small, medium or large. (default: large)", transform: parseScale)
    var scale: NSImage.SymbolScale = .large

    @Option(help: "The value from 0 to 1 for symbols with variable rendering.")
    var variableValue: Double?

    var appearance: SymbolAppearance {
        SymbolAppearance(renderingMode: rendering, colors: color, weight: weight, scale: scale, variableValue: variableValue)
    }
}

struct CanvasOptions: ParsableArguments {
    @Option(help: "Output size in pixels, as 512 or 1920x1080. (default: 512)", transform: parseSize)
    var size: CanvasSize = CanvasSize(width: 512, height: 512)

    @Option(help: "Space around the symbol as a fraction of the shorter side (0–0.49).")
    var padding: Double = 0.2

    @Option(help: "Background color as hex or a name. Transparent when omitted; formats without alpha use white.", transform: parseColor)
    var background: RGBAColor?

    var canvas: Canvas {
        Canvas(width: size.width, height: size.height, padding: padding, background: background)
    }
}

struct TimingOptions: ParsableArguments {
    @Option(help: "Frames per second.")
    var fps: Int = 60

    @Option(help: "Length of the effect in seconds. Defaults to when the effect settles, or 3 s for --repeat forever.")
    var duration: Double?

    @Option(help: "Seconds to hold the resting symbol before the effect.")
    var leadIn: Double = 0.25

    @Option(help: "Seconds to hold the final frame after the effect.")
    var tail: Double = 0.25

    @Option(name: .customLong("repeat"), help: "How many times to play the effect, or `forever`. (default: 1)", transform: parseRepeat)
    var repeatBehavior: Timing.Repeat = .count(1)

    @Option(help: "Seconds to pause between repetitions.")
    var repeatDelay: Double?

    @Option(help: "Playback speed multiplier.")
    var speed: Double = 1

    var timing: Timing {
        Timing(
            framesPerSecond: fps,
            leadIn: leadIn,
            duration: duration,
            tail: tail,
            repeatBehavior: repeatBehavior,
            repeatDelay: repeatDelay,
            speed: speed
        )
    }
}

// MARK: - Output paths

/// Decides where each rendered file goes.
struct OutputPlanner {
    private let directory: URL?
    private let singleFile: URL?
    private let formats: [OutputFormat]

    init(path: String, formats: [OutputFormat], requestCount: Int) throws {
        let url = URL(filePath: path)
        self.formats = formats

        // A path with an extension names the file directly, but only when there's exactly one file.
        if !url.pathExtension.isEmpty, !url.hasDirectoryPath {
            guard requestCount == 1, formats.count == 1 else {
                throw ValidationError("--output can only be a file path when rendering one symbol, one effect and one format. Pass a folder instead.")
            }
            directory = nil
            singleFile = url
        } else {
            directory = url
            singleFile = nil
        }
    }

    func createDirectories() throws {
        let folder = directory ?? singleFile!.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func targets(for request: RenderRequest) throws -> [OutputTarget] {
        if let singleFile, let format = formats.first {
            return [OutputTarget(format: format, url: singleFile)]
        }
        return formats.map { format in
            OutputTarget(format: format, url: directory!.appending(path: request.suggestedBaseName + format.fileSuffix))
        }
    }
}

// MARK: - Argument parsing

struct CanvasSize {
    var width: Int
    var height: Int
}

private func parseEffect(_ string: String) throws -> SymbolEffectSpec {
    do {
        return try SymbolEffectSpec(parsing: string)
    } catch {
        throw ValidationError(error.description)
    }
}

private func parseFormats(_ string: String) throws -> [OutputFormat] {
    try string.split(separator: ",").map { name in
        let name = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard let format = OutputFormat(rawValue: name) else {
            throw ValidationError("Unknown format '\(name)'. Available: \(OutputFormat.allCases.map(\.rawValue).joined(separator: ", ")).")
        }
        return format
    }
}

private func parseColor(_ string: String) throws -> RGBAColor {
    guard let color = RGBAColor(string: string) else {
        throw ValidationError("'\(string)' isn't a color. Use hex like #007AFF or a name like blue.")
    }
    return color
}

private func parseColors(_ string: String) throws -> [RGBAColor] {
    try string.split(separator: ",").map { try parseColor(String($0)) }
}

private func parseRenderingMode(_ string: String) throws -> SymbolAppearance.RenderingMode {
    guard let mode = SymbolAppearance.RenderingMode(rawValue: string.lowercased()) else {
        throw ValidationError("Unknown rendering mode '\(string)'. Use monochrome, hierarchical, palette or multicolor.")
    }
    return mode
}

private func parseWeight(_ string: String) throws -> NSFont.Weight {
    let weights: [String: NSFont.Weight] = [
        "ultralight": .ultraLight, "thin": .thin, "light": .light, "regular": .regular, "medium": .medium,
        "semibold": .semibold, "bold": .bold, "heavy": .heavy, "black": .black,
    ]
    guard let weight = weights[string.lowercased()] else {
        throw ValidationError("Unknown weight '\(string)'. Use one of: \(weights.keys.sorted().joined(separator: ", ")).")
    }
    return weight
}

private func parseScale(_ string: String) throws -> NSImage.SymbolScale {
    switch string.lowercased() {
    case "small": .small
    case "medium": .medium
    case "large": .large
    default: throw ValidationError("Unknown scale '\(string)'. Use small, medium or large.")
    }
}

private func parseSize(_ string: String) throws -> CanvasSize {
    let parts = string.lowercased().split(separator: "x").compactMap { Int($0) }
    switch parts.count {
    case 1: return CanvasSize(width: parts[0], height: parts[0])
    case 2: return CanvasSize(width: parts[0], height: parts[1])
    default: throw ValidationError("'\(string)' isn't a size. Use 512 or 1920x1080.")
    }
}

private func parseRepeat(_ string: String) throws -> Timing.Repeat {
    if string.lowercased() == "forever" { return .forever }
    guard let count = Int(string), count >= 1 else {
        throw ValidationError("--repeat takes a number of at least 1, or `forever`.")
    }
    return .count(count)
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
