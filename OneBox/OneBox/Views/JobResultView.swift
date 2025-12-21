//
//  JobResultView.swift
//  OneBox
//

import SwiftUI
import JobEngine
import UIComponents
import QuickLook
import Photos

struct JobResultView: View {
    let job: Job

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentsManager: PaymentsManager
    @State private var showShareSheet = false
    @State private var previewItem: PreviewItem?  // Combined URL + presentation state
    @State private var isSavingToPhotos = false
    @State private var saveToPhotosError: String?
    @State private var showSaveError = false
    @State private var showPreviewError = false

    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                    // Success Header
                    successHeader

                    // Ad Banner (free tier)
                    if !paymentsManager.hasPro {
                        AdBannerView()
                            .padding(.horizontal)
                    }

                    // Output Files
                    outputFilesSection

                    // Stats
                    statsSection

                    // Actions
                    actionsSection

                    Spacer()
                    }
                    .padding()
                }
            } // End ZStack
            .navigationTitle("Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: job.outputURLs)
            }
            .fullScreenCover(item: $previewItem) { item in
                QuickLookPreviewWrapper(url: item.url, isPresented: Binding(
                    get: { previewItem != nil },
                    set: { if !$0 { previewItem = nil } }
                ))
            }
        }
    }

    private var successHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(OneBoxColors.secureGreen)

            VStack(spacing: 4) {
                Text("Success!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(OneBoxColors.primaryText)

                Text("Your files are ready")
                    .font(.subheadline)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
        .padding(.top)
    }

    private var outputFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Files")
                .font(.headline)
                .foregroundColor(OneBoxColors.primaryText)

            ForEach(Array(job.outputURLs.enumerated()), id: \.offset) { index, url in
                Button {
                    // Ensure file is accessible before previewing
                    if let accessibleURL = ensureFileAccessible(url) {
                        previewItem = PreviewItem(url: accessibleURL)
                    } else {
                        print("❌ Could not make file accessible for preview: \(url)")
                        showPreviewError = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: fileIcon(url))
                            .foregroundColor(OneBoxColors.primaryGold)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .foregroundColor(OneBoxColors.primaryText)
                                .lineLimit(1)

                            if let size = fileSize(url) {
                                Text(size)
                                    .font(.caption)
                                    .foregroundColor(OneBoxColors.secondaryText)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    .padding()
                    .background(OneBoxColors.secondaryGraphite)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .foregroundColor(OneBoxColors.primaryText)

            VStack(spacing: 8) {
                InfoRow(
                    label: "Files Processed",
                    value: "\(job.inputs.count)",
                    icon: "doc"
                )

                InfoRow(
                    label: "Files Created",
                    value: "\(job.outputURLs.count)",
                    icon: "doc.badge.plus"
                )

                if let completedAt = job.completedAt {
                    InfoRow(
                        label: "Completed",
                        value: completedAt.formatted(date: .omitted, time: .shortened),
                        icon: "clock"
                    )
                }

                if let savings = compressionSavings {
                    InfoRow(
                        label: "Space Saved",
                        value: savings,
                        icon: "arrow.down.circle"
                    )
                }
            }
            .padding()
            .background(OneBoxColors.secondaryGraphite)
            .cornerRadius(12)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Show "Save to Photos" button for image jobs
            if isImageJob {
                PrimaryButton(
                    isSavingToPhotos ? "Saving..." : "Save to Photos",
                    icon: isSavingToPhotos ? "hourglass" : "photo.badge.plus"
                ) {
                    saveImagesToPhotoLibrary()
                }
                .disabled(isSavingToPhotos)
            }
            
            PrimaryButton("Share & Save", icon: "square.and.arrow.up") {
                showShareSheet = true
            }

            SecondaryButton("Preview", icon: "eye") {
                if let url = job.outputURLs.first {
                    // Try to ensure file is accessible first
                    if let accessibleURL = ensureFileAccessible(url) {
                        previewItem = PreviewItem(url: accessibleURL)
                    } else {
                        print("❌ Could not make file accessible for preview: \(url)")
                        showPreviewError = true
                    }
                } else {
                    showPreviewError = true
                }
            }

            Button("Process Another File") {
                // Will be handled by navigation
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.accentColor)
        }
        .alert("Error Saving to Photos", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = saveToPhotosError {
                Text(error)
            }
        }
        .alert("Unable to Preview", isPresented: $showPreviewError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The file may have been moved or deleted. Try processing again.")
        }
    }
    
    private var isImageJob: Bool {
        job.type == .imageResize || job.type == .pdfToImages
    }
    
    private func saveImagesToPhotoLibrary() {
        isSavingToPhotos = true
        saveToPhotosError = nil
        
        Task {
            do {
                // Request photo library permission
                let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                let authStatus: PHAuthorizationStatus
                
                if status == .notDetermined {
                    authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                } else {
                    authStatus = status
                }
                
                guard authStatus == .authorized || authStatus == .limited else {
                    await MainActor.run {
                        saveToPhotosError = "Photo library access denied. Please enable photo access in Settings to save images."
                        showSaveError = true
                        isSavingToPhotos = false
                    }
                    return
                }
                
                // Save each image
                var successCount = 0
                var failureCount = 0
                
                for url in job.outputURLs {
                    // Check if it's an image file
                    let ext = url.pathExtension.lowercased()
                    guard ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) else {
                        continue
                    }
                    
                    // Ensure file is accessible (handle security-scoped resources and temp files)
                    var startedAccessing = false
                    if url.startAccessingSecurityScopedResource() {
                        startedAccessing = true
                    }
                    
                    defer {
                        if startedAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    // Check if file exists
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        print("⚠️ JobResultView: File does not exist: \(url.path)")
                        failureCount += 1
                        continue
                    }
                    
                    // Load image using CGImageSource (better for file access)
                    var image: UIImage?
                    
                    if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                       let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                        image = UIImage(cgImage: cgImage)
                    } else {
                        // Fallback to Data method
                        if let imageData = try? Data(contentsOf: url) {
                            image = UIImage(data: imageData)
                        }
                    }
                    
                    guard let finalImage = image else {
                        print("⚠️ JobResultView: Failed to load image from: \(url.lastPathComponent)")
                        failureCount += 1
                        continue
                    }
                    
                    // Save to photo library
                    do {
                        try await PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
                        }
                        successCount += 1
                        print("✅ JobResultView: Successfully saved \(url.lastPathComponent) to photo library")
                    } catch {
                        print("❌ JobResultView: Failed to save image \(url.lastPathComponent): \(error.localizedDescription)")
                        failureCount += 1
                    }
                }
                
                await MainActor.run {
                    isSavingToPhotos = false
                    
                    if failureCount > 0 {
                        if successCount > 0 {
                            saveToPhotosError = "Saved \(successCount) image\(successCount == 1 ? "" : "s"). \(failureCount) failed to save."
                        } else {
                            saveToPhotosError = "Failed to save images to photo library. The files may have been moved or deleted. Please try using the Share button instead."
                        }
                        showSaveError = true
                    } else if successCount > 0 {
                        // Success - show feedback
                        HapticManager.shared.notification(.success)
                        print("✅ JobResultView: Successfully saved \(successCount) image\(successCount == 1 ? "" : "s") to photo library")
                    } else {
                        // No images found
                        saveToPhotosError = "No image files found to save."
                        showSaveError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSavingToPhotos = false
                    saveToPhotosError = "Failed to save images: \(error.localizedDescription)"
                    showSaveError = true
                }
            }
        }
    }

    // MARK: - Helpers
    private func fileIcon(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text.fill"
        case "jpg", "jpeg", "png", "heic": return "photo.fill"
        default: return "doc.fill"
        }
    }

    private func fileSize(_ url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private var compressionSavings: String? {
        guard job.type == .pdfCompress || job.type == .imageResize else {
            return nil
        }

        let inputSize = job.inputs.reduce(Int64(0)) { sum, url in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int64 ?? 0
            return sum + size
        }

        let outputSize = job.outputURLs.reduce(Int64(0)) { sum, url in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int64 ?? 0
            return sum + size
        }

        let saved = inputSize - outputSize
        if saved > 0 {
            let percentage = Double(saved) / Double(inputSize) * 100
            return "\(ByteCountFormatter.string(fromByteCount: saved, countStyle: .file)) (\(Int(percentage))%)"
        }

        return nil
    }
    
    // MARK: - File Access Helper
    private func ensureFileAccessible(_ sourceURL: URL) -> URL? {
        let fileManager = FileManager.default

        // First, try the URL directly (most common case)
        if fileManager.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }

        // If that fails, try to find the file in Documents/Exports
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsDir = documentsURL.appendingPathComponent("Exports")
        let filename = sourceURL.lastPathComponent
        let exportsURL = exportsDir.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: exportsURL.path) {
            return exportsURL
        }

        // Try with security-scoped access (for external files)
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        if fileManager.fileExists(atPath: sourceURL.path) {
            // Return a copy in accessible location since we need to stop access
            return copyFileToAccessibleLocation(sourceURL)
        }

        return nil
    }
    
    private func copyFileToAccessibleLocation(_ sourceURL: URL) -> URL? {
        do {
            // Create accessible directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let previewsDir = documentsURL.appendingPathComponent("Previews", isDirectory: true)
            
            try FileManager.default.createDirectory(at: previewsDir, withIntermediateDirectories: true, attributes: nil)
            
            // Create unique filename to avoid conflicts
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "\(timestamp)_\(sourceURL.lastPathComponent)"
            let destinationURL = previewsDir.appendingPathComponent(filename)
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy with security-scoped access if needed
            var startedAccessing = false
            if sourceURL.startAccessingSecurityScopedResource() {
                startedAccessing = true
            }
            
            defer {
                if startedAccessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
            
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            print("✅ Copied file for preview: \(destinationURL.path)")
            return destinationURL
            
        } catch {
            print("❌ Error copying file for preview: \(error)")
            return nil
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Ensure files can be saved
        if let urls = items as? [URL] {
            // Copy temp files to a more accessible location
            let accessibleURLs = urls.compactMap { url -> URL? in
                let fileManager = FileManager.default

                // Check if file exists first
                guard fileManager.fileExists(atPath: url.path) else {
                    print("❌ ShareSheet: File doesn't exist: \(url.path)")
                    return nil
                }

                // If file is already in Documents directory, use it directly (don't copy over itself!)
                guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    return url
                }

                if url.path.hasPrefix(documentsURL.path) {
                    print("✅ ShareSheet: File already in Documents, using directly: \(url.lastPathComponent)")
                    return url
                }

                // Only copy files that are in temp directory
                let exportsURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)
                try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)

                let destinationURL = exportsURL.appendingPathComponent(url.lastPathComponent)

                // If destination already exists, use it (don't delete and recopy!)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    print("✅ ShareSheet: Destination already exists, using: \(destinationURL.lastPathComponent)")
                    return destinationURL
                }

                // Copy file from temp to Documents/Exports
                do {
                    try fileManager.copyItem(at: url, to: destinationURL)
                    print("✅ ShareSheet: Copied to: \(destinationURL.lastPathComponent)")
                    return destinationURL
                } catch {
                    print("❌ ShareSheet: Failed to copy file: \(error)")
                    return url
                }
            }

            // Filter out nil values
            let validURLs = accessibleURLs.compactMap { $0 }
            guard !validURLs.isEmpty else {
                print("❌ ShareSheet: No valid URLs to share")
                return activityVC
            }

            return UIActivityViewController(activityItems: validURLs, applicationActivities: nil)
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - QuickLook Preview Wrapper (with dismiss button)
struct QuickLookPreviewWrapper: View {
    let url: URL
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            QuickLookPreview(url: url)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
                .ignoresSafeArea()
        }
    }
}

// MARK: - QuickLook Preview
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // Update coordinator's URL and refresh
        context.coordinator.updateURL(url)
        uiViewController.refreshCurrentPreviewItem()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        private var currentURL: URL
        private var previewItem: QuickLookPreviewItem?
        private var retryCount = 0
        private let maxRetries = 3

        init(url: URL) {
            self.currentURL = url
            super.init()
            self.previewItem = createPreviewItem(from: url)
        }
        
        func updateURL(_ newURL: URL) {
            self.currentURL = newURL
            self.retryCount = 0
            self.previewItem = createPreviewItem(from: newURL)
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            // Always return 1 - we'll provide a fallback in previewItemAt if needed
            // If preview item is nil, try to create it with retry logic
            if previewItem == nil && retryCount < maxRetries {
                retryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.previewItem = self.createPreviewItem(from: self.currentURL)
                    controller.reloadData()
                }
            }
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            // Try to use existing preview item first
            if let item = previewItem {
                // Verify the preview item URL is still accessible
                if let previewURL = item.previewItemURL,
                   FileManager.default.fileExists(atPath: previewURL.path) {
                    print("✅ QuickLook Preview loaded successfully")
                    return item
                } else {
                    print("⚠️ Preview file no longer exists, recreating...")
                    self.previewItem = createPreviewItem(from: currentURL)
                    if let newItem = self.previewItem {
                        return newItem
                    }
                }
            }

            // Fallback: try to create preview item one more time
            if let newItem = createPreviewItem(from: currentURL) {
                self.previewItem = newItem
                print("✅ QuickLook Preview created on fallback")
                return newItem
            }

            // Last resort: return URL directly (QuickLook can sometimes handle this)
            print("⚠️ No preview item available, using URL directly: \(currentURL.path)")
            // Ensure we have security-scoped access
            _ = currentURL.startAccessingSecurityScopedResource()
            return currentURL as QLPreviewItem
        }
        
        private func createPreviewItem(from sourceURL: URL) -> QuickLookPreviewItem? {
            // First, try to ensure file is accessible
            guard let accessibleURL = ensureFileAccessible(sourceURL) else {
                print("❌ Could not make file accessible: \(sourceURL)")
                return nil
            }
            
            // Verify file can be read
            guard FileManager.default.isReadableFile(atPath: accessibleURL.path) else {
                print("❌ File is not readable: \(accessibleURL.path)")
                return nil
            }
            
            print("✅ Created preview item for: \(accessibleURL.path)")
            return QuickLookPreviewItem(url: accessibleURL, title: sourceURL.lastPathComponent)
        }
        
        private func ensureFileAccessible(_ sourceURL: URL) -> URL? {
            let fileManager = FileManager.default

            // First, try the URL directly (most common case)
            if fileManager.fileExists(atPath: sourceURL.path) {
                return sourceURL
            }

            // If that fails, try to find the file in Documents/Exports
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let exportsDir = documentsURL.appendingPathComponent("Exports")
            let filename = sourceURL.lastPathComponent
            let exportsURL = exportsDir.appendingPathComponent(filename)

            if fileManager.fileExists(atPath: exportsURL.path) {
                return exportsURL
            }

            // Try with security-scoped access (for external files)
            let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            if fileManager.fileExists(atPath: sourceURL.path) {
                return copyToAccessibleLocation(sourceURL)
            }

            return nil
        }
        
        private func copyToAccessibleLocation(_ sourceURL: URL) -> URL? {
            do {
                // Create accessible directory
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let previewsDir = documentsURL.appendingPathComponent("Previews", isDirectory: true)
                
                try FileManager.default.createDirectory(at: previewsDir, withIntermediateDirectories: true, attributes: nil)
                
                // Create unique filename to avoid conflicts
                let timestamp = Int(Date().timeIntervalSince1970)
                let filename = "\(timestamp)_\(sourceURL.lastPathComponent)"
                let destinationURL = previewsDir.appendingPathComponent(filename)
                
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy with security-scoped access if needed
                var startedAccessing = false
                if sourceURL.startAccessingSecurityScopedResource() {
                    startedAccessing = true
                }
                
                defer {
                    if startedAccessing {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                
                print("✅ Copied file for preview: \(destinationURL.path)")
                return destinationURL
                
            } catch {
                print("❌ Error copying file for preview: \(error)")
                return nil
            }
        }
    }
}

// MARK: - QuickLook Preview Item
class QuickLookPreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL, title: String? = nil) {
        self.previewItemURL = url
        self.previewItemTitle = title
        super.init()
    }
}

// MARK: - Preview Item (Identifiable URL wrapper for sheet presentation)
struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    JobResultView(job: Job(
        type: .imagesToPDF,
        inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
        status: .success,
        progress: 1.0,
        outputURLs: [URL(fileURLWithPath: "/tmp/output.pdf")]
    ))
    .environmentObject(PaymentsManager.shared)
}
