//
//  SignaturePlacement.swift
//  OneBox
//
//  Data models for signature placement system
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Signature Data
enum SignatureData: Codable, Equatable {
    case text(String)
    case image(Data)
    
    var displayName: String {
        switch self {
        case .text(let text): return text
        case .image: return "Drawn Signature"
        }
    }
    
    var isImage: Bool {
        if case .image = self {
            return true
        }
        return false
    }
}

// MARK: - Signature Placement
struct SignaturePlacement: Identifiable, Codable {
    let id: UUID
    var pageIndex: Int
    var position: CGPoint // Normalized coordinates (0.0-1.0)
    var size: CGSize // In screen pixels at placement time
    var signatureData: SignatureData
    var rotation: CGFloat = 0
    var viewWidthAtPlacement: CGFloat // Store actual view width for accurate size calculation

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        position: CGPoint,
        size: CGSize,
        signatureData: SignatureData,
        rotation: CGFloat = 0,
        viewWidthAtPlacement: CGFloat = 400.0
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.position = position
        self.size = size
        self.signatureData = signatureData
        self.rotation = rotation
        self.viewWidthAtPlacement = viewWidthAtPlacement
    }
    
    // Convert normalized position to PDF coordinates
    func pdfPosition(in pageBounds: CGRect) -> CGPoint {
        CGPoint(
            x: pageBounds.minX + (position.x * pageBounds.width),
            y: pageBounds.minY + ((1.0 - position.y) * pageBounds.height) // Flip Y
        )
    }
    
    // Get signature bounds in PDF coordinates
    func pdfBounds(in pageBounds: CGRect) -> CGRect {
        let origin = pdfPosition(in: pageBounds)
        return CGRect(
            origin: CGPoint(
                x: origin.x - size.width / 2,
                y: origin.y - size.height / 2
            ),
            size: size
        )
    }
}

// MARK: - Detected Signature Field
struct DetectedSignatureField: Identifiable {
    let id: UUID
    let pageIndex: Int
    let bounds: CGRect // In PDF coordinates
    let confidence: Double
    let label: String?
    
    // Convert to normalized coordinates for UI
    func normalizedBounds(in pageBounds: CGRect) -> CGRect {
        CGRect(
            x: (bounds.minX - pageBounds.minX) / pageBounds.width,
            y: 1.0 - ((bounds.maxY - pageBounds.minY) / pageBounds.height), // Flip Y
            width: bounds.width / pageBounds.width,
            height: bounds.height / pageBounds.height
        )
    }
}

