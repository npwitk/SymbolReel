import CoreGraphics

/// Receives rendered frames in order and writes them somewhere.
@MainActor
protocol FrameSink {
    func append(_ frame: CGImage) throws(SymbolReelError)
    func finish() throws(SymbolReelError)
    /// Removes any partially written output after a failure.
    func cancel()
}

extension OutputTarget {
    @MainActor
    func makeSink(canvas: Canvas, framesPerSecond: Int) throws(SymbolReelError) -> any FrameSink {
        // Formats without alpha need an opaque background, even if the canvas is transparent.
        let matte = format.supportsAlpha ? nil : (canvas.background ?? Canvas.opaqueFallbackBackground)

        return switch format {
        case .prores, .hevcAlpha, .mov, .mp4, .hevc:
            try VideoWriter(url: url, format: format, width: canvas.width, height: canvas.height, framesPerSecond: framesPerSecond, matte: matte)
        case .gif:
            try GIFWriter(url: url, framesPerSecond: framesPerSecond, matte: matte ?? .white)
        case .png:
            try PNGSequenceWriter(directory: url)
        }
    }
}

extension CGImage {
    /// Returns the image composited over an opaque color.
    func flattened(onto color: RGBAColor) -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return self }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(color.cgColor)
        context.fill(bounds)
        context.draw(self, in: bounds)
        return context.makeImage() ?? self
    }
}
