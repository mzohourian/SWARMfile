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
- **Redact PDF - Fixed coordinate transformation bug**:
  1. Previous issue: Black boxes appeared in wrong positions (random places instead of over sensitive text)
  2. Root cause: Vision uses bottom-left origin (Y up), UIKit PDF context uses top-left origin (Y down)
  3. Fix: Proper Y coordinate conversion: `y = pageHeight * (1 - visionY - visionHeight)`
  4. Added fallback: If character-level bounding box fails, estimate position from character ratios
  5. Fixed thread safety: Capture OCR results from main thread before processing
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
- **Rebuilt Workflow feature completely:**
  1. Added missing workflow steps: `.redact`, `.addPageNumbers`, `.addDateStamp`, `.flatten`
  2. Fixed step mappings in WorkflowExecutionService (organize now uses pdfOrganize, not pdfMerge)
  3. Added professional industry presets:
     - **Legal Discovery** - redact, Bates numbering, date stamp, flatten, compress
     - **Contract Execution** - merge, flatten, sign, watermark, compress
     - **Financial Report** - redact account numbers, CONFIDENTIAL watermark, date stamp
     - **HR Documents** - redact SSN/personal data, INTERNAL watermark, page numbers
     - **Medical Records** - HIPAA-compliant redaction, date stamp, watermark
     - **Merge & Archive** - combine documents with page numbers and date stamp
  4. Added step configuration capability (watermark text, redaction presets, Bates prefix)
  5. Updated JobSettings with new properties for page numbering, date stamps, form flattening

**What's Unfinished:**
- Redact PDF needs user testing to confirm precise redaction works correctly
- Workflow feature needs user testing

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Added new steps and professional templates
- `OneBox/OneBox/Services/WorkflowExecutionService.swift` - Fixed step mappings and added configuration
- `OneBox/Modules/JobEngine/JobEngine.swift` - Added new JobSettings properties

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
