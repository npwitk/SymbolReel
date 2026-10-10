import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes an endlessly looping animated GIF.
@MainActor
final class GIFWriter: FrameSink {
    /// Browsers clamp GIF frame delays below 20 ms, so frames are dropped to stay at or under 50 fps.
    private static let maximumFramesPerSecond = 50

    private let url: URL
    private let matte: RGBAColor
    private let frameStride: Int
    private let frameDelay: Double
    private var frames: [CGImage] = []
    private var frameIndex = 0

    init(url: URL, framesPerSecond: Int, matte: RGBAColor) throws(SymbolReelError) {
        self.url = url
        self.matte = matte
        frameStride = max(1, Int((Double(framesPerSecond) / Double(Self.maximumFramesPerSecond)).rounded(.up)))
        frameDelay = Double(frameStride) / Double(framesPerSecond)
    }

    func append(_ frame: CGImage) throws(SymbolReelError) {
        defer { frameIndex += 1 }
        guard frameIndex.isMultiple(of: frameStride) else { return }
        frames.append(frame.flattened(onto: matte))
    }

    func finish() throws(SymbolReelError) {
        try? FileManager.default.removeItem(at: url)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            throw .encodingFailed("Couldn't create \(url.lastPathComponent).")
        }

        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)

        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime: frameDelay,
            ],
        ] as CFDictionary
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw .encodingFailed("Couldn't write \(url.lastPathComponent).")
        }
    }

    func cancel() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Writes each frame as a numbered PNG with alpha.
@MainActor
final class PNGSequenceWriter: FrameSink {
    private let directory: URL
    private var frameIndex = 0

    init(directory: URL) throws(SymbolReelError) {
        self.directory = directory
        do {
            try? FileManager.default.removeItem(at: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw .encodingFailed("Couldn't create \(directory.path): \(error.localizedDescription)")
        }
    }

    func append(_ frame: CGImage) throws(SymbolReelError) {
        let url = directory.appending(path: String(format: "frame_%05d.png", frameIndex))
        guard
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw .encodingFailed("Couldn't create \(url.lastPathComponent).")
        }
        CGImageDestinationAddImage(destination, frame, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw .encodingFailed("Couldn't write \(url.lastPathComponent).")
        }
        frameIndex += 1
    }

    func finish() throws(SymbolReelError) {}

    func cancel() {
        try? FileManager.default.removeItem(at: directory)
    }
}
