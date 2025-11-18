//
//  SignatureDrawingView.swift
//  OneBox
//
//  Handwritten signature drawing using PencilKit
//

import SwiftUI
import PencilKit

struct SignatureDrawingView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var signatureImage: UIImage?

    @State private var canvas = PKCanvasView()
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructions
                instructionsBar

                // Drawing canvas
                CanvasView(canvasView: $canvas)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .padding()
                    )

                // Bottom toolbar
                bottomToolbar
            }
            .navigationTitle("Draw Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        saveSignature()
                    }
                    .disabled(canvas.drawing.bounds.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert("Clear Signature", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearCanvas()
                }
            } message: {
                Text("Are you sure you want to clear your signature?")
            }
        }
    }

    private var instructionsBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .foregroundColor(.accentColor)
                Text("Draw your signature below")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("Use your finger or Apple Pencil")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            Button(action: { showClearConfirmation = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("Clear")
                        .font(.caption2)
                }
            }
            .disabled(canvas.drawing.bounds.isEmpty)
            .foregroundColor(.red)

            Spacer()

            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                Text("Tap Done when finished")
                    .font(.caption2)
            }
            .foregroundColor(.secondary.opacity(0.6))
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
    }

    private func clearCanvas() {
        canvas.drawing = PKDrawing()
    }

    private func saveSignature() {
        // Convert PKDrawing to UIImage
        let drawing = canvas.drawing
        let bounds = drawing.bounds

        guard !bounds.isEmpty else {
            dismiss()
            return
        }

        // Add padding around the drawing
        let padding: CGFloat = 20
        let imageSize = CGSize(
            width: bounds.width + (padding * 2),
            height: bounds.height + (padding * 2)
        )

        // Render drawing to image
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { context in
            // Fill white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))

            // Translate to account for padding and drawing bounds
            context.cgContext.translateBy(x: padding - bounds.minX, y: padding - bounds.minY)

            // Draw the signature
            drawing.image(from: drawing.bounds, scale: 1.0).draw(in: bounds)
        }

        signatureImage = image

        // Save to UserDefaults for reuse
        if let imageData = image.pngData() {
            UserDefaults.standard.set(imageData, forKey: "saved_signature")
        }

        dismiss()
    }
}

// MARK: - Canvas View (UIViewRepresentable)
struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput  // Support both finger and Apple Pencil
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .white
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No updates needed
    }
}

// MARK: - Saved Signature Picker
struct SavedSignatureView: View {
    @Binding var signatureImage: UIImage?
    @State private var showDrawing = false

    var savedSignature: UIImage? {
        guard let data = UserDefaults.standard.data(forKey: "saved_signature") else {
            return nil
        }
        return UIImage(data: data)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let saved = savedSignature {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Signature")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 12) {
                        Image(uiImage: saved)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        VStack(spacing: 8) {
                            Button(action: { useSignature(saved) }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Use This")
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }

                            Button(action: { showDrawing = true }) {
                                HStack {
                                    Image(systemName: "pencil.circle")
                                    Text("Draw New")
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            } else {
                Button(action: { showDrawing = true }) {
                    HStack {
                        Image(systemName: "hand.draw")
                        Text("Draw Signature")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showDrawing) {
            SignatureDrawingView(signatureImage: $signatureImage)
        }
    }

    private func useSignature(_ image: UIImage) {
        signatureImage = image
    }
}

#Preview {
    SignatureDrawingView(signatureImage: .constant(nil))
}
