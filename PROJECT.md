# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-20

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
- **Fixed black text on dark backgrounds (success/result page):**
  - JobResultView.swift: Changed system colors (.secondary, .primary) to OneBoxColors
  - Added dark background (OneBoxColors.primaryGraphite) to the success page
  - Fixed InfoRow component in UIComponents.swift to use proper colors
- **Fixed Split PDF only showing 1 file in preview:**
  - Root cause: saveOutputFilesToDocuments() used same filename for all files
  - All files were overwriting each other with same timestamp-based name
  - Fixed by adding unique index suffix to filenames (e.g., split_pdf_date_1.pdf, split_pdf_date_2.pdf)
- **Fixed "files removed or deleted" error on success page:**
  - Same root cause as above - files now persist with unique names
- **Fixed black text in Merge PDF configuration:**
  - Fixed ReorderableFilePickerRow and ReorderableFileListView in UIComponents.swift
  - Changed .secondary/.primary colors to OneBoxColors equivalents
- All previous fixes remain in place

---

## Last Session Summary

**Date:** 2025-12-20

**What Was Done:**
- **Fixed black text on dark backgrounds (4 issues):**
  1. Success/result page: Added proper colors to JobResultView.swift, added dark background
  2. Split PDF preview: Fixed saveOutputFilesToDocuments() to use unique filenames with index
  3. Files deleted error: Same fix - unique filenames prevent overwriting
  4. Merge PDF config: Fixed ReorderableFilePickerRow and ReorderableFileListView colors

**What's Unfinished:**
- Build not verified (no Xcode in environment) - user should build and test
- Other views (PaywallView, HomeView, PrivacyDashboardView, etc.) still have system colors

**Files Modified This Session:**
- `OneBox/OneBox/Views/JobResultView.swift` - Fixed success page colors and background
- `OneBox/Modules/JobEngine/JobEngine.swift` - Fixed unique filenames for multi-file outputs
- `OneBox/Modules/UIComponents/UIComponents.swift` - Fixed InfoRow and ReorderableFileList colors

---

## Next Steps (Priority Order)

1. **Build and test in Xcode** - Verify all changes compile
2. **Test Sign PDF feature:**
   - Place signature and verify it appears at exact tap location in final PDF
   - Verify size matches what you see on screen
   - Test drag-anywhere (drag anywhere on screen while signature selected)
   - Test multi-page signatures (place signatures on different pages, verify all appear in final)
3. **Test other features** - Button styling, preview, state persistence

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
