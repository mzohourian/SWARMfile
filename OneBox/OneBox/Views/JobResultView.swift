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
    @State private var showPreview = false
    @State private var previewURL: URL?
    @State private var showSaveToPhotosAlert = false
    @State private var saveToPhotosMessage = ""
    @State private var isSavingToPhotos = false

    var body: some View {
        NavigationStack {
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
            .sheet(isPresented: $showPreview) {
                if let url = previewURL {
                    QuickLookPreview(url: url)
                }
            }
            .alert(isSavingToPhotos ? "Saving to Photos" : "Photos", isPresented: $showSaveToPhotosAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveToPhotosMessage)
            }
        }
    }

    // Helper to check if output is images
    private var hasImageOutputs: Bool {
        job.outputURLs.contains { url in
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "heic"].contains(ext)
        }
    }

    private var successHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 4) {
                Text("Success!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your files are ready")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top)
    }

    private var outputFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Files")
                .font(.headline)

            ForEach(Array(job.outputURLs.enumerated()), id: \.offset) { index, url in
                Button {
                    previewURL = url
                    showPreview = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: fileIcon(url))
                            .foregroundColor(.accentColor)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            if let size = fileSize(url) {
                                Text(size)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
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
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Save to Photos button for image outputs
            if hasImageOutputs {
                PrimaryButton("Save to Photos", icon: "photo.on.rectangle.angled") {
                    saveToPhotos()
                }
                .disabled(isSavingToPhotos)
            }

            PrimaryButton("Share & Save", icon: "square.and.arrow.up") {
                showShareSheet = true
            }

            SecondaryButton("Preview", icon: "eye") {
                if let url = job.outputURLs.first {
                    previewURL = url
                    showPreview = true
                }
            }

            Button("Process Another File") {
                // Will be handled by navigation
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.accentColor)
        }
    }

    // MARK: - Save to Photos
    private func saveToPhotos() {
        isSavingToPhotos = true

        // Request photo library permission
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    saveToPhotosMessage = "Photo library access denied. Please enable it in Settings to save images."
                    showSaveToPhotosAlert = true
                    isSavingToPhotos = false
                    return
                }

                // Save all image files
                var savedCount = 0
                var failedCount = 0

                PHPhotoLibrary.shared().performChanges({
                    for url in job.outputURLs {
                        let ext = url.pathExtension.lowercased()
                        guard ["jpg", "jpeg", "png", "heic"].contains(ext) else { continue }

                        // Ensure file exists and is accessible
                        guard FileManager.default.fileExists(atPath: url.path) else {
                            failedCount += 1
                            continue
                        }

                        // Create photo creation request
                        if PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url) != nil {
                            savedCount += 1
                        } else {
                            failedCount += 1
                        }
                    }
                }) { success, error in
                    DispatchQueue.main.async {
                        isSavingToPhotos = false

                        if success && savedCount > 0 {
                            saveToPhotosMessage = "Successfully saved \(savedCount) image\(savedCount == 1 ? "" : "s") to Photos."
                        } else if failedCount > 0 {
                            saveToPhotosMessage = "Failed to save \(failedCount) image\(failedCount == 1 ? "" : "s"). \(error?.localizedDescription ?? "")"
                        } else {
                            saveToPhotosMessage = "No images were saved."
                        }

                        showSaveToPhotosAlert = true
                    }
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
        case "mp4", "mov": return "play.rectangle.fill"
        case "zip": return "archivebox.fill"
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
        guard job.type == .pdfCompress || job.type == .imageResize || job.type == .videoCompress else {
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
                // If file is in temp directory, copy to Documents/Exports
                let fileManager = FileManager.default
                guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    return url
                }

                let exportsURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)
                try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)

                let destinationURL = exportsURL.appendingPathComponent(url.lastPathComponent)

                // Remove old file if exists
                try? fileManager.removeItem(at: destinationURL)

                // Copy file
                do {
                    try fileManager.copyItem(at: url, to: destinationURL)
                    return destinationURL
                } catch {
                    print("Failed to copy file: \(error)")
                    return url
                }
            }

            return UIActivityViewController(activityItems: accessibleURLs, applicationActivities: nil)
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - QuickLook Preview
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let accessibleURL: URL

        init(url: URL) {
            // Copy temp files to a persistent location for QuickLook access
            let fileManager = FileManager.default

            // Check if file exists
            guard fileManager.fileExists(atPath: url.path) else {
                print("QuickLook: File not found at \(url.path)")
                self.accessibleURL = url
                return
            }

            // If file is in temp directory, copy to Documents/Previews
            if url.path.contains("/tmp/") || url.path.contains("/Tmp/") {
                if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let previewsURL = documentsURL.appendingPathComponent("Previews", isDirectory: true)
                    try? fileManager.createDirectory(at: previewsURL, withIntermediateDirectories: true)

                    let destinationURL = previewsURL.appendingPathComponent(url.lastPathComponent)

                    // Remove old file if exists
                    try? fileManager.removeItem(at: destinationURL)

                    // Copy file
                    do {
                        try fileManager.copyItem(at: url, to: destinationURL)
                        print("QuickLook: Copied file to \(destinationURL.path)")
                        self.accessibleURL = destinationURL
                        return
                    } catch {
                        print("QuickLook: Failed to copy file: \(error)")
                    }
                }
            }

            // Use original URL if copy failed or not needed
            self.accessibleURL = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            accessibleURL as QLPreviewItem
        }
    }
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
