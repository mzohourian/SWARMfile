# PROJECT.md - Current State Dashboard

**Last Updated:** 2025-12-11

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
- PDF signing (interactive, touch-to-place, multi-page support)
- Image resize and compress
- Job queue with progress tracking
- Free tier (3 exports/day)
- Pro subscriptions (StoreKit 2)
- On-device search
- Workflow automation
- Page organizer with undo/redo and tap-to-select
- Redaction - visual-first editing (tap to remove, draw to add)
- Multi-language OCR (12 languages including Arabic, Persian, CJK)
- File preview (QuickLook) - fixed stale path issue

### Broken / Blocked
- None currently (rebuild app to get latest Info.plist)

### Needs Testing
- **Redact PDF** - Completely redesigned with visual-first approach:
  - Shows document preview with black boxes overlaid on detected sensitive data
  - Tap any box to REMOVE it (becomes gray/dashed outline)
  - Draw/drag on page to ADD new redaction boxes
  - Pinch-to-zoom or use +/- buttons for better visibility (up to 500%)
  - **NEW:** Full-screen mode button for maximum visibility and precise editing
  - Bottom bar shows count and "Apply X Redactions" button
  - Works on both text-based and scanned/image PDFs via OCR
  - **FIXED:** Pattern matching now uses OCR text to ensure bounding boxes are found
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
- **PDF "Invalid PDF" error** - Fixed security-scoped resource access:
  - PDFs from document picker/iCloud require `startAccessingSecurityScopedResource()` before loading
  - Added proper resource access to: merge, split, compress, redact, fillFormFields
  - Ensures cleanup with `defer` and proper error handling
- **Signature placement** - Fixed Y-coordinate inversion and normalization
- **PNG rejection** - Fixed broken format validation logic (was checking characters, not extension)
- **Face ID** - Added @MainActor for LocalAuthentication on main thread
- **Crash on proceed** - Added missing environment objects to IntegrityDashboardView/HomeView
- **PDF password protection** - Implemented native PDF encryption with user password input

---

## Last Session Summary

**Date:** 2025-12-11

**What Was Done:**

**1. Fixed PDF loading "Invalid PDF" errors:**
- Root cause: `PDFDocument(url:)` returns nil for files from document picker/iCloud without security-scoped access
- Added `startAccessingSecurityScopedResource()` to: merge, split, compress, redact, fillFormFields
- Proper cleanup with `defer` and error handling for cleanup before throwing

**2. Fixed signature placement issues:**
- Removed Y-coordinate flip (UIKit coordinates, not PDF coordinates)
- Fixed coordinate normalization to account for scaled/centered PDF pages

**3. Fixed PNG image rejection:**
- Bug: format validation checked if any CHARACTER was in array, not the whole extension
- Fixed to check if extension string is in supported formats array

**4. Fixed Face ID not triggering:**
- LocalAuthentication must run on main thread
- Added @MainActor to `authenticateForProcessing()` and protocol

**5. Fixed app crash on "Proceed":**
- Missing `@EnvironmentObject` for `paymentsManager` and `jobManager`
- Added to IntegrityDashboardView and LegacyHomeView

**6. Implemented PDF password protection:**
- Added password input field in ToolFlowView
- Native PDFKit encryption using `PDFDocumentWriteOption.userPasswordOption`

**Files Modified This Session:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Security-scoped access, signature fix, format fix, password protection
- `OneBox/OneBox/Services/Privacy.swift` - @MainActor for biometric auth
- `OneBox/Modules/JobEngine/JobEngine.swift` - PDF-native encryption
- `OneBox/OneBox/Views/ToolFlowView.swift` - Password input field
- `OneBox/OneBox/Views/WorkflowAutomationView.swift` - Password capture
- `OneBox/OneBox/Views/IntegrityDashboardView.swift` - Environment objects
- `OneBox/OneBox/Views/HomeView.swift` - Environment objects
- `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift` - Coordinate normalization

---

## Next Steps (Priority Order)

1. **REBUILD APP IN XCODE** - Critical: get latest fixes including security-scoped access
2. **Test PDF merge** - Should now work with files from document picker/iCloud
3. **Test preview function** - Verify QuickLook now shows files properly
4. **Test workflow with biometric lock** - Should work after rebuild
5. **Test Redact PDF** - Verify file saving/sharing works correctly
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
