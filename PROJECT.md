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
- **Removed swipe-to-select from Page Organizer:**
  - After 5+ attempts, SwiftUI gesture conflicts with ScrollView proved too complex
  - Reverted to simple tap-to-select and drag-to-reorder (works reliably)

- **Fixed preview showing blank screen throughout app:**
  - Root cause: iOS changes app container UUID on updates, breaking saved file paths
  - Example: `/var/.../ABC123/Documents/file.pdf` → `/var/.../XYZ789/Documents/file.pdf`
  - Fix: Added path reconstruction in `JobEngine.loadJobs()` that extracts relative path from "Documents" and rebuilds with current directory
  - Preview (QuickLook) now works for all exported files

**What's Unfinished:**
- **Workflow crash with Face ID** - App crashes with missing `NSFaceIDUsageDescription` when running workflow with biometric lock enabled
  - The key ALREADY EXISTS in Info.plist (line 27-28)
  - **Solution: Rebuild and reinstall the app in Xcode** to include updated Info.plist

**Files Modified This Session:**
- `OneBox/OneBox/Views/PageOrganizerView.swift` - Simplified to tap-to-select only
- `OneBox/Modules/JobEngine/JobEngine.swift` - Added file path reconstruction for stale URLs

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
