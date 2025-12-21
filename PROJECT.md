# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-21

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
- **MAJOR FIX: "Files removed or deleted" preview error:**
  - **Root cause identified:** SwiftUI state race condition - `showPreview` was set to `true` before `previewURL` was updated, causing fullScreenCover to render with nil URL
  - **Solution:** Changed from separate `showPreview` + `previewURL` states to single `PreviewItem` (Identifiable wrapper) with `fullScreenCover(item:)` binding
  - Also simplified file persistence logic in JobEngine.swift
  - Also simplified ensureFileAccessible() in JobResultView.swift
- **Removed misleading "Create Workflow" from feature flow:**
  - Replaced interactive button with informational tip
- **Fixed Ads module build error:**
  - Removed UIComponents dependency, created local AdColors struct
- All previous fixes remain in place

---

## Last Session Summary

**Date:** 2025-12-21

**What Was Done:**
- **Fixed "files removed or deleted" preview error (USER VERIFIED WORKING):**
  - Root cause: SwiftUI state race condition between `showPreview` and `previewURL`
  - Solution: Combined into single `PreviewItem` with `fullScreenCover(item:)` binding
  - Simplified file persistence logic in JobEngine.swift
  - Simplified ensureFileAccessible() in JobResultView.swift
- **Removed misleading "Create Workflow" option from feature flow:**
  - Replaced with informational tip about Workflows feature
- **Fixed Ads module build error:**
  - Created local AdColors struct to avoid UIComponents dependency

**What's Unfinished:**
- None - all reported issues resolved and verified by user

**Files Modified This Session:**
- `OneBox/Modules/JobEngine/JobEngine.swift` - Simplified saveOutputFilesToDocuments() and loadJobs()
- `OneBox/OneBox/Views/JobResultView.swift` - Fixed state race condition with PreviewItem pattern
- `OneBox/OneBox/Views/ToolFlowView.swift` - Removed Create Workflow option, added tip banner
- `OneBox/Modules/Ads/Ads.swift` - Added local AdColors, removed UIComponents dependency

---

## Next Steps (Priority Order)

1. **Continue testing other features** - Sign PDF, Watermark, Redact
2. **Test Recents tab** - Verify old jobs can still preview files
3. **Prepare for App Store submission** - Review checklist

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
