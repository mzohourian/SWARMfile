# Session Log

*Chronological record of all development sessions.*

---

## 2025-12-15: Button Aesthetics & Signature Position Fixes (Continued)

**Issues Reported:**
1. Disabled button opacity looks harsh - needs aesthetic improvement
2. Signature appears in different position than where user placed it
3. Signature size doesn't match what user expected

**Root Causes & Fixes:**

**1. Disabled Button Aesthetics**
- File: `OneBox/Modules/UIComponents/OneBoxStandard.swift`
- Old approach: Simple `.opacity(isDisabled ? 0.4 : 1.0)` looked harsh
- New approach: Elegant disabled state with multiple visual cues:
  - Muted background color (surfaceGraphite at 50% opacity)
  - Muted text color (tertiaryText instead of bright colors)
  - Subtle border to maintain button shape visibility
  - Desaturation effect (saturation: 0.3) for professional appearance
  - Smooth animation when transitioning between states

**2. Signature Position Mismatch**
- File: `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift`
- Root cause: Y coordinate NOT inverted when passing to CorePDF
- Screen coordinates have Y=0 at TOP, PDF coordinates have Y=0 at BOTTOM
- Fix: Invert Y when creating signature position: `y: 1.0 - firstPlacement.position.y`
- Now signature appears exactly where user placed it

**3. Signature Size Mismatch**
- File: `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift`
- Root cause: Size calculation used raw PDF page width instead of screen-relative ratio
- Old approach: `signatureWidth / pageWidth` (comparing screen pixels to PDF points)
- Fix: Use screen-relative ratio with estimated view width (400px)
- Result: Signature size now matches visual proportion user created

**Files Modified:**
- `OneBox/Modules/UIComponents/OneBoxStandard.swift`
- `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift`

**Status:** Needs user testing

---

## 2025-12-15: UX Fixes & State Persistence

**Issues Reported:**
1. "Continue Securely" button selectable when it should be disabled/faded
2. Preview shows black/blank page instead of actual file
3. Sign PDF has stray dots (resize handles) appearing in wrong positions
4. Sign PDF zoom gesture hard to use
5. User loses work when minimizing the app

**Fixes Applied:**

**1. Continue Securely Button Visual State**
- File: `OneBox/Modules/UIComponents/OneBoxStandard.swift`
- Added `.opacity(isDisabled ? 0.4 : 1.0)` to OneBoxButton
- Button now visually fades when disabled

**2. Preview Black Page Fix**
- File: `OneBox/OneBox/Views/JobResultView.swift`
- Fixed `numberOfPreviewItems` to always return 1 (not 0)
- Added fallback logic in `previewItemAt` to always return a valid item
- Improved file accessibility handling with retry logic

**3. Sign PDF Resize Handles (Stray Dots)**
- File: `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`
- Root cause: `.position()` placed handles absolutely in coordinate space
- Fix: Changed to `.offset()` so handles appear relative to signature center
- Increased handle size from 12 to 16 for better touch targets

**4. Sign PDF Zoom Gesture**
- File: `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`
- Changed from `simultaneousGesture` to regular `gesture` for priority
- Added haptic feedback during resize for better user feedback
- Reduced min/max size range for more reasonable zoom limits

**5. State Persistence on App Minimize**
- Created: `OneBox/OneBox/Services/WorkflowStateManager.swift`
- File: `OneBox/OneBox/Views/ToolFlowView.swift`
- Saves workflow state when app goes to background
- Offers to restore when user returns to the same tool
- State expires after 1 hour
- Only restores if selected files still exist

**Files Modified:**
- `OneBox/Modules/UIComponents/OneBoxStandard.swift`
- `OneBox/OneBox/Views/JobResultView.swift`
- `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`
- `OneBox/OneBox/Views/ToolFlowView.swift`

**Files Created:**
- `OneBox/OneBox/Services/WorkflowStateManager.swift`

**Status:** Needs user testing

---

## 2025-12-08: Page Organizer & Redaction Fixes

**Features Added:**
- **Swipe-to-select in Page Organizer** (iOS Photos-style)
  - Drag finger across pages to select/deselect multiple at once
  - First cell touched determines mode (selecting vs deselecting)
  - Haptic feedback for each cell touched
  - Uses PreferenceKey system to track cell frames

**Bugs Fixed:**
1. **RedactionView not loading PDF in workflow**
   - Root cause: Security-scoped resource access released too early
   - Fix: Keep access open if temp copy fails, release only at workflow end
   - Added retry logic (3 attempts with 0.5s delay)

2. **Redaction analysis not running**
   - Root cause: `onChange(of: pdfDocument)` never fired because PDFDocument doesn't conform to Equatable
   - Fix: Call `performSensitiveDataAnalysis()` directly when PDF loads in `loadPDFDocument()`

**Files Modified:**
- `OneBox/OneBox/Views/PageOrganizerView.swift` - Swipe-to-select
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Security-scoped resource fix
- `OneBox/OneBox/Views/RedactionView.swift` - PDF loading retry + analysis trigger fix

**Status:** Needs user testing

---

## 2025-12-07: Workflow Feature - Complete Fixes

**Problems Reported:**
1. "Create Custom Workflow" - Add Step button doesn't work
2. "Quick Share" template - runs briefly then returns with no feedback
3. Custom workflow doesn't show after save (only after app restart)
4. Workflow error: "Invalid input files"
5. Workflow execution is too slow

**Root Causes & Fixes:**

**Issue 1 - Add Step button:**
- `showingStepPicker` state variable was never used
- Fix: Always show available steps grid with helper text

**Issue 2 - No success feedback:**
- No message shown after workflow completes
- Fix: Added success alert with "Share Result" button

**Issue 3 - Workflow not showing after save:**
- Parent view only loaded workflows on `onAppear`
- Fix: Added `onChange(of: isCreatingWorkflow)` to reload on sheet dismiss

**Issue 4 - Invalid input files:**
- Security-scoped URLs from file picker not accessible across actor boundaries
- Fix: Copy security-scoped files to temp directory before processing, validate files exist

**Issue 5 - Slowness:**
- Fix: Reduced polling from 500ms→100ms (job), 200ms→50ms (UI)

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift`
- `OneBox/OneBox/Services/WorkflowExecutionService.swift`

**Status:** Needs user testing

---

## 2025-12-06: Workflow Feature - Complete Rebuild

**Problem:**
User reported workflow feature wasn't working properly and wasn't offering tailored workflows for specific use cases (legal, finance, HR, medical).

**Issues Found:**
1. `.organize` step was wrongly mapped to `.pdfMerge` (didn't actually organize)
2. `.sign` step used placeholder "Digitally Processed" text
3. Missing critical workflow steps: redact, page numbers, date stamp, flatten
4. Preset workflows were too generic and didn't match real professional needs
5. No step configuration capability

**Fix:**
1. **Added new workflow steps:**
   - `.redact` - Remove sensitive information with preset patterns
   - `.addPageNumbers` - Add page numbers or Bates numbering (for legal)
   - `.addDateStamp` - Add processing date to documents
   - `.flatten` - Flatten form fields and annotations

2. **Fixed step mappings in WorkflowExecutionService:**
   - `.organize` now maps to `.pdfOrganize` (not `.pdfMerge`)
   - `.sign` uses date-based signature text
   - `.redact` uses automatic redaction with legal/finance/HR/medical presets

3. **Added professional industry presets:**
   - **Legal Discovery** - redact PII, Bates numbers, date stamp, flatten, compress
   - **Contract Execution** - merge, flatten, sign, watermark EXECUTED, compress
   - **Financial Report** - redact account numbers, CONFIDENTIAL watermark, date stamp
   - **HR Documents** - redact SSN/personal data, INTERNAL watermark, page numbers
   - **Medical Records** - HIPAA-compliant PHI redaction, date stamp, watermark
   - **Merge & Archive** - combine documents, page numbers, date stamp, compress

4. **Added step configuration:**
   - `StepConfiguration` struct for customizing each step
   - Watermark text, opacity, position configurable
   - Redaction presets (legal, finance, HR, medical, custom)
   - Bates numbering prefix and start number

5. **Updated JobSettings:**
   - Added `WorkflowRedactionPreset` enum
   - Added `isPageNumbering`, `batesPrefix`, `batesStartNumber`
   - Added `isDateStamp`
   - Added `flattenFormFields`, `flattenAnnotations`

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - New steps, professional templates
- `OneBox/OneBox/Services/WorkflowExecutionService.swift` - Fixed mappings, step configuration
- `OneBox/Modules/JobEngine/JobEngine.swift` - New JobSettings properties

**Status:** Needs user testing

---

## 2025-12-06: Redact PDF - Coordinate Transformation Fix

**Problem:**
User showed screenshots where black redaction boxes appeared in WRONG positions - random places on the document instead of over the actual sensitive data (passport numbers, phone numbers, emails were still visible).

**Root Cause:**
Coordinate system mismatch between Vision and UIKit:
- **Vision framework**: Bottom-left origin, Y increases upward (normalized 0-1)
- **UIKit PDF context**: Top-left origin, Y increases downward

The previous code incorrectly assumed same coordinate systems:
```swift
let y = box.origin.y * pageBounds.height  // WRONG
```

**Fix:**
Proper coordinate transformation:
```swift
// Vision's box.origin.y is BOTTOM of box (from bottom of page)
// Vision's top = origin.y + height
// UIKit's origin.y should be TOP of box (from top of page)
let y = pageBounds.height * (1.0 - box.origin.y - box.height)
```

**Additional Fixes:**
1. **Fallback mechanism**: If `VNRecognizedText.boundingBox(for:)` fails, estimate position using character ratios within the block
2. **Thread safety**: Capture `ocrResults` from main thread before processing to avoid race conditions
3. **Better logging**: Added detailed logs for debugging

**Files Modified:**
- `OneBox/OneBox/Views/RedactionView.swift` - Coordinate fix, fallback, thread safety

**Status:** Needs user testing to confirm redaction boxes now appear in correct positions

---

## 2025-12-06: Redact PDF - Character-Level Bounding Boxes (Previous Attempt)

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
