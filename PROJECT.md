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
- **Redact PDF - Precise character-level redaction**:
  1. Previous issue: Was redacting entire text lines when any part matched (wrong text blacked out)
  2. Root cause: Used block-level bounding boxes instead of character-level
  3. Fix: Store `VNRecognizedText` objects during OCR, use `boundingBox(for: Range)` to get precise location of only the matched substring
  4. Now only the exact sensitive text is redacted, not surrounding text
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
- **Fixed Redact PDF precision** - was redacting entire lines, now redacts only exact text:
  1. Previous: Matching any part of an OCR text block would redact the entire block (full lines)
  2. User showed screenshots: wrong text was blacked out, actual sensitive data (passport numbers, phones) was NOT redacted
  3. Root cause: `blocksToRedact` filter was too loose, and we used block-level bounding boxes
  4. Fix: Store `VNRecognizedText` objects during OCR, search for exact matches in each block, use `boundingBox(for: Range)` to get character-level bounding box for just the matched substring
  5. Now only the precise sensitive text is redacted, not the surrounding text on the same line

**What's Unfinished:**
- Redact PDF needs user testing to confirm precise redaction works correctly

**Files Modified:**
- `OneBox/OneBox/Views/RedactionView.swift` - Character-level bounding boxes for precise redaction

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
