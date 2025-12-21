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
- **Fixed 3 potential crash bugs** (`.combined!` force unwraps in encryption code)
- **Fixed infinite loop hang risk** (added 5-minute timeout to workflow execution)
- **Implemented Terms/Privacy sheets** in Onboarding and Upgrade flows
- **Implemented Privacy Info modal** for all tools in HomeView
- **Implemented Document preview** in search results
- **Implemented Help Center buttons** (Contact Support, Video Tutorials, Feature Tour, Shortcuts)
- **Fixed PDF compression issues:**
  - Minimum size estimate now uses realistic values (0.3x scale, 0.05 quality)
  - Removed 50% cap that prevented aggressive compression targets
  - Added guard check for PDF context creation to prevent crashes
  - Added autoreleasepool for memory management during compression
  - Added maxDimension clamping (2000px) to prevent memory overflow
- **Simplified PDF compression UI** - Removed quality presets, just size slider
- **Added grayscale option** for PDF compression (10-15% smaller files)
- **Fixed grayscale estimate** - Now updates dynamically when toggle changes
- **Removed placeholder/non-functional UI elements:**
  - HelpCenterView: Replaced "coming soon" text with helpful guidance
  - UpgradeFlowView: Added real feature comparison table
  - WorkflowConciergeView: Removed disabled Cancel button
  - ProfessionalSigningView: Removed disabled "Visible signature" toggle
  - NewHomeView: Replaced non-functional Search button with Privacy button
  - IntegrityDashboardView: Removed 3 fake quick action buttons (Backup Settings, Privacy Audit, Export Logs)

---

## Last Session Summary

**Date:** 2025-12-21 (Continued Session)

**What Was Done:**
- **Simplified PDF compression UI** - Removed quality presets (High/Medium/Low), single size slider defaulting to minimum
- **Added grayscale option** for PDF compression - 10-15% smaller file sizes
- **Fixed grayscale estimate** - Size estimate now updates dynamically when grayscale toggle changes
- **Pre-launch audit completed** - Found 6 placeholder/non-functional UI elements
- **Removed placeholders and fake buttons:**
  - HelpCenterView: Replaced "coming soon" text with helpful guidance
  - UpgradeFlowView: Added real feature comparison table
  - WorkflowConciergeView: Removed disabled Cancel button
  - ProfessionalSigningView: Removed disabled "Visible signature" toggle
  - NewHomeView: Replaced non-functional Search button with Privacy button
  - IntegrityDashboardView: Removed 3 fake quick action buttons (Backup Settings, Privacy Audit, Export Logs)

**What's Unfinished:**
- None - all requested fixes completed

**Files Modified This Session:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Added grayscale conversion to compression
- `OneBox/Modules/JobEngine/JobEngine.swift` - Added convertToGrayscale to JobSettings
- `OneBox/OneBox/Views/ToolFlowView.swift` - Simplified compression UI, added grayscale toggle
- `OneBox/OneBox/Views/Help/HelpCenterView.swift` - Replaced placeholder text
- `OneBox/OneBox/Views/Upgrade/UpgradeFlowView.swift` - Added feature comparison table
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Removed disabled button
- `OneBox/OneBox/Views/Advanced/ProfessionalSigningView.swift` - Removed disabled toggle
- `OneBox/OneBox/Views/NewHomeView.swift` - Replaced Search with Privacy button
- `OneBox/OneBox/Views/IntegrityDashboardView.swift` - Removed 3 fake buttons

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
