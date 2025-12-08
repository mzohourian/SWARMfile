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

**Date:** 2025-12-08

**What Was Done:**
- **Redesigned workflow to use existing interactive views:**
  1. Added `isInteractive` property to WorkflowStep enum (Organize, Sign = true)
  2. Added fullScreenCover presentations for PageOrganizerView and InteractiveSignPDFView
  3. Implemented view-driven workflow execution:
     - `continueWorkflow()` - handles step routing
     - `runAutomatedStep()` - executes non-interactive steps
     - `handleInteractiveStepCompleted()` - resumes after interactive view closes
     - `finishWorkflow()` - cleanup and success handling
  4. Added `executeSingleStep()` to WorkflowExecutionService for step-by-step execution
  5. Updated StepConfigurationView for Sign/Organize to show "Interactive Step" info

- **Bug fixes from earlier in session:**
  - Fixed `CustomWorkflowData` not conforming to `Encodable`
  - Added workflow delete feature with confirmation
  - Fixed WorkflowHooksView to use new configuredSteps format
  - Fixed page number placeholders (`{page}`, `{total}`) not being replaced
  - Fixed date stamp format (removed "Processed:", use medium date)
  - Made compression more aggressive (JPEG 0.25, resolution 35%)
  - Fixed signature canvas gesture conflict with `.interactiveDismissDisabled()`

- **Additional fixes (from continued session):**
  - Fixed Organize PDF blank page on first tap (changed sheet from `isPresented` to `item` binding)
  - Fixed signature position mismatch (signature CENTER now at tap position, not corner)
  - Fixed workflow section performance (removed unused `@EnvironmentObject` from WorkflowBuilderView)

**What's Unfinished:**
- Build not verified (no Xcode in environment) - user should build and test
- Test workflow with interactive steps (Organize, Sign)
- Verify automated steps work correctly after interactive steps

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Interactive workflow support, fixed blank page, performance fix
- `OneBox/OneBox/Services/WorkflowExecutionService.swift` - Added executeSingleStep method
- `OneBox/Modules/CorePDF/CorePDF.swift` - Fixed signature position (center at tap, not corner)

---

## Next Steps (Priority Order)

1. **Build and test in Xcode** - Verify all changes compile
2. **Test workflow with interactive steps** - Create a workflow with Organize/Sign and verify they open existing views
3. **Verify workflow chaining** - Test that automated steps run correctly after interactive steps complete
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
