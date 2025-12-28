//
//  OnDeviceSearchService.swift
//  OneBox
//
//  100% on-device search service - zero cloud dependencies
//

import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

@MainActor
class OnDeviceSearchService: ObservableObject {
    static let shared = OnDeviceSearchService()
    
    @Published var searchResults: [SearchResult] = []
    @Published var isIndexing = false
    
    private let documentsURL: URL
    private let indexQueue = DispatchQueue(label: "com.spuud.vaultpdf.search.index", qos: .utility)
    
    private init() {
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Indexing (On-Device Only)
    
    func indexAllDocuments() {
        isIndexing = true
        
        Task {
            var searchableItems: [CSSearchableItem] = []
            
            // Index documents
            if let enumerator = FileManager.default.enumerator(at: self.documentsURL, includingPropertiesForKeys: [.nameKey, .fileSizeKey, .contentModificationDateKey]) {
                let allObjects = enumerator.allObjects
                for object in allObjects {
                    guard let fileURL = object as? URL else { continue }
                    // Only index PDFs and images
                    let pathExtension = fileURL.pathExtension.lowercased()
                    guard ["pdf", "jpg", "jpeg", "png", "heic"].contains(pathExtension) else { continue }
                    
                    if let item = self.createSearchableItem(for: fileURL) {
                        searchableItems.append(item)
                    }
                }
            }
            
            // Index workflows (from UserDefaults)
            if let workflowItems = self.indexWorkflows() {
                searchableItems.append(contentsOf: workflowItems)
            }
            
            // Index jobs (from JobManager)
            if let jobItems = self.indexJobs() {
                searchableItems.append(contentsOf: jobItems)
            }
            
            // Add to Core Spotlight index (on-device only)
            do {
                try await CSSearchableIndex.default().indexSearchableItems(searchableItems)
                self.isIndexing = false
            } catch {
                self.isIndexing = false
                print("Search indexing error: \(error.localizedDescription)")
            }
        }
    }
    
    private func createSearchableItem(for fileURL: URL) -> CSSearchableItem? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int64,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        
        let identifier = fileURL.absoluteString
        let domainIdentifier = "com.spuud.vaultpdf.documents"
        
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.data)
        attributeSet.title = fileURL.lastPathComponent
        attributeSet.displayName = fileURL.lastPathComponent
        attributeSet.contentModificationDate = modificationDate
        attributeSet.fileSize = NSNumber(value: fileSize)
        attributeSet.path = fileURL.path
        
        // Extract metadata from filename
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        attributeSet.keywords = extractKeywords(from: fileName)
        
        // Add file type specific metadata
        let pathExtension = fileURL.pathExtension.lowercased()
        if pathExtension == "pdf" {
            // Recreate attributeSet with PDF content type
            let pdfAttributeSet = CSSearchableItemAttributeSet(contentType: UTType.pdf)
            pdfAttributeSet.title = attributeSet.title
            pdfAttributeSet.displayName = attributeSet.displayName
            pdfAttributeSet.contentModificationDate = attributeSet.contentModificationDate
            pdfAttributeSet.fileSize = attributeSet.fileSize
            pdfAttributeSet.path = attributeSet.path
            pdfAttributeSet.keywords = attributeSet.keywords
            // Extract text from PDF for search (on-device only)
            if let pdfText = extractPDFText(url: fileURL) {
                pdfAttributeSet.textContent = pdfText
            }
            return CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domainIdentifier, attributeSet: pdfAttributeSet)
        } else if ["jpg", "jpeg", "png", "heic"].contains(pathExtension) {
            // Recreate attributeSet with image content type
            let imageAttributeSet = CSSearchableItemAttributeSet(contentType: UTType.image)
            imageAttributeSet.title = attributeSet.title
            imageAttributeSet.displayName = attributeSet.displayName
            imageAttributeSet.contentModificationDate = attributeSet.contentModificationDate
            imageAttributeSet.fileSize = attributeSet.fileSize
            imageAttributeSet.path = attributeSet.path
            imageAttributeSet.keywords = attributeSet.keywords
            return CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domainIdentifier, attributeSet: imageAttributeSet)
        }
        
        return CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet)
    }
    
    private func extractKeywords(from fileName: String) -> [String] {
        // Extract meaningful keywords from filename (on-device processing)
        let components = fileName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        return Array(Set(components)) // Remove duplicates
    }
    
    private func extractPDFText(url: URL) -> String? {
        // Extract text from PDF for search indexing (on-device only)
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        
        var text = ""
        for pageIndex in 0..<min(pdfDocument.pageCount, 10) { // Limit to first 10 pages for performance
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                text += pageText + " "
            }
        }
        
        return text.isEmpty ? nil : text
    }
    
    private func indexWorkflows() -> [CSSearchableItem]? {
        // Index custom workflows from UserDefaults (on-device only)
        guard let data = UserDefaults.standard.data(forKey: "saved_custom_workflows"),
              let workflows = try? JSONDecoder().decode([SearchableCustomWorkflowData].self, from: data) else {
            return nil
        }
        
        return workflows.map { workflow in
            let identifier = "workflow-\(workflow.id.uuidString)"
            let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.data)
            attributeSet.title = workflow.name
            attributeSet.displayName = "Workflow: \(workflow.name)"
            attributeSet.keywords = ["workflow", "automation"] + workflow.steps.map { $0.title }
            
            return CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: "com.spuud.vaultpdf.workflows", attributeSet: attributeSet)
        }
    }
    
    private func indexJobs() -> [CSSearchableItem]? {
        // Index recent jobs from JobManager (on-device only)
        // This would need access to JobManager, but for now return nil
        // Jobs are already searchable through their file outputs
        return nil
    }
    
    // MARK: - Search (On-Device Only)
    
    func performGlobalSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let lowercasedQuery = query.lowercased()
        var results: [SearchResult] = []
        
        // Search documents (on-device file system search)
        searchDocuments(query: lowercasedQuery, results: &results)
        
        // Search workflows (on-device UserDefaults search)
        searchWorkflows(query: lowercasedQuery, results: &results)
        
        // Search tools
        searchTools(query: lowercasedQuery, results: &results)
        
        searchResults = results.sorted { $0.relevance > $1.relevance }
    }
    
    private func searchDocuments(query: String, results: inout [SearchResult]) {
        if let enumerator = FileManager.default.enumerator(at: documentsURL, includingPropertiesForKeys: [.nameKey, .fileSizeKey]) {
            let allObjects = enumerator.allObjects
            for object in allObjects {
                guard let fileURL = object as? URL else { continue }
                let fileName = fileURL.lastPathComponent.lowercased()
                
                // Check filename match
                if fileName.contains(query) {
                    let relevance: Double = fileName == query ? 1.0 : 0.7
                    results.append(SearchResult(
                        id: fileURL.absoluteString,
                        title: fileURL.lastPathComponent,
                        type: .document,
                        url: fileURL,
                        relevance: relevance
                    ))
                }
            }
        }
    }
    
    private func searchWorkflows(query: String, results: inout [SearchResult]) {
        guard let data = UserDefaults.standard.data(forKey: "saved_custom_workflows"),
              let workflows = try? JSONDecoder().decode([SearchableCustomWorkflowData].self, from: data) else {
            return
        }
        
        for workflow in workflows {
            let workflowName = workflow.name.lowercased()
            if workflowName.contains(query) {
                results.append(SearchResult(
                    id: "workflow-\(workflow.id.uuidString)",
                    title: workflow.name,
                    type: .workflow,
                    url: nil,
                    relevance: 0.8
                ))
            }
        }
    }
    
    private func searchTools(query: String, results: inout [SearchResult]) {
        for tool in ToolType.allCases {
            let toolName = tool.displayName.lowercased()
            let toolDescription = tool.description.lowercased()
            
            if toolName.contains(query) || toolDescription.contains(query) {
                results.append(SearchResult(
                    id: "tool-\(tool.rawValue)",
                    title: tool.displayName,
                    type: .tool,
                    url: nil,
                    relevance: toolName == query ? 1.0 : 0.6
                ))
            }
        }
    }
    
    // MARK: - Cleanup
    
    func deleteSearchableItem(identifier: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
            if let error = error {
                print("Error deleting searchable item: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteAllSearchableItems() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                print("Error deleting all searchable items: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Search Result Model

struct SearchResult: Identifiable {
    let id: String
    let title: String
    let type: SearchResultType
    let url: URL?
    let relevance: Double
    
    enum SearchResultType {
        case document
        case workflow
        case tool
        
        var icon: String {
            switch self {
            case .document: return "doc.fill"
            case .workflow: return "gear.badge.checkmark"
            case .tool: return "wrench.and.screwdriver.fill"
            }
        }
    }
}

// MARK: - Custom Workflow Data (for search)

struct SearchableCustomWorkflowData: Codable {
    let id: UUID
    let name: String
    let steps: [WorkflowStep]
    let lastUsed: Date
}

// MARK: - WorkflowStep Extension (for search)
// Note: title property is already defined in WorkflowConciergeView, so we use that

// MARK: - PDFDocument Import

import PDFKit

