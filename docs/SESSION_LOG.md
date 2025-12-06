# Session Log

*Chronological record of all development sessions.*

---

## 2025-12-06: Redact PDF - Complete Rebuild

**What Was Done:**
- Completely rebuilt Redact PDF feature with 4 major fixes

**Bug 1: PDF Context Timing**
  - Root cause: `defer { UIGraphicsEndPDFContext() }` was closing PDF context AFTER the return statement
  - Fix: Removed defer, call UIGraphicsEndPDFContext() explicitly before file verification
  - Applied same fix to watermarkPDF, fillFormFields, compressPDFWithQuality

**Bug 2: ShareSheet Deleting Files**
  - Root cause: ShareSheet was deleting destination file before copying when source = destination
  - Fix: Check if file is already in Documents directory - use directly without copying

**Bug 3: Redaction Not Actually Applying to Scanned PDFs**
  - Root cause: CorePDF.redactPDF was using `page.string` which returns nil for scanned PDFs
  - OCR found the text but didn't capture bounding boxes (positions)
  - CorePDF couldn't find text to redact on image-based pages
  - Fix: Store OCR bounding boxes during text detection, then render pages as images and draw black boxes over detected text positions

**Bug 4: Overcomplicated UI**
  - Had 3 modes: Automatic/Manual/Combined - confusing and unnecessary
  - Fix: Removed mode picker, single unified flow where app detects, user reviews, then applies

**Implementation Details:**
- Added `OCRTextBlock` struct to store text with bounding boxes
- Modified OCR to capture VNRecognizedTextObservation.boundingBox for each text block
- New `createRedactedPDF()` function renders pages as images and draws black boxes over matching text blocks
- Properly converts Vision's normalized coordinates (bottom-left origin) to image coordinates (top-left origin)

**Files Modified:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Fixed PDF context timing in 4 functions
- `OneBox/OneBox/Views/JobResultView.swift` - Fixed ShareSheet file deletion bug
- `OneBox/OneBox/Views/RedactionView.swift` - Complete rebuild with OCR bounding boxes and proper redaction

**Status:** Needs user testing to confirm redactions actually appear on the saved PDF

---

## 2025-12-05: Redact PDF - OCR for Scanned Documents

**What Was Done:**
- Fixed Redact PDF black screen issue
  - Root cause: fullScreenCover had no fallback when URL was nil
  - Fix: Added Group wrapper with fallback error view
- Added passport number detection (various international formats)
  - US: 9 digits
  - UK/EU: 1-2 letters + 6-9 digits
  - Detection after "passport" keyword
- Added international phone number patterns (not just US format)
- Added OCR for scanned/image-based PDFs using Vision framework
  - 100% on-device using VNRecognizeTextRequest
  - Renders PDF pages as images, then performs text recognition
- Optimized OCR to prevent crashes on large documents (22 pages was crashing)
  - Reduced image scale from 2x to 1.5x
  - Added max dimension limit (2000px) to cap memory usage
  - Added autoreleasepool for memory cleanup between pages
  - Changed from .accurate to .fast recognition level
  - Disabled language correction for speed
  - Added 5-second timeout per page
  - Added 10ms delay between pages for UI updates

**Root Cause:**
PDF was image-based (scanned documents) so `page.string` returned nil for all 22 pages. PDFKit cannot extract text from images - needs OCR.

**Files Modified:**
- `OneBox/OneBox/Views/RedactionView.swift` - OCR, passport detection, memory optimization
- `OneBox/OneBox/Views/ToolFlowView.swift` - Debug logging, fallback error view

**Status:** OCR implemented and optimized, needs testing on device with scanned documents

---

## 2025-12-05: Organize PDF Fixes

**What Was Done:**
- Fixed scrolling not working in Organize PDF
  - Root cause: Standalone `DragGesture()` was consuming all drag events before ScrollView
  - Fix: Removed the conflicting gesture; `.onDrag` modifier handles drag-and-drop already
- Fixed selection cleared after rotation
  - Root cause: `selectedPages.removeAll()` was called at end of rotate functions
  - Fix: Removed the line so users can rotate multiple times without reselecting
- Disabled anomaly detection (false positives)
  - User feedback: "28 issues detected" but all pages marked as duplicates (incorrect)
  - Fix: Disabled `detectAnomalies()` call; feature needs proper algorithms and one-click solutions
- Fixed file persistence for PageOrganizerView
  - Root cause: View creates jobs with status: .success, bypassing JobEngine's processJob()
  - Fix: Added local `saveOutputToDocuments()` function
- Fixed multi-page rotation bug
  - Root cause: All rotations applied to same PDF object without saving intermediate results
  - Fix: Reload PDF from outputURL after each rotation to preserve previous changes

**Root Cause Summary:**
PageOrganizerView had a standalone DragGesture that was only used for visual feedback (opacity, scale) but it consumed scroll gestures. The `.onDrag` modifier already handles the actual drag-and-drop functionality.

**Files Modified:**
- `OneBox/OneBox/Views/PageOrganizerView.swift` - All fixes applied

**Status:** Fixes applied, needs user testing

---

## 2025-12-05: Watermark Fixes + File Persistence

**What Was Done:**
- Fixed processed files not saving to Files app
  - Root cause: Output saved to temp directory which iOS cleans up automatically
  - Fix: Added `saveOutputFilesToDocuments()` to copy files to Documents/Exports after processing
- Fixed text watermark SIZE completely ignored (parameter wasn't being passed to draw function)
- Improved image watermark size formula: now 5%-50% of page width (10x range)
- Improved text watermark size formula: now 2%-15% of page height (7.5x range)
- Improved image density formula: spacing 0.6x-5x watermark size (8x range)
- Improved text density formula: spacing 0.8x-6x text size (7.5x range)

**Root Cause:**
- Files were saved to temp directory which gets cleaned up by iOS
- Text watermarks had `drawTextWatermark(text, in: bounds, position: position, tileDensity: tileDensity)` - the `size` parameter was never passed
- Size and density formulas used narrow ranges that didn't produce visually obvious differences

**Files Modified:**
- `OneBox/OneBox/Views/ToolFlowView.swift` - Added auto-save to Documents/Exports
- `OneBox/Modules/CorePDF/CorePDF.swift` - Updated `drawTextWatermark` and `drawImageWatermark` functions

**Status:** Fixes applied, needs user testing

---

## 2025-12-04: Watermark PDF Fix - Large File Handling

**What Was Done:**
- Diagnosed root cause of watermark 27% hang: excessive tiling (50x50 = 2500 draw operations per page)
- Fixed `drawImageWatermark`: reduced limit from 50 to 15 (225 max operations)
- Fixed `drawTextWatermark`: reduced limit from 20 to 15 for consistency
- Added `autoreleasepool` inside tiling loops for memory management
- Added 100% offline principle to all documentation

**Root Cause:**
For a 10-page PDF with tiled image watermark, the app was doing 25,000 image draw operations with no memory release or UI updates between them.

**Files Modified:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Watermark tiling limits and memory
- `CLAUDE.md`, `PROJECT.md`, `docs/ARCHITECTURE.md` - Added offline principle

**Status:** Fix applied, needs user testing

---

## 2025-12-04: Documentation Restructure

**What Was Done:**
- Restructured documentation system to solve "model memory" problem
- Created new files: CLAUDE.md, PROJECT.md, docs/INDEX.md, docs/HEALTH_CHECK.md, docs/ARCHITECTURE.md, docs/SESSION_LOG.md, docs/DECISIONS.md
- Moved from single 950-line CLAUDE.md to modular ~300-line mandatory reading
- Old comprehensive CLAUDE.md preserved in OneBox/CLAUDE.md

**Files Created:**
- `/CLAUDE.md` (new, ~60 lines)
- `/PROJECT.md` (new, ~120 lines)
- `/docs/INDEX.md`
- `/docs/HEALTH_CHECK.md`
- `/docs/ARCHITECTURE.md`
- `/docs/SESSION_LOG.md`
- `/docs/DECISIONS.md`

**What's Next:**
- Fix Watermark PDF 27% hang issue

---

## 2025-12-04: Watermark PDF Button and Progress Fixes

**What Was Done:**
- Fixed "Begin Secure Processing" button not responding (HapticManager import issue)
- Fixed watermark infinite loading at 100% (added progress completion detection)
- Added debugging logs to watermark processing
- Improved memory management in watermark function

**Files Modified:**
- `OneBox/Views/ToolFlowView.swift`
- `Modules/CorePDF/CorePDF.swift`

**What's Unfinished:**
- Watermark PDF hangs at 27% (new issue after previous fixes)

---

## 2025-01-15: Resize Image Feature Audit

**What Was Done:**
- Comprehensive audit of Resize Image feature
- Fixed 8 critical issues (selection limits, validation, memory management)
- Fixed save to gallery functionality

**Files Modified:**
- `Modules/CoreImageKit/CoreImageKit.swift`
- `Modules/JobEngine/JobEngine.swift`
- `OneBox/Views/ToolFlowView.swift`
- `OneBox/Views/JobResultView.swift`
- `OneBox/Views/ExportPreviewView.swift`

**Status:** Resize Image fully functional

---

## 2025-01-15: Sign PDF Storage Fix

**What Was Done:**
- Fixed persistent "Unable to save the signed PDF" error
- Improved disk space checking logic
- Fixed clear button functionality
- Removed undo button as requested

**Files Modified:**
- `Modules/CorePDF/CorePDF.swift`
- `OneBox/Views/Signing/EnhancedSignatureCanvasView.swift`

**Status:** Sign PDF fully functional

---

## 2025-01-15: Sign PDF Complete Redesign

**What Was Done:**
- Complete redesign of Sign PDF feature
- Created interactive signing system with touch-to-place
- Implemented custom drawing canvas for real devices
- Fixed workflow progression issues

**Files Created:**
- `OneBox/Views/Signing/InteractiveSignPDFView.swift`
- `OneBox/Views/Signing/EnhancedSignatureCanvasView.swift`
- `OneBox/Views/Signing/InteractivePDFPageView.swift`
- `OneBox/Views/Signing/CustomDrawingCanvasView.swift`
- `OneBox/Services/SignatureFieldDetectionService.swift`
- `OneBox/Models/SignaturePlacement.swift`

**Status:** Sign PDF fully functional

---

## 2025-01-15: Major Implementation Cycle

**What Was Done:**
- Removed all ZIP/unzip features
- Implemented 8 major features (Global Search, Pre-flight Insights, Workflow Hooks, etc.)
- Fixed 31+ build errors and 15+ warnings
- Ensured iOS 16 compatibility

**Files Modified:** 51+ files

**Status:** All critical features implemented

---

*Add new entries at the top of this file.*
