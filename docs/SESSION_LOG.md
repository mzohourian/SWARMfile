# Session Log

*Chronological record of all development sessions.*

---

## 2026-01-05: Accessibility Labels + Beta Testing Mode

**Focus:**
1. Add VoiceOver accessibility labels across all key views
2. Enable beta testing mode for TestFlight distribution

**Issues Addressed:**
- ~50 accessibility labels missing across PaywallView, NewHomeView, ToolFlowView
- Beta testers need full access to all Pro features

**Changes Made:**

**Accessibility Labels:**

**PaywallView.swift (~15 labels):**
- Close button: label + hint
- Header logo: combined ZStack with descriptive label
- "Unlock All Features" header trait
- FeatureRow: combined icon+text with label
- ProductCard: full accessibility description with price, period, savings, selection state
- Purchase button: dynamic label based on state, hint for guidance
- Restore button: label + hint
- Fine print: combined text with full subscription terms

**NewHomeView.swift (~20 labels):**
- VaultLogoWithText: descriptive label
- "100% Offline" badge: combined element with explanation
- Usage status: exports remaining with dynamic count
- Go Pro button: label + hint
- Tools section header trait
- Tool cards: combined label with name, description, security note, button trait + hint
- Quick actions buttons: label + hint
- Workflow Concierge link: label + hint
- Integrity dashboard: header trait, View Dashboard button
- Dashboard stats: combined labels (title: value)
- Search results: label + hint
- ToolPrivacyInfoView: privacy badge, section headers, privacy points, data handling rows, Done button

**ToolFlowView.swift (~15 labels):**
- Cancel button: label + hint
- Back button: label + hint
- Empty state: header trait, security badge label, privacy features combined
- File cards: combined label with filename/size, remove button with specific file label
- Continue button: dynamic label based on file count, hint
- ProcessingView: header trait, progress percentage, security guarantees combined

**Beta Testing Mode (Payments.swift):**
- Added `isBetaTesting = true` flag at line 49
- Modified `hasPro` computed property: returns `true` when beta mode enabled
- Bypasses 3/day export limit for all TestFlight users
- **⚠️ CRITICAL: Set `isBetaTesting = false` before App Store release**

**Files Modified:**
- `OneBox/OneBox/Views/PaywallView.swift`
- `OneBox/OneBox/Views/NewHomeView.swift`
- `OneBox/OneBox/Views/ToolFlowView.swift`
- `OneBox/Modules/Payments/Payments.swift`

**Result:**
- App fully accessible for VoiceOver users
- All Pro features unlocked for Reddit beta testers
- Ready for TestFlight distribution

---

## 2026-01-05: Placeholder Cleanup, Fastlane & Sign PDF Fix

**Focus:**
Remove all remaining placeholder identifiers (com.onebox), configure Fastlane for screenshots, and fix Sign PDF black background bug.

**Issues Addressed:**
1. Multiple `com.onebox` placeholders still in codebase (queue labels, background task IDs, product IDs)
2. Fastlane using wrong app identifier and project reference
3. Snapfile using old simulator device names (iPhone 15 vs iPhone 17)
4. Sign PDF showing black background instead of white PDF pages
5. Documentation with incorrect pricing ($49.99 → $69.99)

**Changes Made:**

**Placeholder Cleanup:**
- `project.yml`, `Info.plist`: BGTaskScheduler ID `com.onebox.process` → `com.spuud.vaultpdf.process`
- `JobEngine.swift`: Queue label `com.onebox.jobengine` → `com.spuud.vaultpdf.jobengine`
- `MultipeerDocumentService.swift`: Queue labels updated
- `OnDeviceSearchService.swift`: Index queue and domain IDs updated
- `Payments.swift`: Product IDs `com.vaultpdf.pro.*` → `com.spuud.vaultpdf.pro.*`
- `PaymentsTests.swift`: Test assertions updated for new product IDs
- `CorePDF.swift`: PDF metadata creator and error messages ("OneBox" → "Vault PDF")

**Fastlane Configuration:**
- `Fastfile`: Changed APP_IDENTIFIER from placeholder to `com.spuud.vaultpdf`, changed WORKSPACE to PROJECT
- `Snapfile`: Updated devices for Xcode 17 simulators:
  - iPhone 17 Pro Max (6.7" - required)
  - iPhone 17 Pro (6.1" - required)
  - iPad Pro 13-inch (M5)

**Sign PDF Black Background Fix:**
- Root cause: `InteractivePDFPageView` had `backgroundColor = .clear` and `isOpaque = false`
- The clear background showed the dark parent view through the PDF page
- Fix: Changed to `backgroundColor = .white` and `isOpaque = true`
- Added white fill in `draw()` method before rendering PDF content

**Documentation Updates:**
- README.md, CONTRIBUTING.md, APP_STORE_SUBMISSION_CHECKLIST.md, SUBMISSION_BUILD_GUIDE.md, ScreenSpecifications.md
- Fixed all `com.yourcompany.onebox` → `com.spuud.vaultpdf`
- Fixed all `yourcompany/onebox` → `mzohourian/vault-pdf`
- Corrected lifetime price $49.99 → $69.99

**Files Modified:**
- `OneBox/fastlane/Fastfile`
- `OneBox/fastlane/Snapfile`
- `OneBox/project.yml`
- `OneBox/OneBox/Info.plist`
- `OneBox/Modules/JobEngine/JobEngine.swift`
- `OneBox/Modules/Networking/MultipeerDocumentService.swift`
- `OneBox/OneBox/Services/OnDeviceSearchService.swift`
- `OneBox/Modules/Payments/Payments.swift`
- `OneBox/Tests/PaymentsTests/PaymentsTests.swift`
- `OneBox/Modules/CorePDF/CorePDF.swift`
- `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`
- Multiple documentation files

**Commits:**
- Fix Sign PDF black background - use white background for PDF rendering
- Update Snapfile devices for Xcode 17 simulators
- Update lifetime price to $69.99 in all documents
- Update documentation with correct identifiers and URLs

**Status:** TestFlight build 1.0.0 (7) uploaded. Sign PDF fix needs device testing. Screenshot automation captured iPad only (iPhone screenshots may need debugging).

---

## 2025-12-28: Pricing, Payments & TestFlight Setup

**Focus:**
Complete pricing configuration, fix payment UI issues, and set up TestFlight for beta testing.

**Issues Addressed:**
1. Product IDs using old `com.onebox.*` pattern
2. "Go Pro" button on home screen not working
3. Savings percentage showing 0% instead of ~50%
4. Bundle IDs reverting to generic values on rebuild

**Changes Made:**

**Pricing Configuration:**
- Set up 3 in-app purchases in App Store Connect
- Monthly: $4.99, Yearly: $29.99, Lifetime: $69.99
- Added localizations in 8 languages (EN-US, EN-UK, EN-AU, ES, FR, FR-CA, DE, ZH)
- Created Products.storekit for local testing

**Product ID Updates:**
- Changed from `com.onebox.pro.*` to `com.vaultpdf.pro.*`
- Updated Payments.swift, Products.storekit, SUBMISSION_BUILD_GUIDE.md

**PaywallView Fixes:**
- Fixed "Go Pro" button action (was empty, now shows PaywallView)
- Changed icon from sparkles to crown
- Added fallback calculation for savings percentage

**Bundle ID Fixes:**
- Updated project.yml with correct bundle IDs
- Main app: `com.spuud.vaultpdf`
- All modules: `com.spuud.vaultpdf.*`
- Prefix: `com.spuud`

**TestFlight Setup:**
- Uploaded first build to TestFlight
- Configured encryption compliance (None)
- Provided step-by-step guide for internal/external testing

**Files Modified:**
- `OneBox/project.yml` - All bundle IDs
- `OneBox/Modules/Payments/Payments.swift` - Product IDs, resetDailyExports()
- `OneBox/OneBox/Views/NewHomeView.swift` - "Go Pro" button action
- `OneBox/OneBox/Views/PaywallView.swift` - Savings calculation
- `OneBox/OneBox/Products.storekit` - Product IDs
- `OneBox/SUBMISSION_BUILD_GUIDE.md` - Bundle ID, pricing

**Commits:**
- Complete pricing configuration and payment system fixes
- Update product IDs from onebox to vaultpdf
- Fix paywall button and savings calculation
- Fix bundle IDs in project.yml

**Status:** Ready for new TestFlight build with corrected product IDs

---

## 2025-12-27: Redaction Gesture & Flickering Fixes

**Focus:**
Fix multiple issues with redaction box interaction - delete button behavior, gesture recognition, and flickering during move/resize.

**Issues Addressed:**
1. Delete button was deleting ALL boxes instead of just the focused one
2. Boxes weren't receiving tap/drag gestures properly
3. Boxes flickered and jumped when moving or resizing

**Changes Made:**

**Delete Button Fix:**
- Added `focusedBoxId` state separate from `isSelected` (which determines redaction)
- Delete button now only appears when a box is focused
- Delete action only removes the specific focused box

**Gesture Recognition Fix:**
- Added explicit `.zIndex(0)` to background tap layer and `.zIndex(1)` to boxes
- Changed from `.offset()` to `.position()` for proper hit testing
- Removed full-page frame wrapper from each box that was interfering
- Added `.contentShape(Rectangle())` before gestures

**Flickering Fix:**
- Root cause: Temporary offset state (`dragOffset`) reset to zero before new position applied
- Solution: Replace temporary offsets with delta-based direct updates
- Now track `lastDragLocation`/`lastResizeLocation` to calculate movement delta
- Update `normalizedRect` directly during drag - no temporary state to reset
- Added `moveBoxDirectly()` and `resizeBoxDirectly()` functions

**Files Modified:**
- `OneBox/OneBox/Views/RedactionView.swift` - Major gesture and positioning overhaul

**Commits:**
- Fix redaction delete button and coordinate system
- Fix redaction box selection and resize gestures
- Fix redaction box flickering during move and resize

**Status:** Fixes applied, device testing recommended to verify

---

## 2025-12-22: Premium UI Redesign - Home Screen Hero & Usage Sections

**Focus:**
Complete redesign of home screen for premium, minimal, luxury aesthetic.

**Issues Addressed:**
1. Hero section was cluttered with gimmicky elements (100% SECURE dial, 3 green privacy badges)
2. Tool cards had off-brand green "SECURE" text badges
3. Usage section had negative framing ("X of 3 used")
4. Logo needed to be more prominent with embedded tagline

**Changes Made:**

**Hero Section Complete Redesign:**
- Removed: `safeDial` function (100% SECURE circular dial)
- Removed: `privacyGuarantees` section (3 green badges: No Cloud, No Tracking, Encrypted)
- Removed: `privacyGuaranteeItem` helper function
- Added: Branded logo with embedded tagline (vaultpdf_sub_transparent2.png)
- Added: Single elegant "100% Offline" gold badge
- Fine-tuned positioning: 280pt height, -50pt top padding for minimal margin

**Tool Cards Refined:**
- Removed: Green "SECURE" text badges from each tool card
- Added: Subtle gold shield icon (`shield.fill`) with 60% opacity
- Cleaner appearance matching gold/black premium palette

**Usage Section Redesigned:**
- Changed from "X of 3 secure exports used" to "X free exports left" (positive framing)
- Added elegant gold dot indicators for remaining exports
- Added premium gold gradient "Unlock Unlimited" CTA button

**Logo Iterations:**
- Started with separate logo + "Fort Knox of PDF Apps" text
- Evolved to logo with embedded "Your documents never leave" tagline
- Multiple sizing iterations (200pt → 320pt → final 280pt)
- Multiple position iterations (top padding: -12 → -60 → final -50)
- Final: vaultpdf_sub_transparent2.png at 280pt height

**Files Modified:**
- `OneBox/OneBox/Views/NewHomeView.swift` - Complete hero and usage section redesign
- `OneBox/OneBox/Assets.xcassets/VaultLogoWithText.imageset/Contents.json` - Updated to vaultpdf_sub_transparent2.png
- `OneBox/OneBox/Assets.xcassets/VaultLogoWithText.imageset/` - Multiple logo files added

**Status:** UI polish complete, all changes functional

---

## 2024-12-22: App Store Preparation - MultipeerConnectivity Removal & URL Updates

**Focus:**
Address App Store submission blockers identified in previous analysis.

**Issues Addressed:**
1. MultipeerConnectivity feature removed for v1.0 (requires Local Network permission)
2. Placeholder URLs updated to real contact info (spuud.com, hello@spuud.com)
3. Privacy policy date fixed to current date

**Changes Made:**

**MultipeerConnectivity Removal (SecureCollaborationView.swift):**
- Removed `import MultipeerConnectivity`
- Removed multipeerService StateObject and related state variables
- Removed PeerDiscoveryView sheet and struct
- Removed peerToPeer case from ShareMethod enum
- Updated uploadSecureDocument to use local share URLs
- Added comment noting MultipeerDocumentService.swift available for future expansion

**URL Updates:**
- SettingsView.swift: Report an Issue, Report a Bug, Request a Feature → hello@spuud.com
- HelpCenterView.swift: Email Support → hello@spuud.com
- PRIVACY_POLICY.md: Support email → hello@spuud.com, date → December 22, 2024
- README.md: Support section → spuud.com, hello@spuud.com
- CONTRIBUTING.md: Contact info → hello@spuud.com, title → Vault PDF
- QUICKSTART.md: Support section → spuud.com, hello@spuud.com
- APP_STORE_SUBMISSION_CHECKLIST.md: Support email → hello@spuud.com

**Files Modified:**
- `OneBox/OneBox/Views/Advanced/SecureCollaborationView.swift`
- `OneBox/OneBox/Views/SettingsView.swift`
- `OneBox/OneBox/Views/Help/HelpCenterView.swift`
- `OneBox/PRIVACY_POLICY.md`
- `OneBox/README.md`
- `OneBox/CONTRIBUTING.md`
- `OneBox/QUICKSTART.md`
- `OneBox/APP_STORE_SUBMISSION_CHECKLIST.md`

**Outstanding:**
- App icon still needs 1024x1024 PNG (logo files not found in doc directory)

---

## 2025-12-21: Pre-Launch Audit + Placeholder Cleanup (Continued Session)

**Focus:**
Pre-launch audit to remove all placeholder/non-functional UI elements.

**Issues Addressed:**
1. PDF compression UI too complex (quality presets unnecessary)
2. Grayscale option missing for compression
3. Grayscale size estimate not updating dynamically
4. Placeholder/non-functional UI elements throughout app

**Fixes Applied:**

**Phase 1: PDF Compression Improvements**
- Simplified UI: Removed quality presets (High/Medium/Low), single size slider
- Added grayscale toggle for 10-15% smaller files
- Fixed estimate to update when grayscale toggled (separated base vs computed values)

**Phase 2: Pre-Launch Audit**
- Identified 6 placeholder/non-functional elements
- Conducted detailed audit of Integrity Dashboard functionality

**Phase 3: Placeholder/Fake UI Removal**
- HelpCenterView: Replaced "Articles coming soon..." with helpful guidance
- HelpCenterView: Replaced video tutorials placeholder with redirect message
- UpgradeFlowView: Added actual feature comparison table (was "coming soon")
- WorkflowConciergeView: Removed disabled Cancel button
- ProfessionalSigningView: Removed disabled "Visible signature" toggle
- NewHomeView: Replaced non-functional Search button with Privacy button
- IntegrityDashboardView: Removed 3 fake quick action buttons:
  - Backup Settings (only played haptic)
  - Privacy Audit (only refreshed page)
  - Export Logs (only played haptic)

**Files Modified:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Grayscale conversion
- `OneBox/Modules/JobEngine/JobEngine.swift` - convertToGrayscale setting
- `OneBox/OneBox/Views/ToolFlowView.swift` - Simplified compression UI
- `OneBox/OneBox/Views/Help/HelpCenterView.swift` - Placeholder text replaced
- `OneBox/OneBox/Views/Upgrade/UpgradeFlowView.swift` - Feature comparison table
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Disabled button removed
- `OneBox/OneBox/Views/Advanced/ProfessionalSigningView.swift` - Disabled toggle removed
- `OneBox/OneBox/Views/NewHomeView.swift` - Search→Privacy button
- `OneBox/OneBox/Views/IntegrityDashboardView.swift` - 3 fake buttons removed

**Status:** All fixes complete. App is cleaner for launch.

---

## 2025-12-21: Critical Bug Fixes + Empty Button Implementations

**Issues Addressed:**
1. CRITICAL: 3 force unwrap crashes in encryption code (`.combined!`)
2. CRITICAL: Infinite loop hang risk in workflow execution
3. Empty button handlers throughout the app
4. Missing Terms/Privacy policy sheets
5. Missing Privacy Info modal for tools
6. Missing document preview in search

**Fixes Applied:**

**Phase 1: Crash Prevention**
- Fixed `Privacy.swift:371` - `encryptedData.combined!` → `guard let`
- Fixed `MultipeerDocumentService.swift:179` - `sealedBox.combined!` → `guard let`
- Fixed `SecureCollaborationView.swift:768` - `sealedBox.combined!` → `guard let`

**Phase 2: Hang Prevention**
- Added 5-minute timeout to `waitForJobCompletion()` in WorkflowExecutionService
- Added `WorkflowError.timeout` error case

**Phase 3: Terms/Privacy Implementation**
- Created `LegalDocumentView` component with actual policy content
- Added sheets to OnboardingView for Terms/Privacy buttons
- Added sheets to UpgradeFlowView for Terms/Privacy buttons

**Phase 4: Privacy Info Modal**
- Created `ToolPrivacyInfoView` showing privacy details per tool
- Implemented `showPrivacyInfo()` function in NewHomeView

**Phase 5: Document Preview**
- Added QuickLook preview for documents in search results
- Documents now open in native iOS preview

**Phase 6: Help Center**
- Created `ContactSupportView` with support options
- Created `VideoTutorialsView` with coming soon placeholders
- Created `FeatureTourView` with interactive tour
- Created `KeyboardShortcutsView` with iPad shortcuts

**Files Modified:**
- `OneBox/Modules/Privacy/Privacy.swift`
- `OneBox/Modules/Networking/MultipeerDocumentService.swift`
- `OneBox/OneBox/Views/Advanced/SecureCollaborationView.swift`
- `OneBox/OneBox/Services/WorkflowExecutionService.swift`
- `OneBox/OneBox/Views/Onboarding/OnboardingView.swift`
- `OneBox/OneBox/Views/Upgrade/UpgradeFlowView.swift`
- `OneBox/OneBox/Views/NewHomeView.swift`
- `OneBox/OneBox/Views/Help/HelpCenterView.swift`

**Status:** All fixes complete

---

## 2025-12-21: Preview File Issue FINALLY Fixed + Workflow UI Cleanup

**Issues Reported:**
1. "Files removed or deleted" error when previewing files (4th-5th report of this issue)
2. "Create Workflow" option in feature flow was misleading
3. Ads module build error (UIComponents import)

**Root Cause (Preview Issue):**
- SwiftUI state race condition
- Using separate `@State private var showPreview = false` and `@State private var previewURL: URL?`
- When button tapped: `previewURL = url` then `showPreview = true`
- SwiftUI could present `fullScreenCover` before `previewURL` state update propagated
- Result: Cover appeared with nil URL, showing error

**Solution:**
- Created `PreviewItem` struct (Identifiable wrapper for URL)
- Changed `fullScreenCover(isPresented:)` to `fullScreenCover(item:)` binding
- Single `@State private var previewItem: PreviewItem?` bundles URL with presentation
- No more race condition - URL is guaranteed present when cover shows

**Other Fixes:**
- Simplified file persistence in JobEngine.swift (removed overly complex verification)
- Simplified ensureFileAccessible() in JobResultView.swift
- Removed "Create Workflow" button, replaced with informational tip
- Fixed Ads module with local AdColors struct

**Files Modified:**
- `OneBox/OneBox/Views/JobResultView.swift` - PreviewItem pattern for sheet presentation
- `OneBox/Modules/JobEngine/JobEngine.swift` - Simplified file persistence
- `OneBox/OneBox/Views/ToolFlowView.swift` - Workflow tip instead of button
- `OneBox/Modules/Ads/Ads.swift` - Local AdColors struct

**Status:** USER VERIFIED WORKING

---

## 2025-12-20: Black Text on Dark Background Fixes + Split PDF Multi-file Fix

**Issues Reported:**
1. Success page has black fonts on dark background (Split PDF and others)
2. Split PDF preview shows only one file instead of 4
3. Success page clicking files shows "files removed or deleted"
4. Merge PDF black text on dark background still present

**Root Causes:**

**1. Black Text Issues:**
- Multiple views using system colors (.secondary, .primary) instead of OneBoxColors
- System colors appear black on the app's dark graphite background

**2. Split PDF Only Showing 1 File:**
- `saveOutputFilesToDocuments()` in JobEngine.swift created filename from job type + timestamp
- All split files processed in same second got identical filenames
- Each file overwrote the previous one, leaving only the last file

**3. Files Deleted Error:**
- Same root cause as #2 - files were being overwritten, not persisted

**Fixes Applied:**

**JobResultView.swift:**
- Added ZStack with `OneBoxColors.primaryGraphite.ignoresSafeArea()` as background
- Changed all `.foregroundColor(.secondary)` to `OneBoxColors.secondaryText`
- Changed all `.foregroundColor(.primary)` to `OneBoxColors.primaryText`
- Changed `.foregroundColor(.green)` to `OneBoxColors.secureGreen`
- Fixed fallback error view colors

**JobEngine.swift:**
- Modified `saveOutputFilesToDocuments()` to add index suffix for multiple files
- Example: `split_pdf_12-20-2024_1.pdf`, `split_pdf_12-20-2024_2.pdf`, etc.
- Moved timestamp generation outside loop (same timestamp for all files in batch)

**UIComponents.swift:**
- Fixed `InfoRow`: Changed `.foregroundColor(.secondary)` to `OneBoxColors.secondaryText`
- Fixed `ReorderableFilePickerRow`: Changed all system colors to OneBoxColors
- Fixed `ReorderableFileListView`: Changed header and button colors

**Files Modified:**
- `OneBox/OneBox/Views/JobResultView.swift`
- `OneBox/Modules/JobEngine/JobEngine.swift`
- `OneBox/Modules/UIComponents/UIComponents.swift`

**Status:** Needs user testing to verify all four issues are resolved

---

## 2025-12-16: Signature Size Fix (Bounding Box vs Actual Display)

**Issue Reported:**
- Signature size not reflecting correctly - "I sign smaller but it is shown much bigger"

**Root Cause:**
- Signature image is displayed with `.aspectRatio(contentMode: .fit)` inside a bounding box (default 300x120)
- For a square signature image (1:1 aspect ratio) in a 300x120 box:
  - Actual displayed width = 120px (height-limited, fits within 120px height)
  - But code was using box width = 300px for ratio calculation
- This caused signatures to appear ~2.5x larger in final PDF than on screen

**Fix:**
- Modified `processSignatures()` in InteractiveSignPDFView.swift
- Now calculates ACTUAL displayed width based on image aspect ratio vs box aspect ratio
- If image aspect (width/height) < box aspect, height is limiting → actualWidth = boxHeight × imageAspect
- Uses actual displayed width for size ratio calculation

**Files Modified:**
- `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift` - Fixed size calculation

**Status:** Needs user testing to verify signature size now matches screen appearance

---

## 2025-12-15: Complete Signature System Overhaul

**Issues Reported:**
1. Signature appears in wrong position (not where user placed it)
2. Signature size doesn't match what user created
3. Zoom in/out is erratic and annoying - on and off behavior

**Deep Analysis - Root Causes Identified:**

**1. Position Bug - Double Y Inversion**
- Data flow traced: User tap → normalize → store → process → CorePDF
- Found Y coordinate was inverted TWICE:
  - Once in `processSignatures()`: `y: 1.0 - position.y`
  - Again in CorePDF: `bounds.height * (1.0 - clampedY)`
- Result: Position ended up nearly correct but inverted from intended

**2. Size Bug - Hardcoded View Width**
- Size calculation used hardcoded `estimatedViewWidth = 400.0`
- Actual view width varies by device (iPhone SE: ~375, iPad: ~800+)
- A 300px signature on a 500px view = 60%, but calculated as 75% (300/400)

**3. Zoom Bug - simultaneousGesture Conflict**
- Page zoom used `simultaneousGesture(MagnificationGesture())`
- This allowed BOTH page zoom and signature resize to recognize simultaneously
- The `if selectedPlacement == nil` check happened AFTER gesture started
- Result: Unpredictable zoom behavior

**Fixes Applied:**

**Fix 1: Remove Double Y Inversion**
- File: `InteractiveSignPDFView.swift:535-537`
- Removed the Y inversion since CorePDF already handles it
- Before: `y: 1.0 - firstPlacement.position.y`
- After: `y: firstPlacement.position.y`

**Fix 2: Store Actual View Width**
- File: `SignaturePlacement.swift` - Added `viewWidthAtPlacement: CGFloat`
- File: `InteractivePDFPageView.swift` - Pass `geometry.size.width` in callback
- File: `InteractiveSignPDFView.swift` - Use stored width for ratio calculation
- Now calculates: `signatureWidth / actualViewWidth` = accurate ratio

**Fix 3: Conditional Gesture Attachment**
- File: `InteractivePDFPageView.swift`
- Extracted page zoom to `pageZoomGesture` computed property
- Added early `guard selectedPlacement == nil else { return }` in gesture handlers
- Page zoom completely ignores input when signature is selected

**Files Modified:**
- `OneBox/OneBox/Models/SignaturePlacement.swift`
- `OneBox/OneBox/Views/Signing/InteractiveSignPDFView.swift`
- `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`

**Status:** Needs user testing

---

## 2025-12-15: Button Aesthetics Fix

**Issue:** Disabled button opacity (0.4) looked harsh and unprofessional

**Fix:** Enhanced disabled state with elegant visual treatment:
- Muted background (surfaceGraphite at 50% opacity)
- Muted text color (tertiaryText)
- Subtle border for visibility
- Desaturation effect (0.3)
- Smooth animation transition

**Files Modified:**
- `OneBox/Modules/UIComponents/OneBoxStandard.swift`

---

## 2025-12-15: UX Fixes & State Persistence

**Issues Reported:**
1. "Continue Securely" button selectable when it should be disabled/faded
2. Preview shows black/blank page instead of actual file
3. Sign PDF has stray dots (resize handles) appearing in wrong positions
4. Sign PDF zoom gesture hard to use
5. User loses work when minimizing the app

**Fixes Applied:**

**1. Continue Securely Button Visual State**
- File: `OneBox/Modules/UIComponents/OneBoxStandard.swift`
- Added `.opacity(isDisabled ? 0.4 : 1.0)` to OneBoxButton
- Button now visually fades when disabled

**2. Preview Black Page Fix**
- File: `OneBox/OneBox/Views/JobResultView.swift`
- Fixed `numberOfPreviewItems` to always return 1 (not 0)
- Added fallback logic in `previewItemAt` to always return a valid item
- Improved file accessibility handling with retry logic

**3. Sign PDF Resize Handles (Stray Dots)**
- File: `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`
- Root cause: `.position()` placed handles absolutely in coordinate space
- Fix: Changed to `.offset()` so handles appear relative to signature center
- Increased handle size from 12 to 16 for better touch targets

**4. Sign PDF Zoom Gesture**
- File: `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`
- Changed from `simultaneousGesture` to regular `gesture` for priority
- Added haptic feedback during resize for better user feedback
- Reduced min/max size range for more reasonable zoom limits

**5. State Persistence on App Minimize**
- Created: `OneBox/OneBox/Services/WorkflowStateManager.swift`
- File: `OneBox/OneBox/Views/ToolFlowView.swift`
- Saves workflow state when app goes to background
- Offers to restore when user returns to the same tool
- State expires after 1 hour
- Only restores if selected files still exist

**Files Modified:**
- `OneBox/Modules/UIComponents/OneBoxStandard.swift`
- `OneBox/OneBox/Views/JobResultView.swift`
- `OneBox/OneBox/Views/Signing/InteractivePDFPageView.swift`
- `OneBox/OneBox/Views/ToolFlowView.swift`

**Files Created:**
- `OneBox/OneBox/Services/WorkflowStateManager.swift`

**Status:** Needs user testing

---

## 2025-12-08: Page Organizer & Redaction Fixes

**Features Added:**
- **Swipe-to-select in Page Organizer** (iOS Photos-style)
  - Drag finger across pages to select/deselect multiple at once
  - First cell touched determines mode (selecting vs deselecting)
  - Haptic feedback for each cell touched
  - Uses PreferenceKey system to track cell frames

**Bugs Fixed:**
1. **RedactionView not loading PDF in workflow**
   - Root cause: Security-scoped resource access released too early
   - Fix: Keep access open if temp copy fails, release only at workflow end
   - Added retry logic (3 attempts with 0.5s delay)

2. **Redaction analysis not running**
   - Root cause: `onChange(of: pdfDocument)` never fired because PDFDocument doesn't conform to Equatable
   - Fix: Call `performSensitiveDataAnalysis()` directly when PDF loads in `loadPDFDocument()`

**Files Modified:**
- `OneBox/OneBox/Views/PageOrganizerView.swift` - Swipe-to-select
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - Security-scoped resource fix
- `OneBox/OneBox/Views/RedactionView.swift` - PDF loading retry + analysis trigger fix

**Status:** Needs user testing

---

## 2025-12-07: Workflow Feature - Complete Fixes

**Problems Reported:**
1. "Create Custom Workflow" - Add Step button doesn't work
2. "Quick Share" template - runs briefly then returns with no feedback
3. Custom workflow doesn't show after save (only after app restart)
4. Workflow error: "Invalid input files"
5. Workflow execution is too slow

**Root Causes & Fixes:**

**Issue 1 - Add Step button:**
- `showingStepPicker` state variable was never used
- Fix: Always show available steps grid with helper text

**Issue 2 - No success feedback:**
- No message shown after workflow completes
- Fix: Added success alert with "Share Result" button

**Issue 3 - Workflow not showing after save:**
- Parent view only loaded workflows on `onAppear`
- Fix: Added `onChange(of: isCreatingWorkflow)` to reload on sheet dismiss

**Issue 4 - Invalid input files:**
- Security-scoped URLs from file picker not accessible across actor boundaries
- Fix: Copy security-scoped files to temp directory before processing, validate files exist

**Issue 5 - Slowness:**
- Fix: Reduced polling from 500ms→100ms (job), 200ms→50ms (UI)

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift`
- `OneBox/OneBox/Services/WorkflowExecutionService.swift`

**Status:** Needs user testing

---

## 2025-12-06: Workflow Feature - Complete Rebuild

**Problem:**
User reported workflow feature wasn't working properly and wasn't offering tailored workflows for specific use cases (legal, finance, HR, medical).

**Issues Found:**
1. `.organize` step was wrongly mapped to `.pdfMerge` (didn't actually organize)
2. `.sign` step used placeholder "Digitally Processed" text
3. Missing critical workflow steps: redact, page numbers, date stamp, flatten
4. Preset workflows were too generic and didn't match real professional needs
5. No step configuration capability

**Fix:**
1. **Added new workflow steps:**
   - `.redact` - Remove sensitive information with preset patterns
   - `.addPageNumbers` - Add page numbers or Bates numbering (for legal)
   - `.addDateStamp` - Add processing date to documents
   - `.flatten` - Flatten form fields and annotations

2. **Fixed step mappings in WorkflowExecutionService:**
   - `.organize` now maps to `.pdfOrganize` (not `.pdfMerge`)
   - `.sign` uses date-based signature text
   - `.redact` uses automatic redaction with legal/finance/HR/medical presets

3. **Added professional industry presets:**
   - **Legal Discovery** - redact PII, Bates numbers, date stamp, flatten, compress
   - **Contract Execution** - merge, flatten, sign, watermark EXECUTED, compress
   - **Financial Report** - redact account numbers, CONFIDENTIAL watermark, date stamp
   - **HR Documents** - redact SSN/personal data, INTERNAL watermark, page numbers
   - **Medical Records** - HIPAA-compliant PHI redaction, date stamp, watermark
   - **Merge & Archive** - combine documents, page numbers, date stamp, compress

4. **Added step configuration:**
   - `StepConfiguration` struct for customizing each step
   - Watermark text, opacity, position configurable
   - Redaction presets (legal, finance, HR, medical, custom)
   - Bates numbering prefix and start number

5. **Updated JobSettings:**
   - Added `WorkflowRedactionPreset` enum
   - Added `isPageNumbering`, `batesPrefix`, `batesStartNumber`
   - Added `isDateStamp`
   - Added `flattenFormFields`, `flattenAnnotations`

**Files Modified:**
- `OneBox/OneBox/Views/WorkflowConciergeView.swift` - New steps, professional templates
- `OneBox/OneBox/Services/WorkflowExecutionService.swift` - Fixed mappings, step configuration
- `OneBox/Modules/JobEngine/JobEngine.swift` - New JobSettings properties

**Status:** Needs user testing

---

## 2025-12-06: Redact PDF - Coordinate Transformation Fix

**Problem:**
User showed screenshots where black redaction boxes appeared in WRONG positions - random places on the document instead of over the actual sensitive data (passport numbers, phone numbers, emails were still visible).

**Root Cause:**
Coordinate system mismatch between Vision and UIKit:
- **Vision framework**: Bottom-left origin, Y increases upward (normalized 0-1)
- **UIKit PDF context**: Top-left origin, Y increases downward

The previous code incorrectly assumed same coordinate systems:
```swift
let y = box.origin.y * pageBounds.height  // WRONG
```

**Fix:**
Proper coordinate transformation:
```swift
// Vision's box.origin.y is BOTTOM of box (from bottom of page)
// Vision's top = origin.y + height
// UIKit's origin.y should be TOP of box (from top of page)
let y = pageBounds.height * (1.0 - box.origin.y - box.height)
```

**Additional Fixes:**
1. **Fallback mechanism**: If `VNRecognizedText.boundingBox(for:)` fails, estimate position using character ratios within the block
2. **Thread safety**: Capture `ocrResults` from main thread before processing to avoid race conditions
3. **Better logging**: Added detailed logs for debugging

**Files Modified:**
- `OneBox/OneBox/Views/RedactionView.swift` - Coordinate fix, fallback, thread safety

**Status:** Needs user testing to confirm redaction boxes now appear in correct positions

---

## 2025-12-06: Redact PDF - Character-Level Bounding Boxes (Previous Attempt)

---

## 2025-12-06: Redact PDF - Complete Rebuild

**What Was Done:**
- Completely rebuilt Redact PDF feature with 4 major fixes

**Bug 1: PDF Context Timing**
  - Root cause: `defer { UIGraphicsEndPDFContext() }` was closing PDF context AFTER the return statement
  - Fix: Removed defer, call UIGraphicsEndPDFContext() explicitly before file verification
  - Applied same fix to watermarkPDF, fillFormFields, compressPDFWithQuality

**Bug 2: ShareSheet Deleting Files**
  - Root cause: ShareSheet was deleting destination file before copying when source = destination
  - Fix: Check if file is already in Documents directory - use directly without copying

**Bug 3: Redaction Not Actually Applying to Scanned PDFs**
  - Root cause: CorePDF.redactPDF was using `page.string` which returns nil for scanned PDFs
  - OCR found the text but didn't capture bounding boxes (positions)
  - CorePDF couldn't find text to redact on image-based pages
  - Fix: Store OCR bounding boxes during text detection, then render pages as images and draw black boxes over detected text positions

**Bug 4: Overcomplicated UI**
  - Had 3 modes: Automatic/Manual/Combined - confusing and unnecessary
  - Fix: Removed mode picker, single unified flow where app detects, user reviews, then applies

**Implementation Details:**
- Added `OCRTextBlock` struct to store text with bounding boxes
- Modified OCR to capture VNRecognizedTextObservation.boundingBox for each text block
- New `createRedactedPDF()` function renders pages as images and draws black boxes over matching text blocks
- Properly converts Vision's normalized coordinates (bottom-left origin) to image coordinates (top-left origin)

**Files Modified:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Fixed PDF context timing in 4 functions
- `OneBox/OneBox/Views/JobResultView.swift` - Fixed ShareSheet file deletion bug
- `OneBox/OneBox/Views/RedactionView.swift` - Complete rebuild with OCR bounding boxes and proper redaction

**Status:** Needs user testing to confirm redactions actually appear on the saved PDF

---

## 2025-12-05: Redact PDF - OCR for Scanned Documents

**What Was Done:**
- Fixed Redact PDF black screen issue
  - Root cause: fullScreenCover had no fallback when URL was nil
  - Fix: Added Group wrapper with fallback error view
- Added passport number detection (various international formats)
  - US: 9 digits
  - UK/EU: 1-2 letters + 6-9 digits
  - Detection after "passport" keyword
- Added international phone number patterns (not just US format)
- Added OCR for scanned/image-based PDFs using Vision framework
  - 100% on-device using VNRecognizeTextRequest
  - Renders PDF pages as images, then performs text recognition
- Optimized OCR to prevent crashes on large documents (22 pages was crashing)
  - Reduced image scale from 2x to 1.5x
  - Added max dimension limit (2000px) to cap memory usage
  - Added autoreleasepool for memory cleanup between pages
  - Changed from .accurate to .fast recognition level
  - Disabled language correction for speed
  - Added 5-second timeout per page
  - Added 10ms delay between pages for UI updates

**Root Cause:**
PDF was image-based (scanned documents) so `page.string` returned nil for all 22 pages. PDFKit cannot extract text from images - needs OCR.

**Files Modified:**
- `OneBox/OneBox/Views/RedactionView.swift` - OCR, passport detection, memory optimization
- `OneBox/OneBox/Views/ToolFlowView.swift` - Debug logging, fallback error view

**Status:** OCR implemented and optimized, needs testing on device with scanned documents

---

## 2025-12-05: Organize PDF Fixes

**What Was Done:**
- Fixed scrolling not working in Organize PDF
  - Root cause: Standalone `DragGesture()` was consuming all drag events before ScrollView
  - Fix: Removed the conflicting gesture; `.onDrag` modifier handles drag-and-drop already
- Fixed selection cleared after rotation
  - Root cause: `selectedPages.removeAll()` was called at end of rotate functions
  - Fix: Removed the line so users can rotate multiple times without reselecting
- Disabled anomaly detection (false positives)
  - User feedback: "28 issues detected" but all pages marked as duplicates (incorrect)
  - Fix: Disabled `detectAnomalies()` call; feature needs proper algorithms and one-click solutions
- Fixed file persistence for PageOrganizerView
  - Root cause: View creates jobs with status: .success, bypassing JobEngine's processJob()
  - Fix: Added local `saveOutputToDocuments()` function
- Fixed multi-page rotation bug
  - Root cause: All rotations applied to same PDF object without saving intermediate results
  - Fix: Reload PDF from outputURL after each rotation to preserve previous changes

**Root Cause Summary:**
PageOrganizerView had a standalone DragGesture that was only used for visual feedback (opacity, scale) but it consumed scroll gestures. The `.onDrag` modifier already handles the actual drag-and-drop functionality.

**Files Modified:**
- `OneBox/OneBox/Views/PageOrganizerView.swift` - All fixes applied

**Status:** Fixes applied, needs user testing

---

## 2025-12-05: Watermark Fixes + File Persistence

**What Was Done:**
- Fixed processed files not saving to Files app
  - Root cause: Output saved to temp directory which iOS cleans up automatically
  - Fix: Added `saveOutputFilesToDocuments()` to copy files to Documents/Exports after processing
- Fixed text watermark SIZE completely ignored (parameter wasn't being passed to draw function)
- Improved image watermark size formula: now 5%-50% of page width (10x range)
- Improved text watermark size formula: now 2%-15% of page height (7.5x range)
- Improved image density formula: spacing 0.6x-5x watermark size (8x range)
- Improved text density formula: spacing 0.8x-6x text size (7.5x range)

**Root Cause:**
- Files were saved to temp directory which gets cleaned up by iOS
- Text watermarks had `drawTextWatermark(text, in: bounds, position: position, tileDensity: tileDensity)` - the `size` parameter was never passed
- Size and density formulas used narrow ranges that didn't produce visually obvious differences

**Files Modified:**
- `OneBox/OneBox/Views/ToolFlowView.swift` - Added auto-save to Documents/Exports
- `OneBox/Modules/CorePDF/CorePDF.swift` - Updated `drawTextWatermark` and `drawImageWatermark` functions

**Status:** Fixes applied, needs user testing

---

## 2025-12-04: Watermark PDF Fix - Large File Handling

**What Was Done:**
- Diagnosed root cause of watermark 27% hang: excessive tiling (50x50 = 2500 draw operations per page)
- Fixed `drawImageWatermark`: reduced limit from 50 to 15 (225 max operations)
- Fixed `drawTextWatermark`: reduced limit from 20 to 15 for consistency
- Added `autoreleasepool` inside tiling loops for memory management
- Added 100% offline principle to all documentation

**Root Cause:**
For a 10-page PDF with tiled image watermark, the app was doing 25,000 image draw operations with no memory release or UI updates between them.

**Files Modified:**
- `OneBox/Modules/CorePDF/CorePDF.swift` - Watermark tiling limits and memory
- `CLAUDE.md`, `PROJECT.md`, `docs/ARCHITECTURE.md` - Added offline principle

**Status:** Fix applied, needs user testing

---

## 2025-12-04: Documentation Restructure

**What Was Done:**
- Restructured documentation system to solve "model memory" problem
- Created new files: CLAUDE.md, PROJECT.md, docs/INDEX.md, docs/HEALTH_CHECK.md, docs/ARCHITECTURE.md, docs/SESSION_LOG.md, docs/DECISIONS.md
- Moved from single 950-line CLAUDE.md to modular ~300-line mandatory reading
- Old comprehensive CLAUDE.md preserved in OneBox/CLAUDE.md

**Files Created:**
- `/CLAUDE.md` (new, ~60 lines)
- `/PROJECT.md` (new, ~120 lines)
- `/docs/INDEX.md`
- `/docs/HEALTH_CHECK.md`
- `/docs/ARCHITECTURE.md`
- `/docs/SESSION_LOG.md`
- `/docs/DECISIONS.md`

**What's Next:**
- Fix Watermark PDF 27% hang issue

---

## 2025-12-04: Watermark PDF Button and Progress Fixes

**What Was Done:**
- Fixed "Begin Secure Processing" button not responding (HapticManager import issue)
- Fixed watermark infinite loading at 100% (added progress completion detection)
- Added debugging logs to watermark processing
- Improved memory management in watermark function

**Files Modified:**
- `OneBox/Views/ToolFlowView.swift`
- `Modules/CorePDF/CorePDF.swift`

**What's Unfinished:**
- Watermark PDF hangs at 27% (new issue after previous fixes)

---

## 2025-01-15: Resize Image Feature Audit

**What Was Done:**
- Comprehensive audit of Resize Image feature
- Fixed 8 critical issues (selection limits, validation, memory management)
- Fixed save to gallery functionality

**Files Modified:**
- `Modules/CoreImageKit/CoreImageKit.swift`
- `Modules/JobEngine/JobEngine.swift`
- `OneBox/Views/ToolFlowView.swift`
- `OneBox/Views/JobResultView.swift`
- `OneBox/Views/ExportPreviewView.swift`

**Status:** Resize Image fully functional

---

## 2025-01-15: Sign PDF Storage Fix

**What Was Done:**
- Fixed persistent "Unable to save the signed PDF" error
- Improved disk space checking logic
- Fixed clear button functionality
- Removed undo button as requested

**Files Modified:**
- `Modules/CorePDF/CorePDF.swift`
- `OneBox/Views/Signing/EnhancedSignatureCanvasView.swift`

**Status:** Sign PDF fully functional

---

## 2025-01-15: Sign PDF Complete Redesign

**What Was Done:**
- Complete redesign of Sign PDF feature
- Created interactive signing system with touch-to-place
- Implemented custom drawing canvas for real devices
- Fixed workflow progression issues

**Files Created:**
- `OneBox/Views/Signing/InteractiveSignPDFView.swift`
- `OneBox/Views/Signing/EnhancedSignatureCanvasView.swift`
- `OneBox/Views/Signing/InteractivePDFPageView.swift`
- `OneBox/Views/Signing/CustomDrawingCanvasView.swift`
- `OneBox/Services/SignatureFieldDetectionService.swift`
- `OneBox/Models/SignaturePlacement.swift`

**Status:** Sign PDF fully functional

---

## 2025-01-15: Major Implementation Cycle

**What Was Done:**
- Removed all ZIP/unzip features
- Implemented 8 major features (Global Search, Pre-flight Insights, Workflow Hooks, etc.)
- Fixed 31+ build errors and 15+ warnings
- Ensured iOS 16 compatibility

**Files Modified:** 51+ files

**Status:** All critical features implemented

---

*Add new entries at the top of this file.*
