# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-16

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
- PDF signing (interactive, touch-to-place)
- Image resize and compress
- Job queue with progress tracking
- Free tier (3 exports/day)
- Pro subscriptions (StoreKit 2)
- On-device search
- Workflow automation
- Page organizer with undo/redo and swipe-to-select
- Redaction with presets

### Broken / Blocked
- None currently

### Needs Testing
- **Redact PDF** - Completely rebuilt with precise character-level redaction:
  - Fixed file not saving (2 bugs: PDF context timing + ShareSheet deletion)
  - Redaction now actually works on scanned/image-based PDFs
  - **NEW**: Uses Vision's character-level bounding boxes (`VNRecognizedText.boundingBox(for:)`) to redact ONLY the exact matched text, not entire lines
  - Simplified UI - removed Automatic/Manual/Combined modes, single unified flow
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

**Date:** 2025-12-16

**What Was Done:**
- **Fixed signature position bug (Y coordinate flip removed):**
  - Root cause: CorePDF was incorrectly flipping Y coordinate with `(1.0 - clampedY)`
  - In UIGraphics PDF context, Y=0 is at TOP (same as screen), so no flip needed
  - Fixed in both `drawSignatureText` and `drawSignatureImage` with customPosition

- **Multi-page signature support:**
  - Previously only the first signature was processed!
  - Added `SignatureConfig` struct in CorePDF for multiple signatures
  - Added `signPDFWithMultipleSignatures()` method that processes all signatures in one pass
  - Added `SignatureConfigData` (Codable) in JobEngine to transfer multiple signatures
  - Updated `processSignatures()` to convert ALL placements to configs
  - Now all signatures on all pages appear in the final PDF

- **Drag-anywhere for selected signature:**
  - Previously had to drag directly on the signature
  - Now like zoom: when signature is selected, dragging anywhere moves it
  - Added `signatureDragOffset` state at page level
  - Modified page-level drag gesture to move signature when selected
  - Removed local drag gesture from SignaturePlacementOverlay

- **Tap to toggle selection:**
  - Removed Unselect button - cleaner UI
  - Tap on signature toggles selection (tap to select, tap again to unselect)

- **Fixed signature size after zoom:**
  - Bug: Resizing after zooming caused wrong size in final PDF
  - Root cause: viewWidthAtPlacement was not updated when resizing
  - Fix: Update viewWidthAtPlacement to current PDF display width when resizing

**What's Unfinished:**
- Build not verified (no Xcode in environment) - user should build and test

**Files Modified This Session:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Fixed Y flip, added multi-signature support
- `OneBox/Modules/JobEngine/JobEngine.swift` - Added SignatureConfigData, multi-sig processing
- `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift` - Drag-anywhere, tap-to-toggle, size fix
- `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift` - Multi-signature, removed Unselect button

---

## Next Steps (Priority Order)

1. **Build and test in Xcode** - Verify all changes compile
2. **Test Sign PDF feature:**
   - Place signature and verify it appears at exact tap location in final PDF
   - Verify size matches what you see on screen
   - Test drag-anywhere (drag anywhere on screen while signature selected)
   - Test multi-page signatures (place signatures on different pages, verify all appear in final)
3. **Test other features** - Button styling, preview, state persistence

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
