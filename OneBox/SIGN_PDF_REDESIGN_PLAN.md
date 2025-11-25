# Sign PDF Feature - Complete Redesign Plan

## Current Issues Analysis

### Problems Identified:
1. **Drawing Canvas Too Small** - Current canvas is only 120px height, unusable
2. **Drawing Not Working** - PencilKit integration issues
3. **Limited Placement** - Only fixed positions (bottom right, etc.)
4. **Single Page Only** - Can only sign last page
5. **No Field Detection** - Doesn't detect existing signature fields in PDF
6. **No Interactive Placement** - Can't tap to place signature
7. **No Resize on Page** - Can't adjust size after placement
8. **Poor UX Flow** - Configuration view is disconnected from PDF preview

## New Architecture

### Core Components:

1. **InteractiveSignPDFView** (Main View)
   - Full-screen PDF viewer with page navigation
   - Interactive signature placement
   - Visual feedback and animations
   - Multi-page support

2. **SignatureFieldDetectionService**
   - Uses Vision framework to detect signature fields
   - Analyzes PDF pages for signature placeholders
   - Returns detected field locations with confidence scores

3. **EnhancedSignatureCanvasView**
   - Large, full-screen or modal drawing canvas
   - Improved PencilKit integration
   - Better touch responsiveness
   - Clear/Undo functionality

4. **InteractiveSignaturePlacement**
   - Touch-to-place on any page
   - Pinch-to-resize gesture
   - Drag-to-move signature
   - Visual handles for precise control

5. **SignaturePlacementManager**
   - Manages multiple signatures across pages
   - Stores signature positions, sizes, and pages
   - Validates placements

## UI/UX Design

### User Flow:
1. **Select PDF** → User selects PDF from file picker
2. **Auto-Detection** → System scans for signature fields (optional, can skip)
3. **Signature Creation** → User draws or types signature in large canvas
4. **Interactive Placement** → User navigates PDF, taps to place signature
5. **Resize & Adjust** → User pinches or drags handles to resize
6. **Review & Confirm** → User reviews all signatures before processing
7. **Process** → Signatures are applied to PDF

### Screen Layout:

```
┌─────────────────────────────────────┐
│  [←] Sign PDF          [Done] [✓]   │ ← Navigation Bar
├─────────────────────────────────────┤
│                                     │
│   ┌───────────────────────────┐   │
│   │                           │   │
│   │   PDF Page Viewer         │   │ ← Full-screen PDF
│   │   (Scrollable, Zoomable)  │   │   with touch support
│   │                           │   │
│   │   [Detected Field]        │   │ ← Highlighted fields
│   │   ┌─────────────┐        │   │
│   │   │  Signature  │        │   │ ← Placed signature
│   │   │  Preview    │        │   │   (resizable)
│   │   └─────────────┘        │   │
│   └───────────────────────────┘   │
│                                     │
│  [<] Page 2 of 5 [>]  [🔍] [📄]    │ ← Page controls
├─────────────────────────────────────┤
│  [✏️ Draw] [📝 Type] [📷 Image]     │ ← Signature creation
│  [🎯 Auto-Detect Fields]             │ ← Field detection
│  [📋 Signatures: 2] [🗑️ Clear All]  │ ← Signature management
└─────────────────────────────────────┘
```

### Signature Drawing Canvas (Modal):
```
┌─────────────────────────────────────┐
│  Draw Your Signature        [✕]    │
├─────────────────────────────────────┤
│                                     │
│   ┌───────────────────────────┐   │
│   │                           │   │
│   │                           │   │
│   │   Large Drawing Area      │   │ ← 400px+ height
│   │   (Full touch support)    │   │
│   │                           │   │
│   │                           │   │
│   └───────────────────────────┘   │
│                                     │
│  [↶ Undo] [Clear]  [Save Signature]│
└─────────────────────────────────────┘
```

## Technical Implementation

### 1. Signature Field Detection

**Service:** `SignatureFieldDetectionService`
- Uses Vision framework (VNDetectRectanglesRequest + VNRecognizeTextRequest)
- Detects rectangles near "signature", "sign", "sign here" text
- Returns array of `DetectedSignatureField`:
  ```swift
  struct DetectedSignatureField {
      let id: UUID
      let pageIndex: Int
      let bounds: CGRect
      let confidence: Double
      let label: String? // "Signature", "Sign here", etc.
  }
  ```

### 2. Interactive PDF Viewer

**Component:** `InteractivePDFPageView`
- PDFKit-based viewer with gesture support
- Tap gesture for signature placement
- Pinch gesture for zoom
- Pan gesture for navigation
- Visual overlays for signatures and detected fields

### 3. Signature Placement System

**Data Model:**
```swift
struct SignaturePlacement {
    let id: UUID
    let pageIndex: Int
    var position: CGPoint // Normalized 0.0-1.0
    var size: CGSize // In PDF points
    let signatureData: SignatureData // Text or image
    var rotation: CGFloat = 0
}
```

**Gestures:**
- **Tap:** Place signature at tap location
- **Long Press:** Show resize handles
- **Pinch:** Resize signature
- **Drag:** Move signature
- **Rotation:** (Optional) Rotate signature

### 4. Enhanced Drawing Canvas

**Component:** `EnhancedSignatureCanvasView`
- Full-screen modal or large embedded view
- Minimum 400px height, preferably 500-600px
- Improved PencilKit configuration:
  - Better tool settings
  - Proper delegate handling
  - Real-time preview
- Clear/Undo buttons
- Save/Cancel actions

### 5. Core PDF Signing Update

**Update:** `CorePDF.signPDF()` to support:
- Multiple signatures on multiple pages
- Custom positions (normalized coordinates)
- Custom sizes per signature
- Signature rotation (optional)

## Implementation Steps

1. ✅ Create architecture plan (this document)
2. Create `SignatureFieldDetectionService`
3. Create `InteractiveSignPDFView` (main view)
4. Create `EnhancedSignatureCanvasView`
5. Create `InteractivePDFPageView` with gesture support
6. Create `SignaturePlacementManager`
7. Update `CorePDF.signPDF()` for multi-signature support
8. Integrate into `ToolFlowView`
9. Add animations and polish
10. Test all edge cases

## Success Criteria

✅ **Drawing Works Perfectly**
- Large, usable canvas (400px+)
- Smooth drawing experience
- Clear/Undo functionality

✅ **Interactive Placement**
- Tap anywhere on any page to place
- Visual feedback on tap
- Smooth animations

✅ **Resize Functionality**
- Pinch-to-resize works smoothly
- Drag handles for precise control
- Size constraints (min/max)

✅ **Field Detection**
- Auto-detects signature fields
- Visual highlights
- One-tap placement in detected fields

✅ **Multi-Page Support**
- Navigate between pages
- Place signatures on any page
- Visual page indicators

✅ **Polished UX**
- Smooth animations
- Clear visual feedback
- Intuitive gestures
- Professional appearance

## Files to Create/Modify

### New Files:
1. `OneBox/Views/Signing/InteractiveSignPDFView.swift`
2. `OneBox/Views/Signing/EnhancedSignatureCanvasView.swift`
3. `OneBox/Views/Signing/InteractivePDFPageView.swift`
4. `OneBox/Services/SignatureFieldDetectionService.swift`
5. `OneBox/Models/SignaturePlacement.swift`

### Modified Files:
1. `Modules/CorePDF/CorePDF.swift` - Update signPDF for multi-signature
2. `OneBox/Views/ToolFlowView.swift` - Integrate new view
3. `Modules/JobEngine/JobEngine.swift` - Update for new signature format
4. `Modules/CommonTypes/CommonTypes.swift` - Add new types if needed

