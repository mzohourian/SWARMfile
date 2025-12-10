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
        let pageBounds = page.bounds(for: .mediaBox)
        
        // STEP 1: Check for actual PDF form field annotations (most reliable)
        let annotations = page.annotations
        for annotation in annotations {
            // Check if this is a widget annotation (form field)
            if annotation.type == "Widget" {
                // Check if it's a signature field
                if let fieldName = annotation.fieldName?.lowercased(),
                   (fieldName.contains("signature") || fieldName.contains("sign")) {
                    // This is an actual PDF form signature field
                    let annotationBounds = annotation.bounds
                    let field = DetectedSignatureField(
                        id: UUID(),
                        pageIndex: pageIndex,
                        bounds: annotationBounds,
                        confidence: 0.95, // Very high confidence for actual form fields
                        label: annotation.fieldName ?? "Signature Field"
                    )
                    fields.append(field)
                    continue
                }
            }
        }
        
        // STEP 2: Use Vision framework to detect signature lines and related text
        // Only proceed if we haven't found form fields (to avoid duplicates)
        guard fields.isEmpty else {
            return fields
        }
        
        // Get page thumbnail for Vision processing
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
        // Support multiple languages for international documents
        textRequest.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "ar-SA", "fa-IR"]

        // Detect rectangles (for signature boxes)
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.minimumAspectRatio = 2.0 // Signature fields are typically wide (width > 2x height)
        rectangleRequest.maximumAspectRatio = 20.0
        rectangleRequest.minimumSize = 0.05 // Larger minimum size to avoid small boxes
        rectangleRequest.maximumObservations = 10 // Fewer observations for better quality
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([textRequest, rectangleRequest])
            
            // Extract signature-related text labels with high confidence
            var detectedLabels: [(String, CGRect, Double)] = []
            if let textResults = textRequest.results {
                for observation in textResults {
                    guard let topCandidate = observation.topCandidates(1).first,
                          topCandidate.confidence > 0.7 else { continue } // Only high-confidence text
                    
                    let text = topCandidate.string.lowercased().trimmingCharacters(in: .whitespaces)
                    let boundingBox = observation.boundingBox
                    let confidence = Double(topCandidate.confidence)
                    
                    // More specific signature-related keywords
                    let signatureKeywords = ["signature", "sign here", "signature:", "signature line", 
                                           "signature block", "signature field", "sign below"]
                    let isSignatureText = signatureKeywords.contains { text.contains($0) }
                    
                    if isSignatureText {
                        // Convert normalized coordinates to PDF coordinates
                        let pdfBounds = CGRect(
                            x: boundingBox.origin.x * pageBounds.width,
                            y: (1 - boundingBox.origin.y - boundingBox.height) * pageBounds.height,
                            width: boundingBox.width * pageBounds.width,
                            height: boundingBox.height * pageBounds.height
                        )
                        
                        detectedLabels.append((text, pdfBounds, confidence))
                    }
                }
            }
            
            // Process rectangles - only accept those that look like signature fields
            if let rectangles = rectangleRequest.results {
                for observation in rectangles {
                    let boundingBox = observation.boundingBox
                    let confidence = Double(observation.confidence)
                    
                    // Only process high-confidence rectangles
                    guard confidence > 0.7 else { continue }
                    
                    // Convert normalized coordinates to PDF coordinates
                    let pdfBounds = CGRect(
                        x: boundingBox.origin.x * pageBounds.width,
                        y: (1 - boundingBox.origin.y - boundingBox.height) * pageBounds.height,
                        width: boundingBox.width * pageBounds.width,
                        height: boundingBox.height * pageBounds.height
                    )
                    
                    // Signature fields are typically:
                    // - Wide (width > 2x height)
                    // - Height between 20-80 points
                    // - Width between 100-400 points
                    let aspectRatio = pdfBounds.width / pdfBounds.height
                    let isValidSignatureField = aspectRatio > 2.0 &&
                                              pdfBounds.height >= 20 &&
                                              pdfBounds.height <= 80 &&
                                              pdfBounds.width >= 100 &&
                                              pdfBounds.width <= 400
                    
                    if !isValidSignatureField {
                        continue
                    }
                    
                    // Check if rectangle is near signature-related text
                    let nearbyLabel = findNearestSignatureLabel(for: pdfBounds, in: detectedLabels, maxDistance: 50)
                    
                    // Only add if near signature text (high confidence) or very high rectangle confidence
                    if nearbyLabel != nil || confidence > 0.85 {
                        let field = DetectedSignatureField(
                            id: UUID(),
                            pageIndex: pageIndex,
                            bounds: pdfBounds,
                            confidence: nearbyLabel != nil ? 0.85 : confidence * 0.8,
                            label: nearbyLabel
                        )
                        fields.append(field)
                    }
                }
            }
            
            // Create fields from signature-related text labels only if no rectangle found nearby
            for (label, bounds, confidence) in detectedLabels {
                // Check if we already have a field near this label
                let hasNearbyField = fields.contains { field in
                    let distance = sqrt(
                        pow(field.bounds.midX - bounds.midX, 2) +
                        pow(field.bounds.midY - bounds.midY, 2)
                    )
                    return distance < 100
                }
                
                if !hasNearbyField && confidence > 0.8 {
                    // Create a signature field below the label
                    let signatureFieldBounds = CGRect(
                        x: bounds.minX,
                        y: bounds.maxY + 10, // Below the label
                        width: min(250, pageBounds.width - bounds.minX - 20), // Reasonable width
                        height: 50  // Standard signature height
                    )
                    
                    // Ensure bounds are within page
                    if signatureFieldBounds.maxX <= pageBounds.maxX &&
                       signatureFieldBounds.maxY <= pageBounds.maxY {
                        let field = DetectedSignatureField(
                            id: UUID(),
                            pageIndex: pageIndex,
                            bounds: signatureFieldBounds,
                            confidence: confidence * 0.75,
                            label: label.capitalized
                        )
                        fields.append(field)
                    }
                }
            }
            
        } catch {
            print("Signature field detection error: \(error.localizedDescription)")
        }
        
        // Filter to only high-confidence fields (0.75+)
        return fields.filter { $0.confidence >= 0.75 }
    }
    
    private func findNearestSignatureLabel(for bounds: CGRect, in labels: [(String, CGRect, Double)], maxDistance: CGFloat = 50) -> String? {
        var nearestLabel: String?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        
        let fieldCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        for (label, labelBounds, _) in labels {
            let labelCenter = CGPoint(x: labelBounds.midX, y: labelBounds.midY)
            let distance = sqrt(pow(fieldCenter.x - labelCenter.x, 2) + pow(fieldCenter.y - labelCenter.y, 2))
            
            // Consider labels within maxDistance (default 50 points for tighter matching)
            if distance < nearestDistance && distance < maxDistance {
                nearestDistance = distance
                nearestLabel = label.capitalized
            }
        }
        
        return nearestLabel
    }
}

