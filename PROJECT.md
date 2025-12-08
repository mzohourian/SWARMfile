# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-08

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
- Page organizer with undo/redo and tap-to-select
- Redaction with presets
- File preview (QuickLook) - fixed stale path issue

### Broken / Blocked
- None currently (rebuild app to get latest Info.plist)

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

**Date:** 2025-12-08 (continued session)

**What Was Done:**

**1. Fixed multi-page signing in workflows:**
- Root cause: `InteractiveSignPDFView.processSignatures()` only processed the first signature placement
- Fix: Added `SignaturePlacementData` struct and `signaturePlacements` array to JobSettings
- Modified `InteractiveSignPDFView` to convert ALL placements to job settings
- Added `processMultipleSignatures()` in JobEngine to chain sign operations
- All signatures on all pages now apply correctly

**2. Fixed PDF merge page size normalization:**
- Root cause: `mergePDFs()` just inserted pages without scaling
- Fix: Modified merge to find largest page dimensions and scale all pages to match
- Smaller pages are now centered on white background at the target size
- Single-page PDFs no longer appear tiny in merged output

**3. Fixed redaction not applying in workflow:**
- Root cause: Timing issue - `handleInteractiveStepCompleted()` retrieved wrong job
- Fix: Added 500ms delay to ensure job is fully submitted
- Now matches jobs by input filename instead of just grabbing last completed job
- Added logging for debugging

**4. Previous fixes still in place:**
- Preview blank screen fixed (path reconstruction)
- Face ID crash diagnosed (rebuild app needed)

**Files Modified This Session:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - PDF merge page normalization
- `OneBox/Modules/JobEngine/JobEngine.swift` - Multi-signature support, SignaturePlacementData
- `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift` - Process all signature placements
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Fixed interactive step job matching

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
