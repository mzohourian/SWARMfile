# OneBox User Flow Diagrams

## 🔄 Complete User Journey Maps

---

## 1. First-Time User Experience

### Flow Overview
New user downloads app → Onboarding → First conversion → Becomes regular user

### Detailed Flow
```
┌──────────────────┐
│  App Store       │
│  Download        │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Launch App      │
│  First Time      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Onboarding      │
│  Slide 1:        │
│  Welcome         │
└────────┬─────────┘
         │ Tap Next
         ▼
┌──────────────────┐
│  Onboarding      │
│  Slide 2:        │
│  On-Device       │
└────────┬─────────┘
         │ Tap Next
         ▼
┌──────────────────┐
│  Onboarding      │
│  Slide 3:        │
│  Privacy         │
└────────┬─────────┘
         │ Tap Next
         ▼
┌──────────────────┐
│  Onboarding      │
│  Slide 4:        │
│  Features        │
└────────┬─────────┘
         │ Start Using
         ▼
┌──────────────────┐
│  Home Screen     │
│  (Toolbox)       │
│  3/3 Free        │
└────────┬─────────┘
         │ Browse Tools
         ├────────────────┐
         │                │
         ▼                ▼
   Select Tool      Use Search
```

**Decision Points:**
- Skip onboarding? → Home (with tooltip)
- Complete onboarding? → Home (full experience)

**Success Metrics:**
- % users who complete onboarding
- Time to first conversion
- Onboarding completion rate

---

## 2. Images → PDF Conversion (Happy Path)

### Flow Overview
Most popular feature - user converts photos to PDF document

### Detailed Flow
```
┌──────────────────┐
│  Home Screen     │
└────────┬─────────┘
         │ Tap "Images → PDF"
         ▼
┌──────────────────┐
│  Input Selection │
│  (Empty State)   │
│  📄              │
│  "Select Images" │
└────────┬─────────┘
         │ Tap "Select Files"
         ▼
┌──────────────────┐
│  iOS Photo       │
│  Picker          │
│  (System)        │
└────────┬─────────┘
         │ Select 3 images
         │ Tap "Add"
         ▼
┌──────────────────┐
│  Input Selection │
│  (With Files)    │
│  📷 IMG_1.jpg    │
│  📷 IMG_2.heic   │
│  📷 IMG_3.png    │
└────────┬─────────┘
         │ Tap "Continue"
         ▼
┌──────────────────┐
│  Configuration   │
│  Page Size: A4   │
│  Orientation: ▶  │
│  Margins: 20pt   │
└────────┬─────────┘
         │ (Optional: Adjust)
         │ Tap "Process Files"
         ▼
┌──────────────────┐
│  Check Free Tier │
│  Exports Today   │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
Has exports?  No exports left
    │         │
    ▼         ▼
┌─────────┐ ┌──────────────┐
│ Process │ │ Show Paywall │
└────┬────┘ └──────┬───────┘
     │             │
     │        ┌────┴────┐
     │        │         │
     │    Purchase?   Dismiss
     │        │         │
     │        ▼         ▼
     │    ┌────────┐ ┌──────┐
     │    │Pro User│ │ Home │
     │    └───┬────┘ └──────┘
     │        │
     └────────┴────────┐
                       ▼
              ┌──────────────────┐
              │  Processing      │
              │  ⏳              │
              │  Progress: 45%   │
              └────────┬─────────┘
                       │ Complete
                       ▼
              ┌──────────────────┐
              │  Result          │
              │  ✅ Success!     │
              │  output.pdf      │
              │  5.2 MB          │
              └────────┬─────────┘
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
       ┌──────────┐      ┌──────────┐
       │  Save    │      │  Share   │
       │  to      │      │  via     │
       │  Files   │      │  Sheet   │
       └────┬─────┘      └────┬─────┘
            │                 │
            └────────┬────────┘
                     ▼
            ┌──────────────────┐
            │  Success Banner  │
            │  "File saved!"   │
            └────────┬─────────┘
                     │ Auto-dismiss
                     ▼
            ┌──────────────────┐
            │  Home Screen     │
            │  2/3 Free left   │
            └──────────────────┘
```

**User Actions:**
1. Tap tool card
2. Select files
3. (Optional) Configure settings
4. Process
5. Save/Share result

**Time Estimate:** 30-60 seconds

---

## 3. Free User Reaches Limit

### Flow Overview
Free user has used 3 exports → Sees paywall → Decision point

### Detailed Flow
```
┌──────────────────┐
│  Home Screen     │
│  0/3 Free left   │
└────────┬─────────┘
         │ Tap any tool
         ▼
┌──────────────────┐
│  Free Tier Check │
└────────┬─────────┘
         │ Limit reached
         ▼
┌──────────────────┐
│  Paywall Screen  │
│  👑              │
│  Unlock All      │
│  Features        │
│                  │
│  [Monthly]  $5   │
│  [Yearly]   $30  │ ← Selected
│  [Lifetime] $50  │
└────────┬─────────┘
         │
    ┌────┴────────────┐
    │                 │
    ▼                 ▼
Purchase           Dismiss
    │                 │
    ▼                 ▼
┌─────────────┐  ┌─────────┐
│ StoreKit    │  │  Home   │
│ Purchase    │  │ Screen  │
│ Dialog      │  └─────────┘
└──────┬──────┘
       │
  ┌────┴─────┐
  │          │
Success   Cancel/Fail
  │          │
  ▼          ▼
┌──────┐  ┌───────────┐
│ Pro  │  │ Error     │
│Active│  │ Message   │
└──┬───┘  └─────┬─────┘
   │            │
   │            ▼
   │      ┌───────────┐
   │      │  Paywall  │
   │      │  (Retry)  │
   │      └─────┬─────┘
   │            │
   └────────────┴────┐
                     ▼
            ┌──────────────────┐
            │  Home Screen     │
            │  Pro Active ✓    │
            │  Unlimited       │
            └────────┬─────────┘
                     │ Continue using
                     ▼
            ┌──────────────────┐
            │  Any Tool Flow   │
            │  (No limits)     │
            └──────────────────┘
```

**Conversion Goals:**
- Show value proposition
- Emphasize unlimited exports
- Highlight privacy benefits
- Make purchasing friction-free

**Success Metrics:**
- Paywall → Purchase rate
- Time spent on paywall
- Which plan converts best

---

## 4. PDF Compression with Target Size

### Flow Overview
Advanced use case - user wants PDF compressed to specific size

### Detailed Flow
```
┌──────────────────┐
│  Home Screen     │
└────────┬─────────┘
         │ Tap "Compress PDF"
         ▼
┌──────────────────┐
│  File Picker     │
│  (iOS System)    │
└────────┬─────────┘
         │ Select large-report.pdf (15 MB)
         ▼
┌──────────────────┐
│  Configuration   │
│  Quality: Medium │
│  ◉ Target Size   │
│  ──●────────     │ ← Slider
│  5 MB            │
└────────┬─────────┘
         │ Tap "Process"
         ▼
┌──────────────────┐
│  Processing      │
│  Special: Target │
│  Size Mode       │
│  (May take      │
│   longer)        │
└────────┬─────────┘
         │ Binary search compression
         │ Multiple passes
         ▼
┌──────────────────┐
│  Result          │
│  ✅ Success!     │
│  output.pdf      │
│  4.9 MB          │ ← Within target
│  ⬇️ 67% smaller  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Share/Save      │
└──────────────────┘
```

**Special Behaviors:**
- May take 2-3x longer than standard compress
- Shows "optimizing..." message
- Result guaranteed ≤ target size
- If impossible, shows clear error

---

## 5. Batch Image Processing

### Flow Overview
User needs to resize 200 vacation photos

### Detailed Flow
```
┌──────────────────┐
│  Home Screen     │
└────────┬─────────┘
         │ Tap "Resize Images"
         ▼
┌──────────────────┐
│  Photo Picker    │
│  Multi-Select    │
└────────┬─────────┘
         │ Select 200 photos
         │ (Shows: "200 selected")
         ▼
┌──────────────────┐
│  Input Selection │
│  200 photos      │
│  Total: 1.2 GB   │
└────────┬─────────┘
         │ Tap "Continue"
         ▼
┌──────────────────┐
│  Configuration   │
│  Format: JPEG    │
│  Quality: 70%    │
│  Max Size:       │
│  2048px          │
│  Strip EXIF: ✓   │
└────────┬─────────┘
         │ Tap "Process"
         ▼
┌──────────────────┐
│  Processing      │
│  Batch Mode      │
│  47/200 (24%)    │
│  ────●──────     │
│  ~5 min left     │
│                  │
│  [Cancel]        │
└────────┬─────────┘
         │ User can background
         │ App continues in BG
         ▼
┌──────────────────┐
│  Background      │
│  Processing      │
│  (BGTask)        │
└────────┬─────────┘
         │ Complete
         │ Send notification
         ▼
┌──────────────────┐
│  Notification    │
│  "200 images     │
│   processed!"    │
└────────┬─────────┘
         │ Tap notification
         ▼
┌──────────────────┐
│  Result          │
│  ✅ Success!     │
│  200 files       │
│  Total: 420 MB   │
│  ⬇️ 65% smaller  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Save All        │
│  to Photos       │
└──────────────────┘
```

**Key Features:**
- Batch progress indicator
- Background processing
- Push notification on completion
- Can cancel mid-process

---

## 6. Share Extension Flow

### Flow Overview
User shares photos from Photos app directly to OneBox

### Detailed Flow
```
┌──────────────────┐
│  Photos App      │
│  Select 5 photos │
└────────┬─────────┘
         │ Tap Share button
         ▼
┌──────────────────┐
│  iOS Share Sheet │
│  [Copy]          │
│  [AirDrop]       │
│  [OneBox] ← New! │
└────────┬─────────┘
         │ Tap "OneBox"
         ▼
┌──────────────────┐
│  Share Extension │
│  What to do?     │
│  • Convert to    │
│    PDF           │ ← Tap
│  • Resize        │
│  • Compress      │
└────────┬─────────┘
         │ Select "Convert to PDF"
         ▼
┌──────────────────┐
│  Quick Config    │
│  Page Size: A4   │
│  [Process Now]   │
└────────┬─────────┘
         │ Tap "Process Now"
         ▼
┌──────────────────┐
│  Processing      │
│  in Extension    │
└────────┬─────────┘
         │ Complete
         ▼
┌──────────────────┐
│  Success!        │
│  [Open in        │
│   OneBox]        │
│  [Done]          │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
Open App    Done
    │         │
    ▼         ▼
┌─────────┐ ┌───────────┐
│OneBox   │ │Photos App │
│Result   │ │(Return)   │
│Screen   │ └───────────┘
└─────────┘
```

**Benefits:**
- Quick access from any app
- No need to switch to OneBox first
- Prefilled with selected files
- Fast processing

---

## 7. Shortcuts Automation

### Flow Overview
Power user sets up automation for daily PDFs

### Detailed Flow
```
┌──────────────────┐
│  Shortcuts App   │
│  Create New      │
└────────┬─────────┘
         │ Add Action
         ▼
┌──────────────────┐
│  Search Actions  │
│  "OneBox"        │
└────────┬─────────┘
         │ Find "Convert Images to PDF"
         ▼
┌──────────────────┐
│  Action Config   │
│  Input: [Images] │
│  Page Size: A4   │
│  Output: [PDF]   │
└────────┬─────────┘
         │ Add to automation
         ▼
┌──────────────────┐
│  Automation      │
│  Trigger:        │
│  Every day 9 AM  │
│  Get receipts    │
│  from folder     │
│  → OneBox        │
│  → Save to       │
│     Files        │
└────────┬─────────┘
         │ Save automation
         ▼
┌──────────────────┐
│  Next Day 9 AM   │
│  Auto-runs       │
└────────┬─────────┘
         │ Silent processing
         ▼
┌──────────────────┐
│  Notification    │
│  "Daily receipts │
│   PDF created"   │
└────────┬─────────┘
         │ (Optional) Tap to view
         ▼
┌──────────────────┐
│  Files App       │
│  receipts.pdf    │
└──────────────────┘
```

**Power User Features:**
- No UI when running in background
- Parameterized settings
- Chainable with other actions
- Reliable automation

---

## 8. Error Recovery Flow

### Flow Overview
Something goes wrong → Clear error → Easy recovery

### Detailed Flow
```
┌──────────────────┐
│  Processing      │
│  Video...        │
└────────┬─────────┘
         │ Error occurs
         ▼
┌──────────────────┐
│  Error Detected  │
│  Type:           │
│  Corrupt file    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Error Banner    │
│  ⚠️              │
│  "Processing     │
│   failed: Video  │
│   file corrupt"  │
│                  │
│  [Try Another]   │
│  [Get Help]      │
└────────┬─────────┘
         │
    ┌────┴────────┐
    │             │
Try Another    Get Help
    │             │
    ▼             ▼
┌─────────┐  ┌──────────────┐
│Return to│  │ Support View │
│Input    │  │ FAQ:         │
│Select   │  │ "Supported   │
└─────────┘  │  Formats"    │
             └──────────────┘
```

**Error Types Covered:**
- Corrupt files → Clear message + format guide
- Out of space → Free space tip
- Invalid format → Supported formats list
- Network error (IAP) → Retry button
- Target size impossible → Adjust suggestion

**Recovery Options:**
- Try with different file
- Adjust settings
- Read help article
- Contact support

---

## 9. Settings & Preferences

### Flow Overview
User customizes app behavior

### Detailed Flow
```
┌──────────────────┐
│  Home Screen     │
└────────┬─────────┘
         │ Tap Settings tab
         ▼
┌──────────────────┐
│  Settings        │
│  • Processing    │
│  • Appearance    │
│  • Privacy       │
└────────┬─────────┘
         │ Tap "Appearance"
         ▼
┌──────────────────┐
│  Theme Picker    │
│  ○ System        │
│  ○ Light         │
│  ● Dark ← Select │
└────────┬─────────┘
         │ Selection
         ▼
┌──────────────────┐
│  App switches to │
│  Dark Mode       │
│  Immediately     │
└────────┬─────────┘
         │ Back
         ▼
┌──────────────────┐
│  Settings        │
│  (Dark Mode)     │
└────────┬─────────┘
         │ Tap "Privacy Policy"
         ▼
┌──────────────────┐
│  Privacy Policy  │
│  (Full text)     │
│  [Done]          │
└────────┬─────────┘
         │ Done
         ▼
┌──────────────────┐
│  Settings        │
└──────────────────┘
```

**Customizable Settings:**
- Strip Metadata: On/Off
- Keep Originals: On/Off
- Theme: System/Light/Dark
- Diagnostics: On/Off

---

## 10. User Lifecycle Journey

### Complete User Journey Over Time

```
Day 1: Discovery & First Use
├─ Download from App Store
├─ Complete onboarding
├─ First conversion (Images → PDF)
├─ Save file successfully
└─ Positive impression ✓

Day 2-7: Regular Use
├─ Open app 3-5 times
├─ Try different tools
├─ Use 3 free exports
└─ See paywall

Week 2: Decision Point
├─ Consider upgrade
├─ Evaluate value
├─ Maybe purchase Pro?
│  ├─ Yes → Pro user path
│  └─ No → Continue free

Pro User Path:
├─ Purchase subscription
├─ Unlock all features
├─ Use multiple times/day
├─ Set up Shortcuts
├─ Become power user
└─ Recommend to others

Free User Path:
├─ Use 3 exports/day
├─ See ads
├─ May upgrade later
└─ Return when needed

Month 1: Retention
├─ Pro: High engagement
│  └─ 80% retention
└─ Free: Moderate use
   └─ 40% retention

Month 3: Loyalty
├─ Pro: Core user base
│  ├─ Daily use
│  └─ Leave reviews
└─ Free: Occasional use
   └─ 20% convert to Pro
```

---

## 📊 Flow Metrics to Track

### Key Performance Indicators (KPIs)

**Acquisition:**
- App Store page views
- Download rate
- First open rate

**Activation:**
- Onboarding completion rate
- Time to first conversion
- First-day retention

**Engagement:**
- Daily Active Users (DAU)
- Weekly Active Users (WAU)
- Average sessions per user
- Tools most used

**Monetization:**
- Free → Pro conversion rate
- Paywall view → Purchase rate
- Revenue per user
- Subscription retention

**Retention:**
- Day 1, 7, 30 retention
- Churn rate
- Time between sessions

**Referral:**
- Share action usage
- App Store ratings
- Word-of-mouth growth

---

## 🎯 Optimization Opportunities

### Based on User Flows

**Reduce Friction:**
- Fewer taps to process
- Smart defaults
- Remember user preferences
- Bulk operations

**Increase Conversion:**
- Better paywall copy
- Show savings/value
- Social proof
- Limited-time offers

**Improve Retention:**
- Push notifications (optional)
- Widget (iOS 14+)
- Shortcuts suggestions
- Regular updates

**Enhance Experience:**
- Faster processing
- Better error messages
- Contextual help
- Smooth animations

---

This comprehensive user flow documentation provides a complete map of every user journey through the OneBox app!
