//
//  CommonTypes.swift
//  OneBox - Common Types Module
//
//  Shared enum definitions used across all modules to avoid ambiguity
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Tool Type
public enum ToolType: String, CaseIterable, Identifiable {
    case imagesToPDF
    case pdfToImages
    case pdfMerge
    case pdfSplit
    case pdfCompress
    case pdfWatermark
    case pdfSign
    case pdfOrganize
    case imageResize
    case pdfRedact

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .imagesToPDF: return "Images → PDF"
        case .pdfToImages: return "PDF → Images"
        case .pdfMerge: return "Merge PDFs"
        case .pdfSplit: return "Split PDF"
        case .pdfCompress: return "Compress PDF"
        case .pdfWatermark: return "Watermark PDF"
        case .pdfSign: return "Sign PDF"
        case .pdfOrganize: return "Organize Pages"
        case .imageResize: return "Resize Images"
        case .pdfRedact: return "Redact PDF"
        }
    }

    public var description: String {
        switch self {
        case .imagesToPDF: return "Convert photos to PDF"
        case .pdfToImages: return "Extract pages as images"
        case .pdfMerge: return "Combine multiple PDFs"
        case .pdfSplit: return "Extract pages"
        case .pdfCompress: return "Reduce file size"
        case .pdfWatermark: return "Add text or image"
        case .pdfSign: return "Add signature"
        case .pdfOrganize: return "Reorder & delete pages"
        case .imageResize: return "Batch resize & compress"
        case .pdfRedact: return "Remove sensitive data"
        }
    }

    public var icon: String {
        switch self {
        case .imagesToPDF: return "photo.on.rectangle.angled"
        case .pdfToImages: return "photo.on.rectangle"
        case .pdfMerge: return "doc.on.doc"
        case .pdfSplit: return "scissors"
        case .pdfCompress: return "arrow.down.circle"
        case .pdfWatermark: return "waterbottle"
        case .pdfSign: return "signature"
        case .pdfOrganize: return "square.grid.2x2"
        case .imageResize: return "photo.stack"
        case .pdfRedact: return "eye.slash.fill"
        }
    }

    #if canImport(SwiftUI)
    @available(iOS 15.0, macOS 12.0, *)
    public var color: Color {
        switch self {
        case .imagesToPDF: return .blue
        case .pdfToImages: return .mint
        case .pdfMerge: return .purple
        case .pdfSplit: return .orange
        case .pdfCompress: return .green
        case .pdfWatermark: return .cyan
        case .pdfSign: return .indigo
        case .pdfOrganize: return .teal
        case .imageResize: return .pink
        case .pdfRedact: return .red
        }
    }
    #endif
}

public enum PDFOrientation: String, Codable, CaseIterable {
    case portrait
    case landscape
    
    public var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        }
    }
}

public enum CompressionQuality: String, Codable, CaseIterable {
    case maximum
    case high
    case medium
    case low
    
    public var displayName: String {
        switch self {
        case .maximum: return "Maximum Quality"
        case .high: return "High Quality"
        case .medium: return "Medium Quality"
        case .low: return "Low Quality"
        }
    }
    
    public var jpegQuality: Double {
        switch self {
        case .maximum: return 0.95
        case .high: return 0.75
        case .medium: return 0.50
        case .low: return 0.25  // Much more aggressive compression
        }
    }
}

public enum ImageFormat: String, Codable, CaseIterable {
    case jpeg
    case png
    case heic
    
    public var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }
}

public enum ImageQuality: String, Codable, CaseIterable {
    case lowest
    case low
    case medium
    case high
    case best
    
    public var displayName: String {
        switch self {
        case .lowest: return "Lowest"
        case .low: return "Low" 
        case .medium: return "Medium"
        case .high: return "High"
        case .best: return "Best"
        }
    }
    
    public var compressionValue: Double {
        switch self {
        case .lowest: return 0.1
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.8
        case .best: return 1.0
        }
    }
}

public enum WatermarkPosition: String, Codable, CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case middleLeft
    case center
    case middleRight
    case bottomLeft
    case bottomCenter
    case bottomRight
    case tiled
    
    public var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .middleLeft: return "Middle Left"
        case .center: return "Center"
        case .middleRight: return "Middle Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        case .tiled: return "Tiled"
        }
    }
}

public enum PDFPageSize: String, Codable, CaseIterable {
    case a4
    case letter
    case fit

    public var displayName: String {
        switch self {
        case .a4: return "A4"
        case .letter: return "Letter"
        case .fit: return "Fit to Image"
        }
    }

    public var size: CGSize? {
        switch self {
        case .a4: return CGSize(width: 595, height: 842) // A4 in points
        case .letter: return CGSize(width: 612, height: 792) // Letter in points
        case .fit: return nil
        }
    }
}