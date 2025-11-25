//
//  SignatureFieldDetectionService.swift
//  OneBox
//
//  Detects signature fields in PDF documents using Vision framework
//

import Foundation
import PDFKit
import Vision
import CoreGraphics

@MainActor
class SignatureFieldDetectionService {
    static let shared = SignatureFieldDetectionService()
    
    private init() {}
    
    /// Detects signature fields across all pages of a PDF document
    func detectSignatureFields(in document: PDFDocument) async -> [DetectedSignatureField] {
        var allFields: [DetectedSignatureField] = []
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            let pageFields = await detectSignatureFields(in: page, pageIndex: pageIndex)
            allFields.append(contentsOf: pageFields)
        }
        
        return allFields
    }
    
    /// Detects signature fields on a single PDF page
    private func detectSignatureFields(in page: PDFPage, pageIndex: Int) async -> [DetectedSignatureField] {
        var fields: [DetectedSignatureField] = []
        
        // Get page thumbnail for Vision processing
        let pageBounds = page.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 612, height: 792) // Standard PDF size
        let pageImage = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        guard let cgImage = pageImage.cgImage else {
            return fields
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Perform text recognition to find signature-related labels
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        
        // Detect rectangles that might be signature fields
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.minimumAspectRatio = 0.1
        rectangleRequest.maximumAspectRatio = 10.0
        rectangleRequest.minimumSize = 0.01
        rectangleRequest.maximumObservations = 30
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([textRequest, rectangleRequest])
            
            // Extract text labels
            var detectedLabels: [(String, CGRect, Double)] = []
            if let textResults = textRequest.results {
                for observation in textResults {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    let text = topCandidate.string.lowercased()
                    let boundingBox = observation.boundingBox
                    let confidence = topCandidate.confidence
                    
                    // Check if text is signature-related
                    if text.contains("signature") || 
                       text.contains("sign") || 
                       text.contains("sign here") ||
                       text.contains("signature:") ||
                       text.contains("signature line") {
                        
                        // Convert normalized coordinates to PDF coordinates
                        let pdfBounds = CGRect(
                            x: boundingBox.origin.x * pageBounds.width,
                            y: (1 - boundingBox.origin.y - boundingBox.height) * pageBounds.height,
                            width: boundingBox.width * pageBounds.width,
                            height: boundingBox.height * pageBounds.height
                        )
                        
                        detectedLabels.append((text, pdfBounds, Double(confidence)))
                    }
                }
            }
            
            // Process rectangles as potential signature fields
            let rectangleResults = rectangleRequest.results
            if let rectangles = rectangleResults {
                for observation in rectangles {
                    let boundingBox = observation.boundingBox
                    let confidence = Double(observation.confidence)
                    
                    // Convert normalized coordinates to PDF coordinates
                    let pdfBounds = CGRect(
                        x: boundingBox.origin.x * pageBounds.width,
                        y: (1 - boundingBox.origin.y - boundingBox.height) * pageBounds.height,
                        width: boundingBox.width * pageBounds.width,
                        height: boundingBox.height * pageBounds.height
                    )
                    
                    // Check if rectangle is near signature-related text
                    let nearbyLabel = findNearestSignatureLabel(for: pdfBounds, in: detectedLabels)
                    
                    // Determine if this is likely a signature field
                    let isSignatureField = nearbyLabel != nil || 
                                          (pdfBounds.width > 100 && pdfBounds.height > 20 && pdfBounds.height < 100)
                    
                    if isSignatureField {
                        let field = DetectedSignatureField(
                            id: UUID(),
                            pageIndex: pageIndex,
                            bounds: pdfBounds,
                            confidence: confidence * (nearbyLabel != nil ? 0.9 : 0.6), // Higher confidence if near label
                            label: nearbyLabel
                        )
                        fields.append(field)
                    }
                }
            }
            
            // Also create fields directly from signature-related text labels
            for (label, bounds, confidence) in detectedLabels {
                // Look for nearby rectangle
                var hasNearbyRectangle = false
                if let rectangles = rectangleResults {
                    hasNearbyRectangle = rectangles.contains { rect in
                        let rectBounds = CGRect(
                            x: rect.boundingBox.origin.x * pageBounds.width,
                            y: (1 - rect.boundingBox.origin.y - rect.boundingBox.height) * pageBounds.height,
                            width: rect.boundingBox.width * pageBounds.width,
                            height: rect.boundingBox.height * pageBounds.height
                        )
                        return rectBounds.intersects(bounds.insetBy(dx: -20, dy: -20))
                    }
                }
                
                if !hasNearbyRectangle {
                    // Create a signature field based on text position
                    // Typical signature field size
                    let signatureFieldBounds = CGRect(
                        x: bounds.minX,
                        y: bounds.maxY + 5, // Below the label
                        width: 200, // Default width
                        height: 50  // Default height
                    )
                    
                    let field = DetectedSignatureField(
                        id: UUID(),
                        pageIndex: pageIndex,
                        bounds: signatureFieldBounds,
                        confidence: confidence * 0.7,
                        label: label.capitalized
                    )
                    fields.append(field)
                }
            }
            
        } catch {
            print("Signature field detection error: \(error.localizedDescription)")
        }
        
        return fields
    }
    
    private func findNearestSignatureLabel(for bounds: CGRect, in labels: [(String, CGRect, Double)]) -> String? {
        var nearestLabel: String?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        
        let fieldCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        for (label, labelBounds, _) in labels {
            let labelCenter = CGPoint(x: labelBounds.midX, y: labelBounds.midY)
            let distance = sqrt(pow(fieldCenter.x - labelCenter.x, 2) + pow(fieldCenter.y - labelCenter.y, 2))
            
            // Consider labels within 100 points
            if distance < nearestDistance && distance < 100 {
                nearestDistance = distance
                nearestLabel = label.capitalized
            }
        }
        
        return nearestLabel
    }
}

