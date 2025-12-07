# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-07

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
- **Workflow "Add Step" button not working** - Button set state variable that was never used, and available steps grid was hidden when no steps selected. Fixed by always showing steps grid.
- **Workflow completing silently** - After workflow ran, no success feedback was shown. Added success alert with "Share Result" option.
- **Custom workflow not showing after save** - Parent view only loaded workflows onAppear. Added onChange to reload when builder sheet dismisses.
- **Workflow "Invalid input files" error** - Security-scoped URLs not accessible across actor boundaries. Fixed by copying input files to temp directory before processing.
- **Workflow slowness** - Reduced polling interval from 500ms to 100ms for job completion, and 200ms to 50ms for UI updates.

---

## Last Session Summary

**Date:** 2025-12-07

**What Was Done:**
- **Fixed Workflow "Create Custom Workflow" - Add Step button:**
  1. Removed unused `showingStepPicker` state variable
  2. Changed layout to always show available steps grid (was hidden when no steps selected)
  3. Users can now tap any step to add it to their workflow
- **Fixed Workflow success feedback:**
  1. Added success alert when workflow completes ("Workflow Complete")
  2. Added "Share Result" button to share processed files
  3. Added progress monitoring to show correct step number during execution
- **Fixed custom workflow not appearing after save:**
  1. Added onChange handler to reload workflows when builder sheet dismisses
- **Fixed "Invalid input files" error:**
  1. Copy security-scoped input files to temp directory before processing
  2. Added validation that output files exist before passing to next step
  3. Added validation that input files exist before submitting jobs
- **Improved workflow speed:**
  1. Reduced job completion polling from 500ms to 100ms
  2. Reduced UI update polling from 200ms to 50ms

**What's Unfinished:**
- Workflow templates need user testing to verify they run correctly
- Redact PDF needs user testing

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Fixed Add Step, success feedback, reload on dismiss
- `OneBox/OneBox/Services/WorkflowExecutionService.swift` - Fixed file access, added validation, improved speed

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
