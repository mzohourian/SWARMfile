# OneBox Screen Specifications

## 📱 Complete Screen Layouts

---

## 1. Home Screen (Toolbox)

### Layout Structure
```
┌─────────────────────────────────────┐
│  OneBox                      [Pro]  │ ← Navigation Bar (Large Title)
├─────────────────────────────────────┤
│                                     │
│  Privacy-First File Tools           │ ← Subtitle (13pt)
│  ┌─────────────────────────────┐   │
│  │ 🎁 2 free exports today     │   │ ← Free tier indicator
│  └─────────────────────────────┘   │
│                                     │
│  [   Search tools...            ]   │ ← Search bar
│                                     │
│  ┌───────────┬───────────┐         │
│  │     📄    │     📑    │         │
│  │           │           │         │
│  │ Images    │   Merge   │         │ ← Tool Cards (Grid)
│  │ → PDF     │   PDFs    │         │
│  │           │           │         │
│  │ Convert   │ Combine   │         │
│  │ photos    │ multiple  │         │
│  └───────────┴───────────┘         │
│                                     │
│  ┌───────────┬───────────┐         │
│  │     ✂️    │     ⬇️    │         │
│  │           │           │         │
│  │  Split    │ Compress  │         │
│  │   PDF     │   PDF     │         │
│  │           │           │         │
│  │ Extract   │  Reduce   │         │
│  │  pages    │ file size │         │
│  └───────────┴───────────┘         │
│                                     │
│  ┌───────────┬───────────┐         │
│  │     💧    │     ✍️    │         │
│  │           │           │         │
│  │Watermark  │   Sign    │         │
│  │   PDF     │   PDF     │         │
│  │           │           │         │
│  │ Add text  │    Add    │         │
│  │ or image  │ signature │         │
│  └───────────┴───────────┘         │
│                                     │
│  ┌───────────┬───────────┐         │
│  │     🖼️    │     ▶️    │         │
│  │           │           │         │
│  │  Resize   │ Compress  │         │
│  │  Images   │   Video   │         │
│  │           │           │         │
│  │  Batch    │  Reduce   │         │
│  │ resize    │ video size│         │
│  └───────────┴───────────┘         │
│                                     │
│  ┌───────────┬───────────┐         │
│  │     📦    │     📂    │         │
│  │           │           │         │
│  │ Create    │ Extract   │         │
│  │   ZIP     │   ZIP     │         │
│  │           │           │         │
│  │ Archive   │  Extract  │         │
│  │  files    │  archive  │         │
│  └───────────┴───────────┘         │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  👑 Upgrade to Pro          │   │ ← Ad Banner (Free tier)
│  │  Remove ads & unlock        │   │
│  │  unlimited exports          │   │
│  │                  [Upgrade]  │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
│ Toolbox | Recents | Settings      │ ← Tab Bar
└─────────────────────────────────────┘
```

### Specifications

**Navigation Bar**
- Height: 96pt (large title collapsed: 44pt)
- Title: "OneBox", 34pt Bold
- Pro Badge: Orange, 60pt × 24pt, "Pro" 13pt Bold
- Background: Transparent, blurs on scroll

**Free Tier Indicator**
- Width: Full width - 32pt
- Height: 36pt
- Padding: 8pt × 12pt
- Corner Radius: 8pt
- Background: Orange 10% opacity
- Icon: Gift, 16pt, orange
- Text: "X free exports today", 13pt Regular

**Search Bar**
- Height: 36pt
- Padding: 8pt × 12pt
- Corner Radius: 10pt
- Background: Tertiary background
- Icon: Magnifying glass, 16pt, secondary text
- Placeholder: "Search tools...", 17pt Regular

**Tool Cards**
- Size: (Screen width - 48pt) / 2 × 140pt
- Spacing: 16pt between cards
- Padding: 16pt
- Corner Radius: 16pt
- Background: Secondary background
- Shadow: 0 2 8 rgba(0,0,0,0.05)

**Tool Card Content**
- Icon: 40pt SF Symbol, tool-specific color
- Spacing: 12pt
- Title: 17pt Semibold, primary text
- Description: 13pt Regular, secondary text, 2 lines max

**Ad Banner**
- Height: 60pt
- Margin: 16pt horizontal
- Padding: 12pt
- Corner Radius: 12pt
- Background: Secondary background
- Border: 1pt solid orange 20%

**Tab Bar**
- Height: 49pt + safe area
- Items: 3 (Toolbox, Recents, Settings)
- Icon: 28pt
- Label: 10pt Regular
- Active: Brand Blue
- Background: Blur (system material)

---

## 2. Tool Flow - Input Selection

### Layout Structure
```
┌─────────────────────────────────────┐
│ [<] Images → PDF              [×]   │ ← Navigation Bar
├─────────────────────────────────────┤
│                                     │
│          📄                         │
│                                     │ ← Empty State
│     Select Images                   │
│                                     │
│   Choose one or more images         │
│   to convert to PDF                 │
│                                     │
│   ┌───────────────────────────┐    │
│   │    📷 Select Files        │    │ ← Primary Button
│   └───────────────────────────┘    │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘

After Selection:
┌─────────────────────────────────────┐
│ [<] Images → PDF              [×]   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📷 IMG_1234.jpg        [×]  │   │ ← File Row
│  │    2.4 MB                   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📷 IMG_1235.heic       [×]  │   │
│  │    3.1 MB                   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📷 IMG_1236.png        [×]  │   │
│  │    1.8 MB                   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌───────────────────────────┐     │
│  │    ➕ Add More Files      │     │ ← Add More Button
│  └───────────────────────────┘     │
│                                     │
│                                     │
│                                     │
│  ┌───────────────────────────┐     │
│  │  Continue       →         │     │ ← Primary Button
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

### Specifications

**Empty State**
- Icon: Tool icon, 64pt, tool color
- Title: "Select [Type]", 22pt Bold
- Message: 15pt Regular, secondary text, centered
- Max width: 280pt

**File Row**
- Height: 64pt
- Padding: 12pt
- Corner Radius: 12pt
- Background: Secondary background

**File Row Content**
- Icon: 32pt (photo/document/video/archive)
- Filename: 15pt Semibold, 1 line
- File Size: 13pt Regular, secondary text
- Remove Button: 24pt, secondary text, right-aligned

**Add More Button**
- Height: 48pt
- Background: Brand Blue 10%
- Text: Brand Blue, 17pt Medium
- Icon: Plus circle, 20pt

---

## 3. Tool Flow - Configuration

### Layout Structure (Images → PDF)
```
┌─────────────────────────────────────┐
│ [<] Images → PDF                    │
├─────────────────────────────────────┤
│                                     │
│  Page Size                          │
│  ┌──────┬────────┬──────────┐      │
│  │  A4  │ Letter │ Fit Image│      │ ← Segmented Control
│  └──────┴────────┴──────────┘      │
│                                     │
│  Orientation                        │
│  ┌─────────────┬─────────────┐     │
│  │  Portrait   │  Landscape  │     │
│  └─────────────┴─────────────┘     │
│                                     │
│  Margins                            │
│  ──────●───────────────────         │ ← Slider
│  20 pt                              │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  ⚙️ Advanced Settings   ▼   │   │ ← Accordion
│  └─────────────────────────────┘   │
│                                     │
│  [Expanded:]                        │
│  ┌─────────────────────────────┐   │
│  │  ⚙️ Advanced Settings   ▲   │   │
│  │                             │   │
│  │  Strip Metadata         ✓   │   │ ← Toggle
│  │                             │   │
│  │  PDF Title                  │   │
│  │  ┌─────────────────────┐   │   │ ← Text Field
│  │  │ OneBox Document     │   │   │
│  │  └─────────────────────┘   │   │
│  │                             │   │
│  │  PDF Author                 │   │
│  │  ┌─────────────────────┐   │   │
│  │  │ OneBox              │   │   │
│  │  └─────────────────────┘   │   │
│  └─────────────────────────────┘   │
│                                     │
│                                     │
│                                     │
│  ┌───────────────────────────┐     │
│  │  ⚡ Process Files        │     │ ← Primary Button
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

### Configuration Options by Tool

**PDF Compress**
```
Quality Preset
├─ Maximum (30% JPEG)
├─ High (50% JPEG)
├─ Medium (70% JPEG)
└─ Low (85% JPEG)

Target Size (Optional)
└─ Slider: 1 MB - 50 MB

Strip Metadata: Toggle
```

**Image Resize**
```
Format
├─ JPEG
├─ PNG
└─ HEIC

Quality
└─ Slider: 10% - 100%

Max Dimension (Optional)
└─ Slider: 512px - 4096px

Resize Percentage (Alternative)
└─ Slider: 10% - 100%

Strip EXIF: Toggle
```

**Video Compress**
```
Preset
├─ High Quality (1080p)
├─ Medium Quality (720p)
├─ Low Quality (540p)
└─ Social Media (optimized)

Target Size (Optional)
└─ Input: MB

Keep Audio: Toggle
```

---

## 4. Tool Flow - Processing

### Layout Structure
```
┌─────────────────────────────────────┐
│       Images → PDF                  │
├─────────────────────────────────────┤
│                                     │
│                                     │
│                                     │
│                                     │
│          ⏳                         │
│                                     │ ← Animated Processing
│      Processing...                  │
│                                     │
│      72% complete                   │
│                                     │
│  ─────────────────●─────────        │ ← Progress Bar
│                                     │
│                                     │
│           [Cancel]                  │ ← Cancel Button
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### Specifications

**Processing Icon**
- Type: Animated spinner or Lottie animation
- Size: 64pt
- Color: Brand Blue
- Animation: Continuous rotation

**Status Text**
- Title: "Processing...", 22pt Semibold
- Progress: "X% complete", 15pt Regular, secondary text
- Spacing: 8pt between lines

**Progress Bar**
- Width: Screen width - 64pt
- Height: 4pt
- Corner Radius: 2pt
- Background: Tertiary background
- Fill: Brand Blue
- Animation: Smooth (0.3s ease)

**Cancel Button**
- Style: Tertiary (text button)
- Text: "Cancel", 17pt Medium, Red
- Padding: 12pt vertical

---

## 5. Tool Flow - Result

### Layout Structure
```
┌─────────────────────────────────────┐
│       Complete              [Done]  │
├─────────────────────────────────────┤
│                                     │
│          ✅                         │
│                                     │
│        Success!                     │ ← Success Message
│    Your files are ready             │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  👑 Upgrade to Pro          │   │ ← Ad Banner (Free)
│  │  Remove ads & unlimited     │   │
│  │                  [Upgrade]  │   │
│  └─────────────────────────────┘   │
│                                     │
│  Output Files                       │
│  ┌─────────────────────────────┐   │
│  │ 📄 output.pdf          [>]  │   │ ← Output File Row
│  │    5.2 MB                   │   │
│  └─────────────────────────────┘   │
│                                     │
│  Details                            │
│  ┌─────────────────────────────┐   │
│  │ 📄 Files Processed      3   │   │
│  │ ➕ Files Created        1   │   │ ← Stats Rows
│  │ ⏰ Completed      3:24 PM   │   │
│  │ ⬇️ Space Saved       40%   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌───────────────────────────┐     │
│  │  💾 Save to Files        │     │ ← Primary Button
│  └───────────────────────────┘     │
│                                     │
│  ┌───────────────────────────┐     │
│  │  📤 Share                │     │ ← Secondary Button
│  └───────────────────────────┘     │
│                                     │
│       Process Another File          │ ← Text Link
│                                     │
└─────────────────────────────────────┘
```

### Specifications

**Success Icon**
- Icon: Checkmark circle fill, 64pt, green
- Animation: Scale in + fade in (0.4s)

**Success Message**
- Title: "Success!", 22pt Bold
- Subtitle: "Your files are ready", 15pt Regular, secondary

**Output File Row**
- Height: 64pt
- Icon: File type icon, 32pt
- Filename: 15pt Semibold
- File Size: 13pt Regular, secondary
- Chevron: 16pt, right-aligned
- Tap: Opens QuickLook preview

**Stats Card**
- Padding: 16pt
- Corner Radius: 12pt
- Background: Secondary background
- Rows: 44pt height each

**Stats Row**
- Icon: 24pt, secondary
- Label: 15pt Regular, secondary
- Value: 15pt Semibold, right-aligned

---

## 6. Recents Screen

### Layout Structure
```
┌─────────────────────────────────────┐
│  Recents                            │ ← Navigation Bar
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ✅ Images → PDF        [>]  │   │ ← Success Job
│  │    2 minutes ago            │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔄 Compress Video      [>]  │   │ ← Running Job
│  │    Processing...            │   │
│  │    ───────●─────────        │   │ ← Progress Bar
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ✅ Merge PDFs          [>]  │   │
│  │    1 hour ago               │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ❌ Split PDF           [>]  │   │ ← Failed Job
│  │    Failed - 2 hours ago     │   │
│  │    ⚠️ Invalid PDF file      │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ✅ Resize Images       [>]  │   │
│  │    Yesterday                │   │
│  └─────────────────────────────┘   │
│                                     │
│  ... (15 more jobs)                 │
│                                     │
└─────────────────────────────────────┘
│ Toolbox | Recents | Settings       │
└─────────────────────────────────────┘
```

### Empty State
```
┌─────────────────────────────────────┐
│  Recents                            │
├─────────────────────────────────────┤
│                                     │
│                                     │
│          🕐                         │
│                                     │
│     No Recent Jobs                  │
│                                     │
│   Your processed files              │
│   will appear here                  │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### Specifications

**Job Row**
- Height: 80pt (no progress), 96pt (with progress)
- Padding: 12pt
- Corner Radius: 12pt
- Background: Secondary background

**Job Row Content**
- Status Icon: 32pt, left-aligned
  - Success: Green checkmark circle
  - Running: Blue rotating arrows
  - Failed: Red X circle
  - Pending: Gray clock
- Title: 15pt Semibold
- Subtitle: 13pt Regular, secondary
- Progress Bar: Full width - 56pt (if running)
- Chevron: 16pt, right-aligned

**Swipe Actions**
- Delete: Red background, trash icon
- Retry: (failed jobs) Blue background, arrow icon

---

## 7. Settings Screen

### Layout Structure
```
┌─────────────────────────────────────┐
│  Settings                           │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 👑 OneBox Pro           ✓   │   │ ← Pro Status (Active)
│  │ Thank you for your support! │   │
│  └─────────────────────────────┘   │
│                                     │
│  Processing                         │ ← Section Header
│  ┌─────────────────────────────┐   │
│  │ Strip Metadata by Default ✓ │   │ ← Toggle Row
│  │ Keep Original Files         │   │
│  └─────────────────────────────┘   │
│                                     │
│  Appearance                         │
│  ┌─────────────────────────────┐   │
│  │ Theme              System › │   │ ← Disclosure Row
│  └─────────────────────────────┘   │
│                                     │
│  Privacy                            │
│  ┌─────────────────────────────┐   │
│  │ Anonymous Diagnostics       │   │
│  │ Privacy Policy          ›   │   │
│  └─────────────────────────────┘   │
│                                     │
│  Support                            │
│  ┌─────────────────────────────┐   │
│  │ Help & FAQ              ›   │   │
│  │ Report an Issue         ›   │   │
│  └─────────────────────────────┘   │
│                                     │
│  About                              │
│  ┌─────────────────────────────┐   │
│  │ Version               1.0.0 │   │
│  │ Build                    42 │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │    Restore Purchases        │   │ ← Button (if not Pro)
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### Pro Status (Free Tier)
```
│  ┌─────────────────────────────┐   │
│  │ 👑 Upgrade to Pro      [>]  │   │ ← Upgrade Row
│  │ Unlimited exports, no ads,  │   │
│  │ and more                    │   │
│  └─────────────────────────────┘   │
```

### Specifications

**Pro Status Card**
- Height: 72pt
- Padding: 16pt
- Corner Radius: 12pt
- Background: Gradient (orange → yellow) at 10% opacity
- Icon: Crown, 28pt, orange
- Title: 17pt Semibold
- Subtitle: 13pt Regular, secondary

**Section Header**
- Text: 13pt Regular, secondary, uppercase
- Padding: 16pt bottom, 32pt top (first), 24pt top (others)
- Margin: 16pt horizontal

**List Row**
- Height: 44pt minimum
- Padding: 16pt horizontal
- Background: Secondary background (grouped)
- Separator: Hairline, at leading edge + 16pt

**Toggle Row**
- Label: 17pt Regular, left-aligned
- Toggle: Standard iOS toggle, right-aligned

**Disclosure Row**
- Label: 17pt Regular, left-aligned
- Value: 15pt Regular, secondary, right-aligned
- Chevron: 16pt, secondary, right-aligned

---

## 8. Paywall Screen

### Layout Structure
```
┌─────────────────────────────────────┐
│  OneBox Pro              [Close]    │
├─────────────────────────────────────┤
│                                     │
│          👑                         │ ← Crown Icon (Gradient)
│                                     │
│     Unlock All Features             │
│                                     │
│  Get unlimited exports, remove      │
│  ads, and support development       │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ∞  Unlimited Exports        │   │
│  │    Process as many files    │   │
│  │                             │   │
│  │ ⚡ Priority Processing      │   │ ← Features List
│  │    Faster background queue  │   │
│  │                             │   │
│  │ 🎨 Custom Presets           │   │
│  │    Save favorite settings   │   │
│  │                             │   │
│  │ 🔒 Shortcuts Power User     │   │
│  │    Advanced automation      │   │
│  │                             │   │
│  │ 👁️ No Ads                   │   │
│  │    Clean experience         │   │
│  │                             │   │
│  │ ❤️ Support Development      │   │
│  │    Help us build more       │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │         Pro Monthly         │   │ ← Unselected Plan
│  │  All features, billed month │   │
│  │                  $4.99  ○   │   │
│  │                    per month│   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      Pro Yearly  [Save 50%] │   │ ← Selected Plan
│  │  All features, best value   │   │
│  │                 $29.99  ●   │   │
│  │                     per year│   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │     Pro Lifetime [Best]     │   │
│  │  Pay once, own forever      │   │
│  │                 $49.99  ○   │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌───────────────────────────┐     │
│  │  Get Pro for $29.99       │     │ ← Purchase Button
│  └───────────────────────────┘     │
│                                     │
│      Restore Purchases              │ ← Link
│                                     │
│  • Payment charged to Apple ID      │
│  • Auto-renews unless cancelled     │ ← Fine Print
│  • Manage in App Store settings     │
│                                     │
└─────────────────────────────────────┘
```

### Specifications

**Crown Icon**
- Size: 64pt
- Gradient: Orange → Yellow
- Animation: Subtle pulse (0.3s, every 2s)

**Features Card**
- Padding: 20pt
- Corner Radius: 16pt
- Background: Secondary background
- Row Height: 60pt
- Icon: 24pt, left-aligned
- Title: 15pt Semibold
- Description: 13pt Regular, secondary

**Plan Card**
- Height: 88pt
- Padding: 16pt
- Corner Radius: 12pt
- Background: Secondary background
- Border: 2pt solid (selected: Brand Blue, unselected: transparent)

**Selected Plan**
- Background: Brand Blue 5% opacity
- Border: Brand Blue
- Shadow: 0 4 12 rgba(10, 132, 255, 0.2)

**Badge (Save/Best)**
- Height: 20pt
- Padding: 4pt × 8pt
- Corner Radius: 4pt
- Background: Orange (Save) / Green (Best)
- Text: White, 11pt Bold, uppercase

**Plan Content**
- Title: 17pt Bold
- Description: 13pt Regular, secondary
- Price: 24pt Bold, right-aligned
- Period: 13pt Regular, secondary, right-aligned
- Radio: 28pt, right-aligned

**Purchase Button**
- Gradient: Orange → Yellow
- Text: White, 17pt Bold
- Height: 56pt
- Shadow: 0 4 12 rgba(255, 149, 0, 0.3)

---

## 9. Onboarding (First Launch)

### Slide 1 - Welcome
```
┌─────────────────────────────────────┐
│                            [Skip]   │
├─────────────────────────────────────┤
│                                     │
│                                     │
│          📦                         │ ← App Icon
│                                     │
│        Welcome to                   │
│          OneBox                     │
│                                     │
│   Privacy-first file tools          │
│   for your iPhone and iPad          │
│                                     │
│                                     │
│                                     │
│        ● ○ ○ ○                     │ ← Page Indicator
│                                     │
│  ┌───────────────────────────┐     │
│  │  Get Started     →        │     │ ← Next Button
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

### Slide 2 - On-Device Processing
```
│          🔒                         │
│                                     │
│    100% On-Device                   │
│       Processing                    │
│                                     │
│   All file conversions happen       │
│   entirely on your device. Your     │
│   files never leave your iPhone.    │
│                                     │
│        ○ ● ○ ○                     │
```

### Slide 3 - No Data Collection
```
│          👁️                         │
│                                     │
│    Zero Data Collection             │
│                                     │
│   We don't collect, store, or       │
│   transmit any of your files or     │
│   personal data. Complete privacy.  │
│                                     │
│        ○ ○ ● ○                     │
```

### Slide 4 - Powerful Tools
```
│          ⚡                         │
│                                     │
│    10 Powerful Tools                │
│                                     │
│   Convert images to PDF, merge      │
│   documents, compress videos,       │
│   and more. All offline, all free.  │
│                                     │
│        ○ ○ ○ ●                     │
│                                     │
│  ┌───────────────────────────┐     │
│  │  Start Using OneBox       │     │
│  └───────────────────────────┘     │
```

### Specifications

**Onboarding Slide**
- Icon: 120pt, centered
- Title: 28pt Bold, centered
- Description: 17pt Regular, secondary, centered, max 280pt width
- Page Indicator: 8pt dots, 16pt spacing
- Buttons: Primary style, full width - 32pt

---

## 10. Dark Mode Variations

### Key Differences

**Backgrounds**
- Primary: #000000
- Secondary: #1C1C1E
- Tertiary: #2C2C2E
- Elevated: #3A3A3C

**Cards & Surfaces**
- Elevated cards use tertiary background
- Shadows are replaced with subtle borders (white 10% opacity)
- Gradients are slightly desaturated

**Text**
- Primary: #FFFFFF
- Secondary: #EBEBF5 (60% opacity)
- Tertiary: #EBEBF5 (30% opacity)

**Colors**
- Slightly brighter/more vibrant in dark mode
- Brand Blue: #0A84FF (vs #007AFF in light)
- Orange: #FF9F0A (vs #FF9500 in light)

**Blur Effects**
- System materials automatically adapt
- Navigation bars: Ultra Thin Material
- Tab bars: Thin Material

---

## 📐 Responsive Layouts

### iPhone SE (Small Screen)
- Reduce vertical spacing to 12pt
- Tool card size: Slightly smaller to fit 2 columns
- Font sizes: Use Dynamic Type minimum

### iPhone Pro Max (Large Screen)
- Increase spacing to 20pt
- Tool cards: Add more padding
- Consider showing 2 columns for lists

### iPad (Tablet)
- Tool grid: 3-4 columns depending on orientation
- Side-by-side layouts where appropriate
- Larger sheets (540pt max width)
- Navigation: Use sidebar in landscape

---

## 🎬 Interaction States

### Buttons
```
Default → [Press] → Pressed (0.95 scale, 0.15s)
         → [Release] → Default (0.3s spring)
         → [Hold] → Contextual menu (0.5s)
```

### Cards
```
Default → [Tap] → Pressed (scale 0.97)
        → [Release] → Navigate with push
        → [Long Press] → Context menu
```

### Lists
```
Default → [Tap] → Flash background
        → [Swipe Left] → Show actions
        → [Swipe Right] → (none)
```

---

This complete screen specification document provides every detail needed to create pixel-perfect designs in Figma!
