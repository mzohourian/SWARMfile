# Decision Records

*Why we made certain choices. Reference this when questioning past decisions.*

**Last Updated:** 2025-12-04

---

## 2025-12-04: Documentation Restructure

**Decision:** Split monolithic CLAUDE.md into multiple focused files

**Context:** Original CLAUDE.md was ~950 lines. Too long for reliable AI adherence. Important details were being overlooked.

**Options Considered:**
1. Keep single file, make it shorter
2. Split into multiple files with clear purposes
3. Use comments/sections to organize single file

**Why Chosen:** Option 2 - Multiple files allow:
- Mandatory vs reference separation
- Easier updates (only touch relevant file)
- Clear "read order" for session start
- ~300 lines mandatory reading vs ~950

**Impact:** New documentation structure with 7 files serving specific purposes.

---

## 2025-01-15: Removed ZIP/Unzip Features

**Decision:** Completely remove ZIP archive creation and extraction features

**Context:** User explicitly requested removal - features no longer part of the plan.

**Options Considered:**
1. Keep features but disable them
2. Mark as deprecated
3. Remove completely

**Why Chosen:** Option 3 - Clean removal prevents confusion and reduces code complexity.

**Impact:** Removed CoreZip module, cleaned 15+ files.

---

## 2025-01-15: On-Device Search Using Core Spotlight

**Decision:** Use Apple's Core Spotlight framework for search

**Context:** App needed search functionality while maintaining privacy-first approach.

**Options Considered:**
1. Cloud-based search
2. Custom search implementation
3. Core Spotlight (Apple's on-device search)

**Why Chosen:** Option 3 - Maintains privacy, uses native iOS capabilities, zero cloud dependency.

**Impact:** Users can search documents, workflows, and tools locally.

---

## 2025-01-15: iOS 16 as Minimum Version

**Decision:** Ensure all code works on iOS 16, avoid iOS 17+ only syntax

**Context:** Need to decide minimum supported iOS version.

**Options Considered:**
1. iOS 17+ (newer features, smaller audience)
2. iOS 16+ (broader compatibility)
3. iOS 15+ (maximum compatibility, more work)

**Why Chosen:** Option 2 - Good balance of compatibility and modern features.

**Impact:** All Button and Picker initializers use iOS 16 compatible syntax.

---

## 2025-01-15: Real StoreKit Integration

**Decision:** Replace mocked purchase flow with real StoreKit 2

**Context:** App needed production-ready payment system.

**Options Considered:**
1. Keep mocked flow for testing
2. StoreKit 1 (older API)
3. StoreKit 2 (modern async/await API)

**Why Chosen:** Option 3 - Modern API, better code patterns, production-ready.

**Impact:** Upgrade flow connects to real App Store purchases with biometric authentication.

---

## 2025-01-15: Custom Drawing Canvas for Real Devices

**Decision:** Implement Core Graphics-based drawing as fallback for PencilKit

**Context:** PencilKit's handwriting daemon was failing on real iPhone 15 Pro Max (iOS 18.1).

**Options Considered:**
1. Only support PencilKit (broken on some devices)
2. Third-party drawing library
3. Custom Core Graphics implementation

**Why Chosen:** Option 3 - No external dependencies, full control, works reliably.

**Impact:** App uses PencilKit on simulator, custom drawing on real devices.

---

*Add new decisions at the top of this file.*
*Format: Decision, Context, Options Considered, Why Chosen, Impact*
