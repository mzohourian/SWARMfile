# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-06

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
- Page organizer with undo/redo
- Redaction with presets

### Broken / Blocked
- None currently

### Needs Testing
- **Redact PDF** - Completely rebuilt:
  - Fixed file not saving (2 bugs: PDF context timing + ShareSheet deletion)
  - Redaction now actually works on scanned/image-based PDFs
  - Stores OCR bounding boxes and draws black boxes over sensitive text
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
- **Redact PDF completely rebuilt**:
  1. PDF context closed too late (defer block) - fixed by explicit close before file verification
  2. ShareSheet deleting file before sharing - fixed by checking if file already in Documents
  3. Redaction not applying to scanned PDFs - fixed by storing OCR bounding boxes and drawing black boxes
  4. Overly complex UI - removed Automatic/Manual/Combined modes, now single unified flow
- Organize PDF scrolling not working - Removed conflicting DragGesture that consumed scroll events
- Organize PDF selection cleared after rotation - Kept selection after rotate left/right
- Organize PDF false anomaly detection - Disabled feature (too many false positives, no solutions)
- Organize PDF not saving to Files - PageOrganizerView was bypassing JobEngine's file persistence
- Organize PDF multi-page rotation bug - Rotating multiple pages only kept last rotation
- Processed files not saving to Files app - Files now auto-saved to Documents/Exports folder
- Watermark size slider not working - Text watermarks now use size parameter (was ignored)
- Watermark size range too narrow - Improved to 5%-50% (images) and 2%-15% (text)
- Watermark density range too narrow - Improved to 0.6x-5x spacing (was 1x-3x)
- Watermark PDF hang at 27% - Fixed by reducing tiling limits from 50x50 to 15x15
- Crash at 100% completion - Fixed division by zero in ExportPreviewView.swift

---

## Last Session Summary

**Date:** 2025-12-06

**What Was Done:**
- **Completely rebuilt Redact PDF feature:**
  1. Fixed PDF context timing (defer block issue) - applies to 4 CorePDF functions
  2. Fixed ShareSheet deleting files before share (same source/destination path)
  3. Fixed redaction not applying to scanned PDFs - now stores OCR bounding boxes and draws black boxes
  4. Simplified UI - removed Automatic/Manual/Combined modes, now single flow with manual review
- OCR now captures text positions (bounding boxes) for accurate redaction
- Redaction renders pages as images and draws black boxes over detected sensitive text

**What's Unfinished:**
- Redact PDF needs user testing to confirm redactions are applied correctly

**Files Modified:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Fixed PDF context timing in 4 functions
- `OneBox/OneBox/Views/JobResultView.swift` - Fixed ShareSheet deleting files before share
- `OneBox/OneBox/Views/RedactionView.swift` - Rebuilt with OCR bounding boxes and proper redaction

---

## Next Steps (Priority Order)

1. **Test Redact PDF** - Verify file saving/sharing now works correctly
2. Test all features end-to-end
3. Address Swift 6 warnings (optional, non-blocking)

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
