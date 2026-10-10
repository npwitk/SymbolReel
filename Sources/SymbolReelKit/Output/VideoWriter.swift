import AVFoundation
import VideoToolbox

/// Encodes frames into a movie file with `AVAssetWriter`.
@MainActor
final class VideoWriter: FrameSink {
    private let url: URL
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let framesPerSecond: Int32
    private let matte: RGBAColor?
    private var frameIndex: Int64 = 0

    init(url: URL, format: OutputFormat, width: Int, height: Int, framesPerSecond: Int, matte: RGBAColor?) throws(SymbolReelError) {
        if format.requiresEvenDimensions, !width.isMultiple(of: 2) || !height.isMultiple(of: 2) {
            throw .invalidRequest("\(format.rawValue) needs an even width and height, but the canvas is \(width)×\(height).")
        }

        self.url = url
        self.framesPerSecond = Int32(framesPerSecond)
        self.matte = matte

        do {
            try? FileManager.default.removeItem(at: url)
            writer = try AVAssetWriter(outputURL: url, fileType: format.fileType)
        } catch {
            throw .encodingFailed("Couldn't create \(url.lastPathComponent): \(error.localizedDescription)")
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: format.codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: format.compressionProperties(width: width, height: height, framesPerSecond: framesPerSecond),
        ].compactMapValues { $0 }

        guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
            throw .encodingFailed("This Mac can't encode \(format.rawValue) at \(width)×\(height).")
        }

        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        writer.add(input)

        guard writer.startWriting() else {
            throw .encodingFailed(writer.error?.localizedDescription ?? "The writer couldn't start.")
        }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ frame: CGImage) throws(SymbolReelError) {
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw failure() }
            Thread.sleep(forTimeInterval: 0.001)
        }

        let pixelBuffer = try makePixelBuffer(from: frame)
        let time = CMTime(value: frameIndex, timescale: framesPerSecond)
        guard adaptor.append(pixelBuffer, withPresentationTime: time) else { throw failure() }
        frameIndex += 1
    }

    func finish() throws(SymbolReelError) {
        input.markAsFinished()
        // Close the last frame so it's shown for a full frame duration.
        writer.endSession(atSourceTime: CMTime(value: frameIndex, timescale: framesPerSecond))

        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        finished.wait()

        guard writer.status == .completed else { throw failure() }
    }

    func cancel() {
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: url)
    }

    private func makePixelBuffer(from frame: CGImage) throws(SymbolReelError) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        guard
            let pool = adaptor.pixelBufferPool,
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
            let buffer
        else {
            throw .encodingFailed("Couldn't allocate a pixel buffer.")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw .encodingFailed("Couldn't draw into a pixel buffer.")
        }

        let bounds = CGRect(x: 0, y: 0, width: context.width, height: context.height)
        context.clear(bounds)
        if let matte {
            context.setFillColor(matte.cgColor)
            context.fill(bounds)
        }
        context.draw(frame, in: bounds)
        return buffer
    }

    private func failure() -> SymbolReelError {
        .encodingFailed(writer.error?.localizedDescription ?? "The writer stopped with status \(writer.status.rawValue).")
    }
}

private extension OutputFormat {
    var fileType: AVFileType {
        switch self {
        case .mp4, .hevc: .mp4
        default: .mov
        }
    }

    var codec: AVVideoCodecType {
        switch self {
        case .prores: .proRes4444
        case .hevcAlpha: .hevcWithAlpha
        case .hevc: .hevc
        default: .h264
        }
    }

    var requiresEvenDimensions: Bool {
        self != .prores
    }

    func compressionProperties(width: Int, height: Int, framesPerSecond: Int) -> [String: Any]? {
        // Frames are rendered with premultiplied alpha, so tell the encoder to expect it.
        let alphaMode: [String: Any] = [kVTCompressionPropertyKey_AlphaChannelMode as String: kVTAlphaChannelMode_PremultipliedAlpha]

        switch self {
        case .prores:
            return alphaMode
        case .hevcAlpha:
            return alphaMode.merging([
                AVVideoQualityKey: 0.9,
                kVTCompressionPropertyKey_TargetQualityForAlpha as String: 0.9,
            ]) { $1 }
        case .mov, .mp4, .hevc:
            // Symbols are flat graphics, so a modest bitrate per pixel keeps edges clean.
            let bitsPerPixel = self == .hevc ? 0.08 : 0.12
            let bitrate = max(2_000_000, Int(Double(width * height * framesPerSecond) * bitsPerPixel))
            return [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: framesPerSecond,
                AVVideoMaxKeyFrameIntervalKey: framesPerSecond,
            ]
        case .gif, .png:
            return nil
        }
    }
}
