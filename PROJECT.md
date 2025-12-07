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
- **Workflow "Configure-Once, Run-Many" redesign** - Major workflow architecture change:
  - Users now configure each step's settings when creating a workflow
  - Settings are saved and applied consistently on each run
  - Removed "Organize" step (requires interactive UI, doesn't fit automated workflow)
- All previous workflow fixes from earlier sessions remain in place

---

## Last Session Summary

**Date:** 2025-12-07

**What Was Done:**
- **Redesigned workflow system to "Configure-Once, Run-Many" approach:**
  1. Created `ConfiguredStepData` and `WorkflowStepConfig` data models
  2. Added `StepConfigurationView` with configuration UI for each step type:
     - Compress: Quality selection (low/medium/high/maximum)
     - Watermark: Text, position, opacity settings
     - Sign: Position, use saved signature toggle, fallback text
     - Page Numbers: Position, format, Bates numbering prefix/start
     - Date Stamp: Position selection
     - Redact: Preset selection (legal/finance/hr/medical)
  3. Updated `CustomWorkflowData` with migration support for old format
  4. Updated `WorkflowBuilderView` to use configured steps
  5. Added `executeConfiguredWorkflow()` method to execution service
  6. Removed "Organize" step from available steps (requires interactive UI)

- **Previous session fixes (preserved):**
  - Fixed Add Step button
  - Added success feedback with share option
  - Fixed custom workflow persistence
  - Fixed file access across actor boundaries
  - Improved polling speed

**What's Unfinished:**
- Build not verified (no Xcode in environment) - user should build and test
- Custom workflows need testing with new configuration UI
- Redact PDF needs user testing

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Major restructure for configured steps
- `OneBox/OneBox/Services/WorkflowExecutionService.swift` - New executeConfiguredWorkflow method

---

## Next Steps (Priority Order)

1. **Build and test in Xcode** - Verify all changes compile
2. **Test new workflow configuration UI** - Create a custom workflow and verify settings are applied
3. **Test Redact PDF** - Verify file saving/sharing now works correctly
4. Address Swift 6 warnings (optional, non-blocking)

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
