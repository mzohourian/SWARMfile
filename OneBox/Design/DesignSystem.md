# OneBox Design System

## 🎨 Brand Identity

### Brand Essence
**OneBox** represents simplicity, privacy, and reliability. The design embodies:
- **Clean & Minimal** - Focus on content, not chrome
- **Trustworthy** - Privacy-first messaging throughout
- **Professional** - Tool-like precision, not toy-like
- **Accessible** - Inclusive design for all users

### Brand Colors

#### Primary Palette
```
Brand Blue (Primary)
- Light: #5AC8FA (iOS System Blue Light)
- Dark: #0A84FF (iOS System Blue Dark)
- Usage: Primary actions, links, tool icons

Brand Orange (Accent)
- Light: #FF9500 (iOS System Orange)
- Dark: #FF9F0A
- Usage: Pro features, upgrade prompts, success states

Privacy Green
- Light: #34C759 (iOS System Green)
- Dark: #30D158
- Usage: Success states, security messaging
```

#### Semantic Colors
```
Background Colors
- Primary Background (Light): #FFFFFF
- Primary Background (Dark): #000000
- Secondary Background (Light): #F2F2F7
- Secondary Background (Dark): #1C1C1E
- Tertiary Background (Light): #FFFFFF
- Tertiary Background (Dark): #2C2C2E

Text Colors
- Primary Text (Light): #000000
- Primary Text (Dark): #FFFFFF
- Secondary Text (Light): #3C3C43 (60% opacity)
- Secondary Text (Dark): #EBEBF5 (60% opacity)
- Tertiary Text (Light): #3C3C43 (30% opacity)
- Tertiary Text (Dark): #EBEBF5 (30% opacity)

Status Colors
- Error Red: #FF3B30 (Light) / #FF453A (Dark)
- Warning Yellow: #FFCC00 (Light) / #FFD60A (Dark)
- Info Blue: #5AC8FA (Light) / #64D2FF (Dark)
```

#### Tool-Specific Colors
```
Images → PDF: #007AFF (Blue)
PDF Merge: #AF52DE (Purple)
PDF Split: #FF9500 (Orange)
PDF Compress: #34C759 (Green)
PDF Watermark: #32ADE6 (Cyan)
PDF Sign: #5856D6 (Indigo)
Image Resize: #FF2D55 (Pink)
Video Compress: #FF3B30 (Red)
Create ZIP: #FFCC00 (Yellow)
Extract ZIP: #8E8E93 (Brown/Gray)
```

---

## 📐 Typography

### Font Family
**SF Pro** (iOS System Font) - Automatic with SwiftUI

### Type Scale
```
Display (Large Title)
- Size: 34pt
- Weight: Bold
- Line Height: 41pt
- Usage: Navigation bars (large), onboarding

Title 1
- Size: 28pt
- Weight: Bold
- Line Height: 34pt
- Usage: Screen titles

Title 2
- Size: 22pt
- Weight: Bold
- Line Height: 28pt
- Usage: Section headers, cards

Title 3
- Size: 20pt
- Weight: Semibold
- Line Height: 25pt
- Usage: Card titles, group headers

Headline
- Size: 17pt
- Weight: Semibold
- Line Height: 22pt
- Usage: List items, buttons

Body
- Size: 17pt
- Weight: Regular
- Line Height: 22pt
- Usage: Main content, descriptions

Callout
- Size: 16pt
- Weight: Regular
- Line Height: 21pt
- Usage: Secondary content

Subheadline
- Size: 15pt
- Weight: Regular
- Line Height: 20pt
- Usage: Metadata, subtitles

Footnote
- Size: 13pt
- Weight: Regular
- Line Height: 18pt
- Usage: Captions, fine print

Caption 1
- Size: 12pt
- Weight: Regular
- Line Height: 16pt
- Usage: Small labels

Caption 2
- Size: 11pt
- Weight: Regular
- Line Height: 13pt
- Usage: Timestamps, counts
```

### Dynamic Type Support
All text must support Dynamic Type scaling (from xSmall to AX5)

---

## 📏 Spacing & Layout

### Spacing Scale
```
4pt   - XXS (tight padding, icon spacing)
8pt   - XS (small padding, vertical rhythm)
12pt  - S (compact spacing)
16pt  - M (standard padding) ← Default
20pt  - L (comfortable spacing)
24pt  - XL (section separation)
32pt  - XXL (major sections)
48pt  - XXXL (screen-level spacing)
64pt  - XXXXL (hero sections)
```

### Grid System
```
iPhone Grid
- Columns: 6
- Gutter: 16pt
- Margin: 16pt (standard), 20pt (comfortable)

iPad Grid
- Columns: 12
- Gutter: 20pt
- Margin: 24pt (portrait), 32pt (landscape)
```

### Layout Containers
```
Card Container
- Padding: 16pt
- Corner Radius: 12pt
- Shadow: 0 2 8 rgba(0,0,0,0.04)

Section Container
- Padding: 16pt horizontal, 20pt vertical
- Background: Secondary background

Full-Bleed Container
- Edge-to-edge content
- Padding: 0
```

---

## 🎯 Component Library

### 1. Buttons

#### Primary Button
```
Appearance:
- Height: 50pt (44pt minimum touch target + 6pt padding)
- Padding: 16pt horizontal
- Corner Radius: 12pt
- Background: Gradient (Brand Blue → Purple)
- Text: White, 17pt Semibold
- Icon: Optional, 20pt, left-aligned

States:
- Default: Full opacity, gradient background
- Pressed: 80% opacity
- Disabled: 40% opacity, gray background
- Loading: Show spinner, disable interaction

Accessibility:
- Min contrast ratio: 4.5:1
- VoiceOver label: Button text + "button"
```

#### Secondary Button
```
Appearance:
- Height: 50pt
- Padding: 16pt horizontal
- Corner Radius: 12pt
- Background: Secondary background color
- Text: Primary text color, 17pt Medium
- Border: None

States:
- Default: Secondary background
- Pressed: Tertiary background
- Disabled: 40% opacity
```

#### Tertiary Button (Text Button)
```
Appearance:
- Height: Auto (minimum 44pt)
- Padding: 8pt horizontal
- Background: None
- Text: Brand Blue, 17pt Medium

States:
- Default: Brand blue text
- Pressed: 60% opacity
- Disabled: Tertiary text color
```

### 2. Cards

#### Tool Card
```
Appearance:
- Width: (Screen width - 48pt) / 2 (iPhone)
- Height: 140pt
- Padding: 16pt
- Corner Radius: 16pt
- Background: Secondary background
- Shadow: 0 2 8 rgba(0,0,0,0.05)

Content:
- Icon: 40pt SF Symbol, tool color
- Title: 17pt Semibold
- Description: 13pt Regular, secondary text
- Spacing: 12pt between elements

States:
- Default: Shadow visible
- Pressed: Scale 0.95, shadow reduced
- Focus: Blue border (accessibility)
```

#### Job Card (Recents)
```
Appearance:
- Height: 80pt
- Padding: 12pt
- Corner Radius: 12pt
- Background: Secondary background

Content:
- Leading: Status icon (32pt)
- Title: 15pt Semibold
- Subtitle: 13pt Regular, secondary text
- Progress: If running, show progress bar
- Trailing: Chevron (16pt)

States:
- Default: Normal appearance
- Pressed: Tertiary background
- Swipe: Red delete action
```

#### Result Card
```
Appearance:
- Width: Full width - 32pt margin
- Height: Auto
- Padding: 20pt
- Corner Radius: 16pt
- Background: Gradient (subtle)
- Shadow: 0 4 12 rgba(0,0,0,0.08)

Content:
- Success icon: 64pt, green
- Title: 22pt Bold
- Details: Key-value pairs, 15pt
- Actions: Button stack below
```

### 3. Input Fields

#### Text Field
```
Appearance:
- Height: 44pt
- Padding: 12pt horizontal
- Corner Radius: 10pt
- Background: Tertiary background
- Border: 1pt, transparent (default)
- Text: 17pt Regular

States:
- Default: No border
- Focus: Blue border (2pt)
- Error: Red border (2pt)
- Disabled: 50% opacity

Placeholder:
- Color: Tertiary text
- Text: 17pt Regular
```

#### Slider
```
Appearance:
- Height: 44pt (including touch target)
- Track Height: 4pt
- Thumb: 28pt circle
- Active Track: Brand Blue
- Inactive Track: Tertiary background

Labels:
- Min/Max: 13pt Regular, secondary text
- Current Value: 17pt Semibold, above slider
```

#### Picker (Segmented Control)
```
Appearance:
- Height: 32pt
- Corner Radius: 8pt
- Background: Tertiary background
- Selected: Secondary background + shadow

Text:
- Size: 13pt Semibold
- Color: Primary text (selected), secondary (unselected)
```

### 4. Lists

#### Standard List Row
```
Appearance:
- Height: 44pt minimum
- Padding: 16pt horizontal
- Background: Primary background
- Separator: Hairline, secondary color

Content:
- Leading: Optional icon (24pt)
- Title: 17pt Regular
- Trailing: Value or chevron (16pt)

States:
- Default: White background
- Pressed: Secondary background
- Selected: Tertiary background
```

#### Grouped List
```
Appearance:
- Background: Secondary background (screen)
- Section: White cards with rounded corners
- Corner Radius: 10pt
- Padding: 0 (content), 16pt (horizontal margin)

Section Header:
- Text: 13pt Regular, secondary text
- Padding: 16pt bottom, 32pt top (first), 24pt top
```

### 5. Progress Indicators

#### Linear Progress Bar
```
Appearance:
- Height: 4pt
- Corner Radius: 2pt
- Background: Tertiary background
- Fill: Brand Blue

Animation:
- Duration: 0.3s ease-in-out
- Update every 0.1s minimum
```

#### Circular Progress (Activity Indicator)
```
Appearance:
- Size: 20pt (small), 36pt (large)
- Color: Brand Blue or white (on colored background)
- Animation: Continuous rotation
```

#### Progress Card
```
Appearance:
- Full-width card
- Padding: 20pt
- Corner Radius: 16pt
- Background: Secondary background

Content:
- Title: 17pt Semibold
- Progress Bar: Full width
- Percentage: 15pt Regular, right-aligned
- Cancel Button: Tertiary style, right-aligned
```

### 6. Banners & Alerts

#### Success Banner
```
Appearance:
- Height: Auto (minimum 60pt)
- Padding: 16pt
- Corner Radius: 12pt
- Background: Green (10% opacity)
- Border: 1pt solid green (30% opacity)

Content:
- Icon: Checkmark circle, 24pt, green
- Message: 15pt Regular, primary text
- Dismiss: X button, 16pt, top-right

Animation:
- Entry: Slide from top + fade in (0.3s)
- Exit: Slide to top + fade out (0.2s)
- Auto-dismiss: 4 seconds
```

#### Error Banner
```
Appearance:
- Same as Success but red color scheme
- Icon: Exclamation triangle
- No auto-dismiss (requires user action)
```

#### Ad Banner (Free Tier)
```
Appearance:
- Height: 60pt
- Padding: 12pt
- Corner Radius: 12pt
- Background: Secondary background
- Border: 1pt solid orange (20% opacity)

Content:
- Icon: Sparkles, 24pt, orange
- Message: 2 lines, 13pt
- CTA Button: Small, orange, "Upgrade"

Placement:
- Below header in Home
- Above actions in Result
```

### 7. Navigation

#### Tab Bar
```
Appearance:
- Height: 49pt + safe area
- Background: Blur (system material)
- Separator: Hairline at top

Items:
- Icon: 28pt SF Symbol
- Label: 10pt Regular
- Active Color: Brand Blue
- Inactive Color: Secondary text

Badge:
- Size: 18pt circle
- Background: Red
- Text: White, 13pt Bold
```

#### Navigation Bar
```
Standard (Inline Title):
- Height: 44pt + safe area
- Background: Transparent or blur
- Title: 17pt Semibold, centered
- Buttons: 17pt, Brand Blue

Large Title:
- Height: 96pt + safe area
- Title: 34pt Bold, left-aligned
- Scroll: Collapses to standard

Search Bar:
- Height: 36pt
- Corner Radius: 10pt
- Background: Tertiary background
- Icon: 16pt magnifying glass
- Placeholder: "Search tools..."
```

### 8. Modals & Sheets

#### Bottom Sheet
```
Appearance:
- Corner Radius: 16pt (top corners)
- Background: Primary background
- Grabber: 36pt × 5pt, tertiary text color
- Padding: 16pt

Sizes:
- Small: 1/3 screen height
- Medium: 2/3 screen height
- Large: Full screen - 60pt

Dismiss:
- Drag down
- Tap outside (small/medium only)
- Close button (large only)
```

#### Modal Dialog
```
Appearance:
- Width: Screen width - 64pt (iPhone)
- Width: 540pt max (iPad)
- Padding: 24pt
- Corner Radius: 14pt
- Background: Primary background
- Shadow: 0 8 24 rgba(0,0,0,0.2)

Content:
- Icon: 64pt, centered (optional)
- Title: 20pt Bold, centered
- Message: 15pt Regular, centered
- Buttons: Stacked, full-width

Backdrop:
- Color: Black, 40% opacity
- Blur: 10pt
```

---

## 🎭 Iconography

### Icon Style
- **SF Symbols** (iOS system icons)
- **Weight**: Medium (default), Bold (emphasis)
- **Rendering**: Monochrome (default), Hierarchical (status), Multicolor (special)

### Icon Sizes
```
Navigation: 28pt
Tool Cards: 40pt
List Items: 24pt
Buttons: 20pt
Inline: 16pt
```

### Custom Icon Guidelines
If creating custom icons:
- **Stroke Width**: 2pt (consistent)
- **Corner Radius**: 1pt
- **Grid**: 40pt × 40pt (tool icons)
- **Export**: SVG, 1x/2x/3x PNG

---

## 🌈 Gradients

### Primary Gradient (Pro Features)
```
Colors: #FF9500 → #FFCC00 (Orange to Yellow)
Angle: 45°
Usage: Paywall, Pro badges, upgrade CTAs
```

### Accent Gradient (Success States)
```
Colors: #34C759 → #30D158 (Green)
Angle: 135°
Usage: Success banners, completion states
```

### Subtle Background Gradient
```
Colors: #F2F2F7 → #E5E5EA (Very subtle)
Angle: 180° (top to bottom)
Usage: Card backgrounds, section separators
```

---

## ♿ Accessibility

### Color Contrast
- **Normal Text**: Minimum 4.5:1 contrast ratio
- **Large Text** (18pt+): Minimum 3:1 contrast ratio
- **Icons**: Minimum 3:1 against background

### Touch Targets
- **Minimum Size**: 44pt × 44pt
- **Recommended**: 48pt × 48pt
- **Spacing**: 8pt minimum between targets

### VoiceOver
- All interactive elements have labels
- Custom controls have hints
- Images have meaningful descriptions
- Decorative images are hidden

### Dynamic Type
- All text supports scaling
- Layout adapts to larger text
- Minimum line height: 1.2 × font size

### Reduced Motion
- Respect system setting
- Provide non-animated alternatives
- Use crossfade instead of slide

---

## 📱 Screen Specifications

### iPhone Sizes
```
iPhone 15 Pro Max / 14 Plus
- Screen: 430 × 932 pt
- Safe Area Top: 59pt
- Safe Area Bottom: 34pt

iPhone 15 Pro / 14 Pro
- Screen: 393 × 852 pt
- Safe Area Top: 59pt
- Safe Area Bottom: 34pt

iPhone SE (3rd gen)
- Screen: 375 × 667 pt
- Safe Area Top: 20pt
- Safe Area Bottom: 0pt
```

### iPad Sizes
```
iPad Pro 12.9"
- Screen: 1024 × 1366 pt
- Safe Area: 20pt all sides

iPad Air / iPad 10th gen
- Screen: 820 × 1180 pt
- Safe Area: 20pt all sides
```

---

## 🎬 Motion & Animation

### Animation Principles
1. **Purposeful** - Every animation has a reason
2. **Quick** - Don't slow down the user
3. **Smooth** - Use ease curves, not linear
4. **Consistent** - Same duration for similar actions

### Timing
```
Quick Feedback: 0.15s (button press)
Standard: 0.3s (most transitions)
Moderate: 0.4s (sheet presentation)
Slow: 0.6s (page transitions)
```

### Easing Curves
```
Ease In Out: Default for most animations
Ease Out: Element entering screen
Ease In: Element exiting screen
Spring: Interactive elements (cards, buttons)
```

### Common Animations
```
Button Press:
- Scale: 0.95
- Duration: 0.15s
- Timing: Ease In Out

Card Tap:
- Scale: 0.97
- Shadow: Reduce by 50%
- Duration: 0.2s

Sheet Present:
- Slide from bottom + fade in
- Duration: 0.4s
- Timing: Ease Out

Modal Present:
- Fade in backdrop (0.2s)
- Scale + fade content (0.3s, delay 0.1s)

Loading:
- Fade in progress (0.2s)
- Continuous progress animation
- Fade out + scale out (0.3s)
```

---

## 🎯 Usage Guidelines

### Do's
✅ Use system colors and adapt to light/dark mode
✅ Provide sufficient padding and spacing
✅ Use SF Symbols for consistency
✅ Support Dynamic Type
✅ Respect safe areas
✅ Use blur effects for overlays
✅ Provide loading states
✅ Show progress for long operations
✅ Use familiar iOS patterns

### Don'ts
❌ Don't use custom fonts (use SF Pro)
❌ Don't ignore safe areas
❌ Don't use tiny touch targets (<44pt)
❌ Don't disable dark mode
❌ Don't use too many colors
❌ Don't animate excessively
❌ Don't ignore accessibility
❌ Don't use Android patterns

---

## 📦 Design Deliverables

### Figma File Structure
```
📁 OneBox Design System
  ├── 🎨 Foundations
  │   ├── Colors (Light/Dark)
  │   ├── Typography
  │   ├── Spacing
  │   └── Iconography
  │
  ├── 🧩 Components
  │   ├── Buttons
  │   ├── Cards
  │   ├── Input Fields
  │   ├── Lists
  │   ├── Progress
  │   ├── Banners
  │   ├── Navigation
  │   └── Modals
  │
  ├── 📱 Screens - Light Mode
  │   ├── Home
  │   ├── Recents
  │   ├── Settings
  │   ├── Tool Flows (10 tools)
  │   ├── Paywall
  │   └── Onboarding
  │
  ├── 🌙 Screens - Dark Mode
  │   └── (Same as Light Mode)
  │
  ├── 📐 Wireframes
  │   └── All screens (low-fidelity)
  │
  └── 📊 Specs
      ├── Export Settings
      ├── Design Tokens
      └── Developer Handoff
```

### Export Specifications
```
App Icon:
- 1024 × 1024 px (App Store)
- Alpha channel: No
- Color space: sRGB

Screenshots:
- 6.7" (1290 × 2796 px)
- 6.5" (1242 × 2688 px)
- 5.5" (1242 × 2208 px)
- iPad Pro 12.9" (2048 × 2732 px)

Assets:
- @1x, @2x, @3x for images
- PDF for vectors (SF Symbols)
- PNG-24 with transparency
```

---

This design system provides the foundation for creating a flawless UI/UX in Figma. Next, I'll create the detailed screen specifications!
