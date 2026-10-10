import Foundation

/// A file format SymbolReel can write.
public enum OutputFormat: String, CaseIterable, Sendable {
    /// Apple ProRes 4444 with alpha in a QuickTime movie. Best for editing in Final Cut Pro,
    /// Motion, After Effects, Premiere and DaVinci Resolve.
    case prores
    /// HEVC with alpha in a QuickTime movie. Much smaller than ProRes and plays in Safari and Keynote.
    case hevcAlpha = "hevc-alpha"
    /// H.264 in a QuickTime movie, on an opaque background.
    case mov
    /// H.264 in an MPEG-4 file, on an opaque background. Plays everywhere.
    case mp4
    /// HEVC in an MPEG-4 file, on an opaque background.
    case hevc
    /// An animated GIF on an opaque background.
    case gif
    /// A folder of numbered PNG frames with alpha.
    case png

    public var supportsAlpha: Bool {
        switch self {
        case .prores, .hevcAlpha, .png: true
        case .mov, .mp4, .hevc, .gif: false
        }
    }

    /// The suffix appended to a base name, including the extension.
    public var fileSuffix: String {
        switch self {
        case .prores: "-prores4444.mov"
        case .hevcAlpha: "-hevc-alpha.mov"
        case .mov: ".mov"
        case .mp4: ".mp4"
        case .hevc: "-hevc.mp4"
        case .gif: ".gif"
        case .png: "-frames"
        }
    }

    public var summary: String {
        switch self {
        case .prores: "ProRes 4444 .mov with transparency (for video editors)"
        case .hevcAlpha: "HEVC .mov with transparency (small, for Safari/Keynote)"
        case .mov: "H.264 .mov on a solid background"
        case .mp4: "H.264 .mp4 on a solid background"
        case .hevc: "HEVC .mp4 on a solid background"
        case .gif: "Animated GIF on a solid background"
        case .png: "Folder of PNG frames with transparency"
        }
    }
}

/// A format paired with the location to write it to.
public struct OutputTarget: Sendable {
    public var format: OutputFormat
    public var url: URL

    public init(format: OutputFormat, url: URL) {
        self.format = format
        self.url = url
    }
}
