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
| 1 | **BLOCKER** | App icon image missing | Assets.xcassets/AppIcon.appiconset/ | Need 1024x1024 PNG |
| 2 | Medium | Accessibility labels incomplete | Multiple views | ~50 labels needed |
| 3 | Low | Swift 6 concurrency warnings (3) | MultipeerDocumentService, OnDeviceSearchService | Non-blocking |
| 4 | Info | "Update to recommended settings" | Xcode project | Informational |

**Resolved This Session:**
- **Repurposed Biometric Lock for real security** - Now locks the entire app (not just processing)
  - App-level lock screen with Face ID/Touch ID
  - Re-locks automatically when app goes to background
  - Secure Vault requires biometric to access encrypted files
- **Fixed critical Face ID crash** - Added NSFaceIDUsageDescription to project.yml for XcodeGen
- **Fixed invalid SF Symbol** - Replaced non-existent "vault.fill" with "lock.shield.fill" in PrivacyDashboardView
- **Fixed MainActor isolation crashes** when all privacy features enabled:
  - JobEngine.swift: Wrapped privacyDelegate calls in MainActor.run { }
  - Cached zeroTraceEnabled to avoid synchronous MainActor access from non-isolated context
  - Fixed deleteJob and processJob secure file cleanup
- **Fixed PBKDF2 encryption crashes** (Privacy.swift):
  - Fixed 4 force unwraps in key derivation
  - Fixed type mismatch: Int32 for CCKeyDerivationPBKDF result
  - Added password validation (reject empty passwords)
  - Fixed salt generation with safe guard check
- **Enforced dark-only aesthetic** - ThemeManager simplified to always return .dark
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
- **Fixed 4 crash risks found in pre-launch audit:**
  - InteractivePDFPageView.swift: Force unwrap on graphics context → guard let
  - CorePDF.swift: Missing guard on watermark PDF context creation
  - CorePDF.swift: Force unwrap `as!` on file size check → safe cast
  - RedactionView.swift: Silent failure if graphics context nil → proper error handling
- **Fixed file preview edge case** in JobResultView (missing file check in QuickLook fallback)

---

## Last Session Summary

**Date:** 2025-12-21 (Continued Session - Biometric Repurposing)

**What Was Done:**
- **Repurposed Biometric Lock to provide real security:**
  - App-level lock: Face ID/Touch ID required to open the app
  - Lock screen shows when app launches if enabled
  - App re-locks when going to background
  - Removed pointless "before processing" authentication
- **Vault biometric access**: Secure Vault now requires biometric to access encrypted files
- **Fixed critical Face ID crash** - NSFaceIDUsageDescription was in Info.plist but missing from project.yml
- **Fixed invalid SF Symbol** - "vault.fill" doesn't exist, replaced with "lock.shield.fill"
- **Fixed MainActor isolation crashes** - Privacy delegate calls properly wrapped in MainActor.run
- **Fixed PBKDF2 encryption crashes** - Fixed force unwraps and type mismatches
- **Enforced dark-only aesthetic** - ThemeManager simplified for dark-only

**What's Unfinished:**
- None - all changes completed

**Files Modified This Session:**
- `OneBox/OneBox/OneBoxApp.swift` - Added AppLockContainer, LockScreenView, scenePhase handling
- `OneBox/Modules/Privacy/Privacy.swift` - Added isAppUnlocked, authenticateToUnlockApp(), lockApp(), authenticateForVaultAccess()
- `OneBox/OneBox/Views/PrivacyDashboardView.swift` - Updated toggle descriptions
- `OneBox/project.yml` - Added NSFaceIDUsageDescription to XcodeGen config

---

## Next Steps (Priority Order)

1. **BLOCKER: Add app icon** - Create 1024x1024 PNG and add to AppIcon.appiconset
2. **Add accessibility labels** - ~50 labels needed across PaywallView, ToolFlowView, HomeView
3. **Final device testing** - Test all features on physical device before submission

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
