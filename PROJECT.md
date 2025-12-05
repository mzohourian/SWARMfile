# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-05

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

**Date:** 2025-12-05

**What Was Done:**
- Fixed Organize PDF scrolling - removed conflicting DragGesture that blocked ScrollView
- Fixed Organize PDF selection - pages stay selected after rotation for multi-rotation
- Disabled Organize PDF anomaly detection - too many false positives, no solutions offered
- Fixed Organize PDF file persistence - PageOrganizerView now saves to Documents/Exports
- Fixed Organize PDF multi-page rotation - reloads PDF after each rotation
- Fixed processed files not saving to Files app - centralized fix in JobEngine
  - ALL tools now auto-save to Documents/Exports folder
  - Covers: watermark, merge, split, compress, sign, images-to-pdf, pdf-to-images, etc.
- Fixed watermark SIZE slider - text watermarks were ignoring the size parameter completely
- Improved size range for dramatic visible effect:
  - Images: 5% to 50% of page width (was just 0-100% linear)
  - Text: 2% to 15% of page height (was fixed at 5%)
- Improved density range for dramatic visible effect:
  - Images: 0.6x to 5x spacing (was 1x to 3x)
  - Text: 0.8x to 6x spacing (was 2x to 5x)

**What's Unfinished:**
- All features need user testing to verify fixes work

**Files Modified:**
- `OneBox/OneBox/Views/PageOrganizerView.swift` - Scrolling fix, selection fix, anomaly detection disabled
- `OneBox/Modules/JobEngine/JobEngine.swift` - Centralized auto-save to Documents/Exports
- `OneBox/Modules/CorePDF/CorePDF.swift` - Watermark size and density improvements
- `OneBox/OneBox/Views/ToolFlowView.swift` - Simplified (persistence now in JobEngine)

---

## Next Steps (Priority Order)

1. **Test Watermark PDF** - Verify fix works on real device with large files
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
