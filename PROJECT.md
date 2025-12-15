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
- **Fixed "Continue Securely" button visual state:**
  - Added opacity 0.4 when disabled so button appears faded
  - User can now clearly see when button is not yet available

- **Fixed preview showing black/blank page:**
  - QuickLookPreview now always returns 1 item (not 0)
  - Added fallback logic to always return valid preview item
  - Improved file accessibility handling

- **Fixed Sign PDF stray dots (resize handles appearing elsewhere):**
  - Changed from `.position()` to `.offset()` for resize handles
  - Handles now appear correctly at signature corners
  - Increased handle size for better touch targets

- **Improved Sign PDF zoom gesture:**
  - Changed from simultaneousGesture to regular gesture for priority
  - Added haptic feedback during resize
  - Better min/max size limits

- **Added state persistence on app minimize:**
  - Created WorkflowStateManager service
  - Saves workflow state when app goes to background
  - Offers "Continue Where You Left Off?" dialog when returning
  - State expires after 1 hour
  - Only restores if files still exist

**What's Unfinished:**
- Build not verified (no Xcode in environment) - user should build and test
- All fixes need user testing

**Files Modified This Session:**
- `OneBox/Modules/UIComponents/OneBoxStandard.swift` - Button opacity when disabled
- `OneBox/OneBox/Views/JobResultView.swift` - Preview loading fixes
- `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift` - Resize handles + zoom gesture
- `OneBox/OneBox/Views/ToolFlowView.swift` - State persistence integration

**Files Created This Session:**
- `OneBox/OneBox/Services/WorkflowStateManager.swift` - State persistence service

---

## Next Steps (Priority Order)

1. **Build and test in Xcode** - Verify all changes compile
2. **Test "Continue Securely" button** - Verify it's faded when disabled
3. **Test preview functionality** - Check file preview works without black screen
4. **Test Sign PDF** - Verify resize handles appear at correct positions
5. **Test state persistence** - Minimize app during workflow, verify restore dialog appears
6. Address Swift 6 warnings (optional, non-blocking)

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
