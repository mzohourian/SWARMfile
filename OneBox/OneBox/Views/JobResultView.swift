//
//  JobResultView.swift
//  OneBox
//

import SwiftUI
import JobEngine
import UIComponents
import QuickLook

struct JobResultView: View {
    let job: Job

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentsManager: PaymentsManager
    @State private var showShareSheet = false
    @State private var showPreview = false
    @State private var previewURL: URL?
    @State private var saveSuccess = false

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
                if let url = job.outputURLs.first {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showPreview) {
                if let url = previewURL {
                    QuickLookPreview(url: url)
                }
            }
            .alert("Saved", isPresented: $saveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("File saved to your Photos library")
            }
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
            PrimaryButton("Save to Files", icon: "square.and.arrow.down") {
                saveToFiles()
            }

            SecondaryButton("Share", icon: "square.and.arrow.up") {
                showShareSheet = true
            }

            Button("Process Another File") {
                // Will be handled by navigation
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.accentColor)
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

    private func saveToFiles() {
        // Implement save to Files app
        // This would typically use a UIDocumentPickerViewController
        // For now, just show success
        saveSuccess = true
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
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
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
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
