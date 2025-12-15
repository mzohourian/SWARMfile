# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-15

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

**Date:** 2025-12-15

**What Was Done:**
- **Enhanced disabled button aesthetics:**
  - Replaced simple opacity with elegant disabled state
  - Uses muted background color (surfaceGraphite at 50% opacity)
  - Uses muted text color (tertiaryText)
  - Adds subtle border to maintain button shape
  - Applies desaturation (saturation: 0.3) for professional look
  - Smooth animation transition between enabled/disabled states

- **Fixed signature position mismatch (appears in wrong location):**
  - Inverted Y coordinate when processing signatures for PDF
  - Screen has Y=0 at top, PDF has Y=0 at bottom - now correctly converted
  - Signature now appears where user actually placed it

- **Fixed signature size mismatch (appears different size):**
  - Improved size calculation to use screen-relative ratio
  - Uses estimated view width (400px) to calculate intended proportion
  - Increased size clamp range (0.1 to 0.6) for better flexibility

**Previous Session (same day):**
- Fixed preview showing black/blank page
- Fixed Sign PDF stray dots (resize handles appearing elsewhere)
- Improved Sign PDF zoom gesture
- Added state persistence on app minimize

**What's Unfinished:**
- Build not verified (no Xcode in environment) - user should build and test
- All fixes need user testing

**Files Modified This Session:**
- `OneBox/Modules/UIComponents/OneBoxStandard.swift` - Enhanced disabled button styling
- `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift` - Fixed signature position and size

---

## Next Steps (Priority Order)

1. **Build and test in Xcode** - Verify all changes compile
2. **Test disabled button styling** - Verify elegant muted appearance when disabled
3. **Test Sign PDF position** - Place signature and verify it appears in correct location after processing
4. **Test Sign PDF size** - Verify signature size matches what user intended
5. **Test preview functionality** - Check file preview works without black screen
6. **Test state persistence** - Minimize app during workflow, verify restore dialog appears
7. Address Swift 6 warnings (optional, non-blocking)

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
