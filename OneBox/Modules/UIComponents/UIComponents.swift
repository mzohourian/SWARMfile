//
//  UIComponents.swift
//  OneBox - UIComponents Module
//
//  Reusable SwiftUI components for consistent UI across the app
//

import SwiftUI
import PencilKit
import UIKit

// MARK: - Primary Button
public struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    public init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDisabled ? Color.gray : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button
public struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Progress Card
public struct ProgressCard: View {
    let title: String
    let progress: Double
    let canCancel: Bool
    let onCancel: () -> Void

    public init(
        title: String,
        progress: Double,
        canCancel: Bool = true,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.progress = progress
        self.canCancel = canCancel
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text("\(progress.isNaN || progress.isInfinite ? 0 : Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if canCancel {
                    Button("Cancel", action: onCancel)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            ProgressView(value: progress)
                .tint(.accentColor)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Info Row
public struct InfoRow: View {
    let label: String
    let value: String
    let icon: String?

    public init(label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }

    public var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .frame(width: 24)
            }
            Text(label)
                .foregroundColor(OneBoxColors.secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(OneBoxColors.primaryText)
        }
        .font(.subheadline)
    }
}

// MARK: - Empty State View
public struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error Banner
public struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    public init(message: String, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// MARK: - Success Banner
public struct SuccessBanner: View {
    let message: String
    let onDismiss: () -> Void

    public init(message: String, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.green)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// MARK: - File Picker Row
public struct FilePickerRow: View {
    let fileName: String
    let fileSize: String?
    let icon: String
    let onRemove: (() -> Void)?

    public init(
        fileName: String,
        fileSize: String? = nil,
        icon: String = "doc",
        onRemove: (() -> Void)? = nil
    ) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.icon = icon
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                if let fileSize = fileSize {
                    Text(fileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Settings Row
public struct SettingsRow<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let destination: Destination

    public init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.destination = destination()
    }

    public var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 28)

                Text(title)

                Spacer()
            }
        }
    }
}

// MARK: - Loading View
public struct LoadingView: View {
    let message: String

    public init(message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Signature Drawing Canvas
@available(iOS 13.0, *)
public struct SignatureDrawingView: UIViewRepresentable {
    @Binding public var signatureData: Data?
    @State private var canvasView = PKCanvasView()
    
    public init(signatureData: Binding<Data?>) {
        self._signatureData = signatureData
    }
    
    public func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = UIColor.systemBackground
        canvasView.isOpaque = false
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3.0)
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
        return canvasView
    }
    
    public func updateUIView(_ uiView: PKCanvasView, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: SignatureDrawingView
        
        init(_ parent: SignatureDrawingView) {
            self.parent = parent
        }
        
        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Update signature data when drawing changes
            if canvasView.drawing.bounds.isEmpty {
                parent.signatureData = nil
            } else {
                let image = canvasView.drawing.image(from: canvasView.drawing.bounds, scale: 2.0)
                
                // Validate image size to prevent memory issues
                let maxDimension: CGFloat = 4096
                if image.size.width > maxDimension || image.size.height > maxDimension {
                    // Scale down if too large
                    let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
                    let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
                    image.draw(in: CGRect(origin: .zero, size: scaledSize))
                    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    if let scaledImage = scaledImage, let data = scaledImage.pngData() {
                        // Limit PNG data size to 10MB
                        if data.count <= 10 * 1024 * 1024 {
                            parent.signatureData = data
                        } else {
                            // Compress further if still too large
                            if let compressedData = scaledImage.jpegData(compressionQuality: 0.7) {
                                parent.signatureData = compressedData
                            }
                        }
                    }
                } else {
                    if let data = image.pngData() {
                        // Limit PNG data size to 10MB
                        if data.count <= 10 * 1024 * 1024 {
                            parent.signatureData = data
                        } else {
                            // Use JPEG compression if PNG is too large
                            if let compressedData = image.jpegData(compressionQuality: 0.8) {
                                parent.signatureData = compressedData
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Helper methods
    public func clearCanvas() {
        canvasView.drawing = PKDrawing()
        signatureData = nil
    }
}

// MARK: - Signature Input View
@available(iOS 13.0, *)
public struct SignatureInputView: View {
    @Binding public var signatureText: String?
    @Binding public var signatureImageData: Data?
    @State private var selectedMode: SignatureMode = .text
    
    private enum SignatureMode: String, CaseIterable {
        case text = "Text"
        case draw = "Draw"
        
        var icon: String {
            switch self {
            case .text: return "textformat"
            case .draw: return "scribble"
            }
        }
    }
    
    public init(signatureText: Binding<String?>, signatureImageData: Binding<Data?>) {
        self._signatureText = signatureText
        self._signatureImageData = signatureImageData
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Mode Selector
            Picker("Signature Mode", selection: $selectedMode) {
                ForEach(SignatureMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedMode) { _ in
                // Clear the other mode when switching
                if selectedMode == .text {
                    signatureImageData = nil
                } else {
                    signatureText = nil
                }
            }
            
            // Input based on selected mode
            Group {
                switch selectedMode {
                case .text:
                    textSignatureView
                case .draw:
                    drawSignatureView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedMode)
        }
    }
    
    private var textSignatureView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signature Text")
                .font(.subheadline)
                .fontWeight(.medium)
                
            TextField("Enter your name or signature text", text: Binding(
                get: { signatureText ?? "" },
                set: { signatureText = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            // Preview of text signature
            if let text = signatureText, !text.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(text)
                        .font(.custom("Snell Roundhand", size: 24))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private var drawSignatureView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Draw Your Signature")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Clear") {
                    signatureImageData = nil
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Drawing Canvas
            SignatureDrawingView(signatureData: $signatureImageData)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            Text("Use your finger or Apple Pencil to sign")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Reorderable File List
public struct ReorderableFilePickerRow: View {
    let fileName: String
    let fileSize: String?
    let icon: String
    let onRemove: (() -> Void)?
    let showDragHandle: Bool
    
    public init(
        fileName: String,
        fileSize: String? = nil,
        icon: String = "doc",
        onRemove: (() -> Void)? = nil,
        showDragHandle: Bool = false
    ) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.icon = icon
        self.onRemove = onRemove
        self.showDragHandle = showDragHandle
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(OneBoxColors.secondaryText)
                    .frame(width: 20)
            }

            Image(systemName: icon)
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                if let fileSize = fileSize {
                    Text(fileSize)
                        .font(.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
            Spacer()
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Reorderable File List View
public struct ReorderableFileListView: View {
    @Binding public var urls: [URL]
    let onRemove: (Int) -> Void
    let showAddButton: Bool
    let onAddFiles: () -> Void
    
    public init(
        urls: Binding<[URL]>,
        onRemove: @escaping (Int) -> Void,
        showAddButton: Bool = true,
        onAddFiles: @escaping () -> Void
    ) {
        self._urls = urls
        self.onRemove = onRemove
        self.showAddButton = showAddButton
        self.onAddFiles = onAddFiles
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            if !urls.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Files to Merge")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(OneBoxColors.primaryText)

                        Spacer()

                        Text("\(urls.count) file\(urls.count == 1 ? "" : "s") • Drag to reorder")
                            .font(.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }

                    reorderableList
                }
            }

            Spacer(minLength: 0)

            if showAddButton {
                addButton
            }
        }
    }
    
    private var reorderableList: some View {
        // Using List with onMove modifier for reordering
        List {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                ReorderableFilePickerRow(
                    fileName: url.lastPathComponent,
                    fileSize: fileSizeString(for: url),
                    icon: fileIcon(for: url),
                    onRemove: { onRemove(index) },
                    showDragHandle: true
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove(perform: moveFiles)
        }
        .listStyle(.plain)
        .frame(minHeight: CGFloat(min(urls.count * 56, 400)))
    }
    
    private var addButton: some View {
        Button(action: onAddFiles) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(urls.isEmpty ? "Select Files" : "Add More")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(OneBoxColors.primaryGold.opacity(0.1))
            .foregroundColor(OneBoxColors.primaryGold)
            .cornerRadius(12)
        }
    }
    
    private func moveFiles(from source: IndexSet, to destination: Int) {
        urls.move(fromOffsets: source, toOffset: destination)
    }
    
    private func fileSizeString(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text.fill"
        case "jpg", "jpeg", "png", "heic": return "photo.fill"
        default: return "doc.fill"
        }
    }
}
