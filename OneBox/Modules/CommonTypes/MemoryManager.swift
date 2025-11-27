//
//  MemoryManager.swift
//  OneBox - CommonTypes Module
//
//  Memory pressure monitoring and management utilities
//

import Foundation
import UIKit

/// Manages memory monitoring and provides utilities for safe large file processing
@MainActor
public class MemoryManager {
    public static let shared = MemoryManager()
    
    private var memoryWarningObserver: NSObjectProtocol?
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Memory Monitoring
    
    /// Gets current available memory in bytes
    public func getAvailableMemory() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            // Fallback: return conservative estimate
            return 100 * 1024 * 1024 // 100MB
        }
        
        // Get total physical memory
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Estimate available memory (total - used)
        let usedMemory = Int64(info.resident_size)
        let availableMemory = Int64(totalMemory) - usedMemory
        
        return max(0, availableMemory)
    }
    
    /// Gets current memory usage in bytes
    public func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return 0
        }
        
        return Int64(info.resident_size)
    }
    
    /// Checks if there's enough memory for an operation
    /// - Parameters:
    ///   - requiredMemory: Memory needed in bytes
    ///   - safetyMargin: Safety margin multiplier (default 1.5x)
    /// - Returns: True if enough memory is available
    public func hasEnoughMemory(requiredMemory: Int64, safetyMargin: Double = 1.5) -> Bool {
        let available = getAvailableMemory()
        let requiredWithMargin = Int64(Double(requiredMemory) * safetyMargin)
        return available >= requiredWithMargin
    }
    
    /// Gets memory pressure level
    public func getMemoryPressureLevel() -> MemoryPressureLevel {
        let available = getAvailableMemory()
        let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
        let usagePercent = Double(totalMemory - available) / Double(totalMemory) * 100.0
        
        if usagePercent > 85 {
            return .critical
        } else if usagePercent > 70 {
            return .high
        } else if usagePercent > 50 {
            return .moderate
        } else {
            return .low
        }
    }
    
    // MARK: - File Size Validation
    
    /// Validates if a file can be safely processed based on size and available memory
    /// - Parameters:
    ///   - fileSize: Size of the file in bytes
    ///   - operationType: Type of operation (affects memory multiplier)
    /// - Returns: Validation result with recommendation
    public func validateFileSize(fileSize: Int64, operationType: OperationType) -> FileSizeValidation {
        let availableMemory = getAvailableMemory()
        let memoryPressure = getMemoryPressureLevel()
        
        // Estimate memory needed (file size * multiplier for processing)
        let memoryMultiplier: Double
        switch operationType {
        case .pdfRead:
            memoryMultiplier = 2.0 // PDFs need ~2x memory for processing
        case .pdfWrite:
            memoryMultiplier = 3.0 // Writing needs more memory
        case .imageProcess:
            memoryMultiplier = 4.0 // Images need ~4x memory (decoding + processing)
        case .pdfMerge:
            memoryMultiplier = 2.5 // Merging multiple PDFs
        case .pdfCompress:
            memoryMultiplier = 3.5 // Compression needs more memory
        }
        
        let estimatedMemoryNeeded = Int64(Double(fileSize) * memoryMultiplier)
        let hasEnoughMemory = availableMemory >= estimatedMemoryNeeded
        
        // Determine warning level
        let warningLevel: FileSizeWarningLevel
        if !hasEnoughMemory {
            warningLevel = .critical
        } else if memoryPressure == .critical || memoryPressure == .high {
            warningLevel = .high
        } else if fileSize > 50 * 1024 * 1024 { // > 50MB
            warningLevel = .moderate
        } else {
            warningLevel = .none
        }
        
        return FileSizeValidation(
            canProcess: hasEnoughMemory && memoryPressure != .critical,
            warningLevel: warningLevel,
            estimatedMemoryNeeded: estimatedMemoryNeeded,
            availableMemory: availableMemory,
            recommendation: generateRecommendation(
                fileSize: fileSize,
                estimatedMemory: estimatedMemoryNeeded,
                availableMemory: availableMemory,
                memoryPressure: memoryPressure,
                hasEnoughMemory: hasEnoughMemory
            )
        )
    }
    
    // MARK: - Adaptive Quality
    
    /// Calculates adaptive quality/resolution based on available memory
    /// - Parameters:
    ///   - preferredQuality: User's preferred quality (0.0-1.0)
    ///   - preferredResolution: User's preferred resolution in DPI
    ///   - fileSize: Size of file being processed
    /// - Returns: Adjusted quality and resolution that fits in available memory
    public func calculateAdaptiveQuality(
        preferredQuality: Double,
        preferredResolution: CGFloat,
        fileSize: Int64
    ) -> (quality: Double, resolution: CGFloat) {
        let memoryPressure = getMemoryPressureLevel()
        let availableMemory = getAvailableMemory()
        
        // Estimate memory needed at preferred settings
        let estimatedMemory = Int64(Double(fileSize) * 4.0) // Image processing multiplier
        
        var adjustedQuality = preferredQuality
        var adjustedResolution = preferredResolution
        
        // Adjust based on memory pressure
        switch memoryPressure {
        case .critical:
            // Aggressive reduction
            adjustedQuality = max(0.3, preferredQuality * 0.5)
            adjustedResolution = max(72, preferredResolution * 0.5)
        case .high:
            // Moderate reduction
            adjustedQuality = max(0.5, preferredQuality * 0.75)
            adjustedResolution = max(100, preferredResolution * 0.75)
        case .moderate:
            // Slight reduction
            adjustedQuality = max(0.7, preferredQuality * 0.9)
            adjustedResolution = max(150, preferredResolution * 0.9)
        case .low:
            // Use preferred settings
            break
        }
        
        // Further adjust if estimated memory exceeds available
        if estimatedMemory > availableMemory {
            let reductionFactor = Double(availableMemory) / Double(estimatedMemory)
            adjustedQuality = max(0.3, adjustedQuality * reductionFactor)
            adjustedResolution = max(72, adjustedResolution * CGFloat(reductionFactor))
        }
        
        return (adjustedQuality, adjustedResolution)
    }
    
    // MARK: - Private Helpers
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Memory warning received - could trigger cleanup if needed
            print("⚠️ MemoryManager: Memory warning received")
        }
    }
    
    private func generateRecommendation(
        fileSize: Int64,
        estimatedMemory: Int64,
        availableMemory: Int64,
        memoryPressure: MemoryPressureLevel,
        hasEnoughMemory: Bool
    ) -> String {
        if !hasEnoughMemory {
            return "This file requires approximately \(formatBytes(estimatedMemory)) of memory, but only \(formatBytes(availableMemory)) is available. Please close other apps or process a smaller file."
        }
        
        if memoryPressure == .critical {
            return "Device memory is critically low. Processing may be slow or fail. Consider closing other apps first."
        }
        
        if memoryPressure == .high {
            return "Device memory is high. Processing may be slower than usual."
        }
        
        if fileSize > 100 * 1024 * 1024 { // > 100MB
            return "Large file detected. Processing may take longer."
        }
        
        return "File size is acceptable for processing."
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

public enum MemoryPressureLevel {
    case low
    case moderate
    case high
    case critical
}

public enum OperationType {
    case pdfRead
    case pdfWrite
    case imageProcess
    case pdfMerge
    case pdfCompress
}

public enum FileSizeWarningLevel {
    case none
    case moderate
    case high
    case critical
}

public struct FileSizeValidation {
    public let canProcess: Bool
    public let warningLevel: FileSizeWarningLevel
    public let estimatedMemoryNeeded: Int64
    public let availableMemory: Int64
    public let recommendation: String
    
    public init(
        canProcess: Bool,
        warningLevel: FileSizeWarningLevel,
        estimatedMemoryNeeded: Int64,
        availableMemory: Int64,
        recommendation: String
    ) {
        self.canProcess = canProcess
        self.warningLevel = warningLevel
        self.estimatedMemoryNeeded = estimatedMemoryNeeded
        self.availableMemory = availableMemory
        self.recommendation = recommendation
    }
}

