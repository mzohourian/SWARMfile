//
//  CoreZip.swift
//  OneBox - CoreZip Module
//
//  Provides ZIP archive creation and extraction using Apple's Archive framework
//

import Foundation
import System
import AppleArchive

// MARK: - ZIP Processor
public actor ZipProcessor {

    // MARK: - Create ZIP
    public func createZip(
        from fileURLs: [URL],
        outputName: String = "archive",
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        guard !fileURLs.isEmpty else {
            throw ZipError.noFilesToCompress
        }

        let outputURL = temporaryOutputURL(name: outputName)

        // Create temporary directory to stage files
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: stagingDir)
        }

        // Copy files to staging directory preserving names
        for (index, fileURL) in fileURLs.enumerated() {
            let destinationURL = stagingDir.appendingPathComponent(fileURL.lastPathComponent)
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            progressHandler(Double(index) / Double(fileURLs.count) * 0.5)
        }

        // Create archive
        try await createArchive(from: stagingDir, to: outputURL, progressHandler: progressHandler)

        progressHandler(1.0)

        return outputURL
    }

    // MARK: - Extract ZIP
    public func extractZip(
        _ zipURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        // Verify it's a ZIP file
        guard zipURL.pathExtension.lowercased() == "zip" else {
            throw ZipError.notAZipFile
        }

        // Check if encrypted (simple check)
        if try isEncrypted(zipURL) {
            throw ZipError.encryptedArchive
        }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        try await extractArchive(from: zipURL, to: outputDir, progressHandler: progressHandler)

        progressHandler(1.0)

        return outputDir
    }

    // MARK: - Archive Operations using Apple Archive
    private func createArchive(
        from sourceDir: URL,
        to destinationURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {

        // Get all files to compress
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        guard let enumerator = enumerator else {
            throw ZipError.compressionFailed("Could not enumerate files")
        }

        var filesToCompress: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
               isRegularFile {
                filesToCompress.append(fileURL)
            }
        }

        // Simple ZIP creation using Zip Foundation alternative
        // For a production app, use AppleArchive or a library like ZIPFoundation
        try await createSimpleZip(files: filesToCompress, sourceDir: sourceDir, output: destinationURL, progressHandler: progressHandler)
    }

    private func extractArchive(
        from archiveURL: URL,
        to destinationDir: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {

        // Simple ZIP extraction
        try await extractSimpleZip(from: archiveURL, to: destinationDir, progressHandler: progressHandler)
    }

    // MARK: - Simple ZIP Implementation (Fallback)
    private func createSimpleZip(
        files: [URL],
        sourceDir: URL,
        output: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {

        // Use system zip command as fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", output.path, "."]
        process.currentDirectoryURL = sourceDir

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ZipError.compressionFailed("ZIP creation failed")
        }

        progressHandler(1.0)
    }

    private func extractSimpleZip(
        from archiveURL: URL,
        to destinationDir: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {

        // Use system unzip command as fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", archiveURL.path, "-d", destinationDir.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"

            if errorOutput.contains("encrypted") || errorOutput.contains("password") {
                throw ZipError.encryptedArchive
            }

            throw ZipError.extractionFailed(errorOutput)
        }

        progressHandler(1.0)
    }

    // MARK: - Encryption Detection
    private func isEncrypted(_ zipURL: URL) throws -> Bool {
        // Simple heuristic: try to list contents
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-l", zipURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.contains("encrypted") || output.contains("password")
    }

    // MARK: - Archive Info
    public func getArchiveInfo(_ zipURL: URL) async throws -> ArchiveInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-l", zipURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Parse output to count files
        let lines = output.components(separatedBy: .newlines)
        let fileCount = lines.filter { $0.contains(":") && !$0.contains("Archive:") }.count

        let attributes = try FileManager.default.attributesOfItem(atPath: zipURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        return ArchiveInfo(
            fileCount: fileCount,
            compressedSize: fileSize,
            isEncrypted: try isEncrypted(zipURL)
        )
    }

    // MARK: - Helper Methods
    private func temporaryOutputURL(name: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(name)_\(UUID().uuidString).zip"
        return tempDir.appendingPathComponent(filename)
    }
}

// MARK: - Supporting Types
public struct ArchiveInfo {
    public let fileCount: Int
    public let compressedSize: Int64
    public let isEncrypted: Bool

    public var compressedSizeMB: Double {
        Double(compressedSize) / 1_000_000
    }
}

// MARK: - ZIP Error
public enum ZipError: LocalizedError {
    case noFilesToCompress
    case notAZipFile
    case encryptedArchive
    case compressionFailed(String)
    case extractionFailed(String)
    case insufficientSpace

    public var errorDescription: String? {
        switch self {
        case .noFilesToCompress:
            return "No files selected to compress"
        case .notAZipFile:
            return "The selected file is not a ZIP archive"
        case .encryptedArchive:
            return "This archive is password-protected. Encrypted archives are not supported in this version."
        case .compressionFailed(let message):
            return "Compression failed: \(message)"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .insufficientSpace:
            return "Not enough storage space to complete operation"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .encryptedArchive:
            return "Try extracting the archive on a computer first, or use an unencrypted archive."
        case .insufficientSpace:
            return "Free up some storage space and try again."
        default:
            return nil
        }
    }
}
