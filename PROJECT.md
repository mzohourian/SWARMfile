# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-04

## What This Is
**OneBox** is a privacy-first iOS/iPadOS app for processing PDFs and images entirely on-device. No cloud uploads, no tracking. Think of it as a Swiss Army knife for documents that respects your privacy.

**Target Users:** Anyone who works with PDFs and images on iPhone/iPad and cares about privacy.

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
- **Watermark PDF hangs at 27%** - Critical, prevents feature from working

### Needs Testing
- Some advanced workflow features may need verification

---

## Known Issues

| # | Severity | Issue | Location | Status |
|---|----------|-------|----------|--------|
| 1 | CRITICAL | Watermark PDF hangs at 27% | `CorePDF.swift` watermark function | Under investigation |
| 2 | Low | Swift 6 concurrency warnings (3) | MultipeerDocumentService, OnDeviceSearchService | Non-blocking |
| 3 | Info | "Update to recommended settings" | Xcode project | Informational |

---

## Last Session Summary

**Date:** 2025-12-04

**What Was Done:**
- Fixed "Begin Secure Processing" button not responding (HapticManager issue)
- Fixed watermark infinite loading at 100%
- Added debugging logs to watermark processing
- Improved memory management in watermark function

**What's Unfinished:**
- Watermark still hangs at 27% (new issue after previous fixes)

**Files Modified:**
- `OneBox/Views/ToolFlowView.swift`
- `Modules/CorePDF/CorePDF.swift`

---

## Next Steps (Priority Order)

1. **Fix Watermark PDF 27% hang** - Debug logs are in place, need to identify exact hang location
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
