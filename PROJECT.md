# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-11

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
- Multi-language OCR (12 languages including Arabic, Persian, CJK)
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

**Date:** 2025-12-11

**What Was Done:**

**1. Added multi-language OCR support across all Vision-based features:**
- Added 12 languages: English, French, German, Spanish, Italian, Portuguese, Chinese (Simplified & Traditional), Japanese, Korean, Arabic, Persian/Farsi
- Updated 6 files: RedactionView, SignatureFieldDetectionService, AdvancedImageToPDFView, FormFillingStampView, AdaptiveWatermarkView, SmartSplitView
- Enables better text recognition for international documents

**2. Added international phone number detection for redaction:**
- Pattern for formats like +98 21 22283831 (country code + area + local)
- Supports Iranian and other international phone formats

**3. Attempted Persian passport number detection:**
- Added patterns for Persian numerals (۰-۹) and Arabic-Indic numerals (٠-٩)
- Added 8-digit ID number pattern
- Vision OCR may not reliably recognize Persian numerals in passport images
- User can use "Draw to add" for manual redaction of Persian numbers

**Files Modified This Session:**
- `OneBox/OneBox/Views/RedactionView.swift` - International phone + Persian patterns
- `OneBox/OneBox/Services/SignatureFieldDetectionService.swift` - Multi-language OCR
- `OneBox/OneBox/Views/Advanced/AdvancedImageToPDFView.swift` - Multi-language OCR
- `OneBox/OneBox/Views/Advanced/FormFillingStampView.swift` - Multi-language OCR
- `OneBox/OneBox/Views/Advanced/AdaptiveWatermarkView.swift` - Multi-language OCR
- `OneBox/OneBox/Views/Advanced/SmartSplitView.swift` - Multi-language OCR

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
