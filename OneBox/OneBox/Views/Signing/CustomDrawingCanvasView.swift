//
//  CustomDrawingCanvasView.swift
//  OneBox
//
//  Custom drawing canvas as fallback for PencilKit issues on real devices
//

import SwiftUI
import UIKit
import CoreGraphics

// MARK: - Custom Drawing Canvas (Fallback for PencilKit)
class CustomDrawingView: UIView {
    private var path = UIBezierPath()
    private var paths: [UIBezierPath] = []
    private var lastPoint: CGPoint = .zero
    private var lineWidth: CGFloat = 3.0
    private var lineColor: UIColor = .black
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .white
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastPoint = touch.location(in: self)
        path = UIBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: lastPoint)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let currentPoint = touch.location(in: self)
        path.addLine(to: currentPoint)
        lastPoint = currentPoint
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let currentPoint = touch.location(in: self)
        path.addLine(to: currentPoint)
        paths.append(path)
        setNeedsDisplay()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    override func draw(_ rect: CGRect) {
        lineColor.setStroke()
        for path in paths {
            path.stroke()
        }
        path.stroke()
    }
    
    func clear() {
        paths.removeAll()
        path = UIBezierPath()
        setNeedsDisplay()
    }
    
    func getImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 2.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func undo() {
        guard !paths.isEmpty else { return }
        paths.removeLast()
        setNeedsDisplay()
    }
    
    var hasDrawing: Bool {
        return !paths.isEmpty || !path.isEmpty
    }
}

// MARK: - SwiftUI Wrapper
struct CustomDrawingCanvasWrapper: UIViewRepresentable {
    @Binding var hasDrawing: Bool
    @Binding var canvasRef: CustomDrawingView?
    let onDrawingChanged: (Bool) -> Void
    
    func makeUIView(context: Context) -> CustomDrawingView {
        let view = CustomDrawingView()
        DispatchQueue.main.async {
            canvasRef = view
        }
        return view
    }
    
    func updateUIView(_ uiView: CustomDrawingView, context: Context) {
        // Update hasDrawing state
        let newHasDrawing = uiView.hasDrawing
        if newHasDrawing != hasDrawing {
            DispatchQueue.main.async {
                hasDrawing = newHasDrawing
                onDrawingChanged(newHasDrawing)
            }
        }
    }
    
    static func dismantleUIView(_ uiView: CustomDrawingView, coordinator: ()) {
        // Cleanup if needed
    }
}

