//
//  CoreVideo.swift
//  OneBox - CoreVideo Module
//
//  Provides video compression with preset and target-size modes
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Video Processor
public actor VideoProcessor {

    // MARK: - Compress Video
    public func compressVideo(
        _ videoURL: URL,
        preset: VideoCompressionPreset? = nil,
        targetSizeMB: Double? = nil,
        keepAudio: Bool = true,
        codec: VideoCodec = .h264,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let asset = AVURLAsset(url: videoURL)

        // Validate asset
        guard try await asset.load(.isReadable) else {
            throw VideoError.invalidVideo
        }

        if let targetSize = targetSizeMB {
            return try await compressToTargetSize(
                asset: asset,
                targetSizeMB: targetSize,
                keepAudio: keepAudio,
                codec: codec,
                progressHandler: progressHandler
            )
        } else if let preset = preset {
            return try await compressWithPreset(
                asset: asset,
                preset: preset,
                keepAudio: keepAudio,
                progressHandler: progressHandler
            )
        } else {
            throw VideoError.noCompressionSettingsProvided
        }
    }

    // MARK: - Preset-Based Compression
    private func compressWithPreset(
        asset: AVURLAsset,
        preset: VideoCompressionPreset,
        keepAudio: Bool,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let outputURL = temporaryOutputURL(prefix: "compressed_video")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: preset.avPresetName
        ) else {
            throw VideoError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true

        if !keepAudio {
            exportSession.audioMix = nil
        }

        // Monitor progress
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task {
                progressHandler(Double(exportSession.progress))
            }
        }

        await exportSession.export()
        progressTimer.invalidate()

        switch exportSession.status {
        case .completed:
            progressHandler(1.0)
            return outputURL
        case .failed:
            throw VideoError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        case .cancelled:
            throw VideoError.cancelled
        default:
            throw VideoError.exportFailed("Unexpected status: \(exportSession.status)")
        }
    }

    // MARK: - Target Size Compression
    private func compressToTargetSize(
        asset: AVURLAsset,
        targetSizeMB: Double,
        keepAudio: Bool,
        codec: VideoCodec,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        // Get video duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else {
            throw VideoError.invalidDuration
        }

        // Calculate target bitrate
        let targetBytes = targetSizeMB * 1_000_000
        let audioBitrate: Double = keepAudio ? 128_000 : 0 // 128 kbps for audio
        let availableBytes = targetBytes - (durationSeconds * audioBitrate / 8)
        let targetVideoBitrate = Int((availableBytes * 8 / durationSeconds) * 0.9) // 90% for safety

        guard targetVideoBitrate > 100_000 else {
            throw VideoError.targetSizeUnachievable
        }

        return try await compressWithCustomBitrate(
            asset: asset,
            videoBitrate: targetVideoBitrate,
            audioBitrate: keepAudio ? 128_000 : 0,
            codec: codec,
            progressHandler: progressHandler
        )
    }

    // MARK: - Custom Bitrate Compression
    private func compressWithCustomBitrate(
        asset: AVURLAsset,
        videoBitrate: Int,
        audioBitrate: Int,
        codec: VideoCodec,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let outputURL = temporaryOutputURL(prefix: "compressed_video")

        // Load tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let videoTrack = videoTracks.first else {
            throw VideoError.noVideoTrack
        }

        // Get video properties
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let frameRate = try await videoTrack.load(.nominalFrameRate)

        // Create reader and writer
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Configure video output
        let videoOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]

        let videoReaderOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: videoOutputSettings
        )
        reader.add(videoReaderOutput)

        // Configure video input
        let videoInputSettings: [String: Any] = [
            AVVideoCodecKey: codec.avCodec,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoMaxKeyFrameIntervalKey: Int(frameRate * 2),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoInputSettings
        )
        videoWriterInput.expectsMediaDataInRealTime = false
        videoWriterInput.transform = preferredTransform
        writer.add(videoWriterInput)

        // Configure audio if needed
        var audioWriterInput: AVAssetWriterInput?
        if audioBitrate > 0, let audioTrack = audioTracks.first {
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM
            ]

            let audioReaderOutput = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: audioOutputSettings
            )
            reader.add(audioReaderOutput)

            let audioInputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: audioBitrate
            ]

            let audioInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioInputSettings
            )
            audioInput.expectsMediaDataInRealTime = false
            writer.add(audioInput)
            audioWriterInput = audioInput
        }

        // Start reading and writing
        guard reader.startReading(), writer.startWriting() else {
            throw VideoError.compressionSetupFailed
        }

        writer.startSession(atSourceTime: .zero)

        // Process video
        await withCheckedContinuation { continuation in
            var videoFinished = false
            var audioFinished = audioBitrate == 0

            videoWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "video.queue")) {
                while videoWriterInput.isReadyForMoreMediaData {
                    if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                        videoWriterInput.append(sampleBuffer)

                        // Report progress
                        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let duration = asset.duration
                        let progress = CMTimeGetSeconds(currentTime) / CMTimeGetSeconds(duration)
                        progressHandler(progress * 0.95) // Reserve 5% for finalization
                    } else {
                        videoWriterInput.markAsFinished()
                        videoFinished = true
                        if audioFinished {
                            continuation.resume()
                        }
                        break
                    }
                }
            }

            // Process audio
            if let audioInput = audioWriterInput,
               let audioOutput = reader.outputs.first(where: { $0.mediaType == .audio }) as? AVAssetReaderTrackOutput {
                audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audio.queue")) {
                    while audioInput.isReadyForMoreMediaData {
                        if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                            audioInput.append(sampleBuffer)
                        } else {
                            audioInput.markAsFinished()
                            audioFinished = true
                            if videoFinished {
                                continuation.resume()
                            }
                            break
                        }
                    }
                }
            }
        }

        // Finish writing
        await writer.finishWriting()

        progressHandler(1.0)

        if writer.status == .completed {
            return outputURL
        } else {
            throw VideoError.exportFailed(writer.error?.localizedDescription ?? "Unknown error")
        }
    }

    // MARK: - Video Info
    public func getVideoInfo(_ videoURL: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: videoURL)

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let videoTrack = videoTracks.first else {
            throw VideoError.noVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let estimatedBitrate = try await videoTrack.load(.estimatedDataRate)

        let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        return VideoInfo(
            duration: durationSeconds,
            width: Int(naturalSize.width),
            height: Int(naturalSize.height),
            frameRate: Double(frameRate),
            bitrate: Int(estimatedBitrate),
            fileSize: fileSize,
            hasAudio: !audioTracks.isEmpty
        )
    }

    // MARK: - Estimate Output Size
    public func estimateOutputSize(
        for videoURL: URL,
        preset: VideoCompressionPreset
    ) async throws -> Double {
        let info = try await getVideoInfo(videoURL)

        // Rough estimation based on preset
        let estimatedBitrate: Double
        switch preset {
        case .highQuality:
            estimatedBitrate = 5_000_000 // 5 Mbps
        case .mediumQuality:
            estimatedBitrate = 2_500_000 // 2.5 Mbps
        case .lowQuality:
            estimatedBitrate = 1_000_000 // 1 Mbps
        case .socialMedia:
            estimatedBitrate = 1_500_000 // 1.5 Mbps
        }

        let estimatedBytes = (estimatedBitrate * info.duration) / 8
        return estimatedBytes / 1_000_000 // MB
    }

    // MARK: - Helper Methods
    private func temporaryOutputURL(prefix: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(prefix)_\(UUID().uuidString).mp4"
        return tempDir.appendingPathComponent(filename)
    }
}

// MARK: - Supporting Types
public enum VideoCompressionPreset: String, Codable, CaseIterable {
    case highQuality
    case mediumQuality
    case lowQuality
    case socialMedia

    var avPresetName: String {
        switch self {
        case .highQuality: return AVAssetExportPreset1920x1080
        case .mediumQuality: return AVAssetExportPreset1280x720
        case .lowQuality: return AVAssetExportPreset960x540
        case .socialMedia: return AVAssetExportPreset1280x720
        }
    }

    public var displayName: String {
        switch self {
        case .highQuality: return "High Quality (1080p)"
        case .mediumQuality: return "Medium Quality (720p)"
        case .lowQuality: return "Low Quality (540p)"
        case .socialMedia: return "Social Media (720p)"
        }
    }
}

public enum VideoCodec: String, Codable {
    case h264
    case hevc

    var avCodec: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .hevc: return .hevc
        }
    }

    var displayName: String {
        switch self {
        case .h264: return "H.264"
        case .hevc: return "H.265 (HEVC)"
        }
    }
}

public struct VideoInfo {
    public let duration: Double
    public let width: Int
    public let height: Int
    public let frameRate: Double
    public let bitrate: Int
    public let fileSize: Int64
    public let hasAudio: Bool

    public var fileSizeMB: Double {
        Double(fileSize) / 1_000_000
    }

    public var resolution: String {
        "\(width) × \(height)"
    }

    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Error
public enum VideoError: LocalizedError {
    case invalidVideo
    case invalidDuration
    case noVideoTrack
    case noCompressionSettingsProvided
    case exportSessionCreationFailed
    case exportFailed(String)
    case compressionSetupFailed
    case targetSizeUnachievable
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "Invalid or corrupted video file"
        case .invalidDuration:
            return "Could not determine video duration"
        case .noVideoTrack:
            return "No video track found in file"
        case .noCompressionSettingsProvided:
            return "No compression settings provided"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .compressionSetupFailed:
            return "Failed to setup compression"
        case .targetSizeUnachievable:
            return "Target size is too small for this video. Try a larger size."
        case .cancelled:
            return "Operation cancelled"
        }
    }
}
