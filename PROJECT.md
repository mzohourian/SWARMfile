# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-10

## What This Is
**OneBox** is a privacy-first iOS/iPadOS app for processing PDFs and images entirely on-device. Think of it as a Swiss Army knife for documents that respects your privacy.

**Target Users:** Anyone who works with PDFs and images on iPhone/iPad and cares about privacy.

## Core Principle - 100% OFFLINE

| Requirement | Status |
|-------------|--------|
| Works in airplane mode | REQUIRED |
| No cloud services | REQUIRED |
| No API calls | REQUIRED |
| No internet needed | REQUIRED |
| All processing on-device | REQUIRED |

The app uses only the device's local storage, RAM, and CPU. Large files should be handled via streaming/chunking, not by loading everything into memory.

---

## Current State

### Working
- Images to PDF conversion
- PDF merge, split, compress
- PDF signing (interactive, touch-to-place, multi-page support)
- Image resize and compress
- Job queue with progress tracking
- Free tier (3 exports/day)
- Pro subscriptions (StoreKit 2)
- On-device search
- Workflow automation
- Page organizer with undo/redo and tap-to-select
- Redaction - visual-first editing (tap to remove, draw to add)
- File preview (QuickLook) - fixed stale path issue

### Broken / Blocked
- None currently (rebuild app to get latest Info.plist)

### Needs Testing
- **Redact PDF** - Completely redesigned with visual-first approach:
  - Shows document preview with black boxes overlaid on detected sensitive data
  - Tap any box to REMOVE it (becomes gray/dashed outline)
  - Draw/drag on page to ADD new redaction boxes
  - Pinch-to-zoom or use +/- buttons for better visibility (up to 500%)
  - **NEW:** Full-screen mode button for maximum visibility and precise editing
  - Bottom bar shows count and "Apply X Redactions" button
  - Works on both text-based and scanned/image PDFs via OCR
  - **FIXED:** Pattern matching now uses OCR text to ensure bounding boxes are found
- **Watermark PDF** - Multiple fixes applied, needs user verification:
  - Size slider now has dramatic effect (5%-50% for images, 2%-15% for text)
  - Density slider now has dramatic effect (0.6x to 5x spacing)
  - Previous fix: reduced tiling from 50x50 to 15x15
- **Organize PDF** - Fixed file persistence and multi-page rotation bug
- Some advanced workflow features may need verification

---

## Known Issues

| # | Severity | Issue | Location | Status |
|---|----------|-------|----------|--------|
| 1 | Low | Swift 6 concurrency warnings (3) | MultipeerDocumentService, OnDeviceSearchService | Non-blocking |
| 2 | Info | "Update to recommended settings" | Xcode project | Informational |

**Resolved This Session:**
- **Workflow hybrid interactive/automated redesign** - Major workflow fix:
  - Interactive steps (Organize, Sign) now use existing app views (PageOrganizerView, InteractiveSignPDFView)
  - Automated steps (Compress, Watermark, etc.) run with pre-configured settings
  - Workflow pauses for interactive steps, continues after user completes them
  - Fixed page numbers showing literal `{page}` - now properly replaced per-page
  - Fixed date stamp showing "Processed:" prefix and ugly formatting
  - Made compression more aggressive for visible file size reduction
- All previous workflow fixes remain in place

---

## Last Session Summary

**Date:** 2025-12-10

**What Was Done:**

**1. Fixed redaction boxes not showing on visual preview:**
- Root cause 1: OCR was only run for scanned PDFs, but bounding boxes are needed for ALL PDFs
- Root cause 2: Pattern matching used embedded text but bounding box lookup used OCR text (mismatch!)
- Fix: Now ALWAYS use OCR text for pattern matching since that's where bounding boxes come from
- Increased OCR resolution (2.0 scale) and accuracy level for better detection

**2. Added zoom functionality to RedactionView:**
- Pinch-to-zoom gesture (100% to 500%)
- Zoom +/- buttons in header bar with percentage display
- Two-axis scrolling when zoomed in
- Zoom resets when changing pages

**3. Added full-screen editing mode:**
- Full-screen button (expand icon) opens page at maximum size
- Dark background for better contrast
- Page navigation at bottom
- All redaction features work (tap to toggle, draw to add)
- Pinch-to-zoom works in full-screen too

**4. Previous fixes (from earlier in session):**
- Multi-page signing now works (all signatures applied)
- PDF merge normalizes page sizes (small PDFs scaled up)
- Workflow redaction timing fixed
- Preview blank screen fixed
- Face ID crash diagnosed (rebuild needed)

**Files Modified This Session:**
- `OneBox/OneBox/Views/RedactionView.swift` - Fixed OCR bounding boxes + zoom functionality

---

## Next Steps (Priority Order)

1. **REBUILD APP IN XCODE** - Critical: fixes Face ID crash in workflows
2. **Test preview function** - Verify QuickLook now shows files properly after path fix
3. **Test workflow with biometric lock** - Should work after rebuild
4. **Test Redact PDF** - Verify file saving/sharing works correctly
5. Address Swift 6 warnings (optional, non-blocking)

---

## Quick Reference

| Item | Location |
|------|----------|
| App entry point | `OneBox/OneBox/OneBoxApp.swift` |
| Main home screen | `OneBox/OneBox/Views/NewHomeView.swift` |
| Tool flow (all tools) | `OneBox/OneBox/Views/ToolFlowView.swift` |
| PDF processing | `OneBox/Modules/CorePDF/CorePDF.swift` |
| Image processing | `OneBox/Modules/CoreImageKit/CoreImageKit.swift` |
| Job queue | `OneBox/Modules/JobEngine/JobEngine.swift` |

---

## Build Status
- **Compiles:** Yes (as of last session)
- **Warnings:** 3 (Swift 6 concurrency, non-blocking)
- **Errors:** 0

---

*For architecture details, see docs/ARCHITECTURE.md*
*For session history, see docs/SESSION_LOG.md*
*For decision records, see docs/DECISIONS.md*
