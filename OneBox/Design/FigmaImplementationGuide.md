# OneBox Figma Implementation Guide

## 🎯 Purpose

This guide provides step-by-step instructions for implementing the OneBox design system in Figma, creating a production-ready design file that can be handed off to developers.

---

## 📋 Pre-Implementation Checklist

Before starting, ensure you have:
- [ ] Figma Desktop App or Browser (latest version)
- [ ] SF Pro font family installed (download from Apple)
- [ ] Screen specification requirements reviewed
- [ ] iOS Human Interface Guidelines bookmarked
- [ ] Apple Design Resources downloaded (optional but helpful)

---

## 🏗️ File Setup

### 1. Create New Figma File

```
File → New Design File
Name: "OneBox - File Converter iOS App"
```

### 2. Set Up Pages

Create the following pages in order:

```
1. 📘 Cover & Documentation
2. 🎨 Design System
3. 🧩 Components
4. 📱 Screens - iPhone (Light)
5. 🌙 Screens - iPhone (Dark)
6. 📱 Screens - iPad (Light)
7. 🌙 Screens - iPad (Dark)
8. 📐 Wireframes
9. 🔄 User Flows
10. 📊 Developer Handoff
```

### 3. Set Up Artboards

For each screen page, create artboards:

**iPhone Artboards:**
```
- iPhone 15 Pro Max (430 × 932)
- iPhone 15 Pro (393 × 852)
- iPhone SE (375 × 667)
```

**iPad Artboards:**
```
- iPad Pro 12.9" (1024 × 1366)
- iPad Air (820 × 1180)
```

---

## 🎨 Phase 1: Build Design System

### Step 1: Create Color Styles

Navigate to **Design System** page.

#### 1.1 Light Mode Colors

**Create Text Frame:** "Light Mode Colors"

**Primary Colors:**
```
Create Rectangle → Add as Style → Name

Brand Blue:
- Fill: #007AFF
- Name: "Color/Light/Brand/Blue"

Brand Orange:
- Fill: #FF9500
- Name: "Color/Light/Brand/Orange"

Privacy Green:
- Fill: #34C759
- Name: "Color/Light/Brand/Green"
```

**Background Colors:**
```
Primary Background:
- Fill: #FFFFFF
- Name: "Color/Light/Background/Primary"

Secondary Background:
- Fill: #F2F2F7
- Name: "Color/Light/Background/Secondary"

Tertiary Background:
- Fill: #FFFFFF
- Name: "Color/Light/Background/Tertiary"
```

**Text Colors:**
```
Primary Text:
- Fill: #000000
- Name: "Color/Light/Text/Primary"

Secondary Text:
- Fill: #3C3C43
- Opacity: 60%
- Name: "Color/Light/Text/Secondary"

Tertiary Text:
- Fill: #3C3C43
- Opacity: 30%
- Name: "Color/Light/Text/Tertiary"
```

**Status Colors:**
```
Error Red:
- Fill: #FF3B30
- Name: "Color/Light/Status/Error"

Warning Yellow:
- Fill: #FFCC00
- Name: "Color/Light/Status/Warning"

Info Blue:
- Fill: #5AC8FA
- Name: "Color/Light/Status/Info"

Success Green:
- Fill: #34C759
- Name: "Color/Light/Status/Success"
```

#### 1.2 Dark Mode Colors

Repeat above for dark mode with naming:
```
"Color/Dark/..." instead of "Color/Light/..."
```

Use values from DesignSystem.md.

#### 1.3 Tool Colors

```
Images to PDF: #007AFF → "Color/Tool/ImagesToPDF"
PDF Merge: #AF52DE → "Color/Tool/PDFMerge"
PDF Split: #FF9500 → "Color/Tool/PDFSplit"
... (continue for all 10 tools)
```

### Step 2: Create Text Styles

**Create text samples with proper styles:**

```
Display / Large Title:
- Font: SF Pro Display
- Size: 34pt
- Weight: Bold
- Line Height: 41pt
- Name: "Text/Display/LargeTitle"

Title 1:
- Font: SF Pro Display
- Size: 28pt
- Weight: Bold
- Line Height: 34pt
- Name: "Text/Title/Title1"

... (create all text styles from DesignSystem.md)

Body:
- Font: SF Pro Text
- Size: 17pt
- Weight: Regular
- Line Height: 22pt
- Name: "Text/Body/Body"
```

**Pro Tip:** Use Figma's Text Styles panel (⌘⌥T) to quickly create and organize styles.

### Step 3: Create Effect Styles

**Shadow Styles:**

```
Card Shadow:
- Type: Drop Shadow
- X: 0, Y: 2, Blur: 8, Spread: 0
- Color: #000000, 4% opacity
- Name: "Effect/Shadow/Card"

Elevated Shadow:
- Type: Drop Shadow
- X: 0, Y: 4, Blur: 12, Spread: 0
- Color: #000000, 8% opacity
- Name: "Effect/Shadow/Elevated"

Button Shadow:
- Type: Drop Shadow
- X: 0, Y: 4, Blur: 12, Spread: 0
- Color: #FF9500, 30% opacity
- Name: "Effect/Shadow/Button"
```

**Blur Effects:**

```
Background Blur:
- Type: Layer Blur
- Blur: 40
- Name: "Effect/Blur/Background"
```

### Step 4: Create Grid & Layout Styles

**iPhone Grid:**
```
Layout Grid:
- Type: Columns
- Count: 6
- Margin: 16
- Gutter: 16
- Color: Red 10%
- Name: "Grid/iPhone"
```

**iPad Grid:**
```
Layout Grid:
- Type: Columns
- Count: 12
- Margin: 24
- Gutter: 20
- Color: Red 10%
- Name: "Grid/iPad"
```

---

## 🧩 Phase 2: Build Component Library

Navigate to **Components** page.

### Step 1: Create Button Components

#### Primary Button

1. **Create Base:**
   ```
   - Rectangle: 375 × 50
   - Corner Radius: 12
   - Fill: Gradient (Brand Blue → Purple, 135°)
   ```

2. **Add Content:**
   ```
   - Auto Layout: Horizontal
   - Padding: 16 horizontal, 15 vertical
   - Gap: 8
   - Align: Center
   ```

3. **Add Text:**
   ```
   - Text: "Button Text"
   - Style: Text/Body/Semibold
   - Color: White
   ```

4. **Add Icon (Optional):**
   ```
   - Icon: SF Symbol (use IconFinder plugin)
   - Size: 20 × 20
   - Color: White
   ```

5. **Create Component:**
   ```
   Right-click → Create Component
   Name: "Button/Primary"
   ```

6. **Add Variants:**
   ```
   - State: Default, Pressed, Disabled, Loading
   - Size: Medium, Small
   ```

7. **Configure Pressed State:**
   ```
   - Opacity: 80%
   - Scale: 0.95 (simulate with layout)
   ```

8. **Configure Disabled State:**
   ```
   - Opacity: 40%
   - Fill: Gray (#8E8E93)
   ```

9. **Configure Loading State:**
   ```
   - Add spinner component
   - Hide text slightly
   ```

#### Secondary Button

Repeat above with:
```
- Fill: Color/Light/Background/Secondary
- Text Color: Color/Light/Text/Primary
- No shadow
```

#### Text Button (Tertiary)

```
- No background
- Text Color: Brand Blue
- Padding: 8 horizontal
```

### Step 2: Create Card Components

#### Tool Card

1. **Create Frame:**
   ```
   - Size: 171 × 140 (for 2-column grid with 16pt spacing)
   - Corner Radius: 16
   - Fill: Color/Light/Background/Secondary
   - Effect: Effect/Shadow/Card
   ```

2. **Add Auto Layout:**
   ```
   - Direction: Vertical
   - Padding: 16
   - Gap: 12
   - Align: Top Left
   ```

3. **Add Icon:**
   ```
   - SF Symbol: 40 × 40
   - Color: Tool-specific (use property)
   ```

4. **Add Title:**
   ```
   - Text: "Tool Name"
   - Style: Text/Body/Semibold
   - Auto Width
   ```

5. **Add Description:**
   ```
   - Text: "Description text here"
   - Style: Text/Caption/Regular
   - Color: Color/Light/Text/Secondary
   - Fixed Width: 139
   - Max Lines: 2
   ```

6. **Create Component:**
   ```
   Name: "Card/Tool"
   Properties:
     - Icon (Instance Swap)
     - Icon Color (Color)
     - Title (Text)
     - Description (Text)
   ```

#### Job Card (Recents)

1. **Create Frame:**
   ```
   - Width: Fill Container
   - Height: 80
   - Corner Radius: 12
   - Fill: Secondary Background
   ```

2. **Add Auto Layout:**
   ```
   - Direction: Horizontal
   - Padding: 12
   - Gap: 12
   - Align: Center
   ```

3. **Add Status Icon:**
   ```
   - Size: 32 × 32
   - Color: Status-dependent
   ```

4. **Add Content Stack:**
   ```
   - Auto Layout: Vertical
   - Gap: 4
   - Hug Contents
   ```

5. **Add Title & Subtitle:**
   ```
   - Title: Text/Body/Semibold
   - Subtitle: Text/Caption/Regular, Secondary Color
   ```

6. **Add Progress Bar (Optional):**
   ```
   - Show when status = Running
   - Width: Fill
   - Height: 4
   ```

7. **Add Chevron:**
   ```
   - Icon: chevron.right
   - Size: 16 × 16
   - Color: Secondary Text
   ```

8. **Create Component:**
   ```
   Name: "Card/Job"
   Variants: Success, Running, Failed, Pending
   ```

### Step 3: Create Input Components

#### Text Field

1. **Create Base:**
   ```
   - Width: Fill Container
   - Height: 44
   - Corner Radius: 10
   - Fill: Tertiary Background
   ```

2. **Add Text:**
   ```
   - Padding: 12 horizontal
   - Placeholder: "Placeholder text"
   - Color: Tertiary Text
   ```

3. **Create Component:**
   ```
   Name: "Input/TextField"
   Variants: Default, Focused, Error, Disabled
   ```

4. **Add Focus State:**
   ```
   - Border: 2pt, Brand Blue
   ```

5. **Add Error State:**
   ```
   - Border: 2pt, Error Red
   ```

#### Slider

1. **Create Track:**
   ```
   - Width: Fill Container
   - Height: 4
   - Corner Radius: 2
   - Fill: Tertiary Background
   ```

2. **Create Active Track:**
   ```
   - Same size as track
   - Fill: Brand Blue
   - Mask: From left to progress point
   ```

3. **Create Thumb:**
   ```
   - Circle: 28 × 28
   - Fill: White
   - Border: 0.5pt, #D1D1D6
   - Effect: Shadow (0, 2, 4, rgba(0,0,0,0.1))
   ```

4. **Create Component:**
   ```
   Name: "Input/Slider"
   Properties:
     - Value (0-100)
     - Labels (Boolean)
   ```

### Step 4: Create Navigation Components

#### Tab Bar

1. **Create Frame:**
   ```
   - Width: Device Width
   - Height: 49 + Safe Area
   - Fill: Blur (Background/Thin Material)
   ```

2. **Add Separator:**
   ```
   - Top border: 0.5pt, Secondary Text 30%
   ```

3. **Add Tab Items:**
   ```
   - Auto Layout: Horizontal
   - Distribution: Space Between
   - Padding: 0 horizontal, 8 vertical
   ```

4. **Create Tab Item:**
   ```
   - Auto Layout: Vertical
   - Gap: 2
   - Align: Center
   - Icon: 28 × 28
   - Label: Text/Caption2/Regular
   ```

5. **Create Component:**
   ```
   Name: "Navigation/TabBar"
   Instances:
     - TabBar/Item (with selected variant)
   ```

#### Navigation Bar

1. **Create Frame:**
   ```
   - Width: Device Width
   - Height: 44 + Safe Area (standard)
   - Height: 96 + Safe Area (large title)
   - Fill: Transparent or Blur
   ```

2. **Add Title:**
   ```
   - Large: Text/Display/LargeTitle, left-aligned
   - Standard: Text/Body/Semibold, center-aligned
   ```

3. **Add Buttons:**
   ```
   - Leading: Back button or Close
   - Trailing: Action buttons
   - Style: Text/Body/Regular, Brand Blue
   ```

4. **Create Component:**
   ```
   Name: "Navigation/NavBar"
   Variants: Large, Standard
   ```

---

## 📱 Phase 3: Build Screens

Navigate to **Screens - iPhone (Light)** page.

### General Process for Each Screen

1. **Create Artboard:**
   ```
   Frame → iPhone 15 Pro (393 × 852)
   Add Grid: Grid/iPhone
   ```

2. **Add Safe Area Guides:**
   ```
   Rectangle: 393 × 759
   Position: 59pt from top
   Stroke: Red 50%, 1pt
   Name: "Safe Area"
   Lock layer
   ```

3. **Build Screen Content:**
   - Start with navigation bar
   - Add content sections
   - Add tab bar (if applicable)
   - Use components from library
   - Apply proper spacing (8pt grid)

4. **Add Annotations:**
   ```
   - Spacing annotations
   - Interaction notes
   - Component instances
   ```

### Screen Priority Order

Build screens in this order:

1. **Home Screen**
   - Most complex, sets the tone
   - Tool grid with all 10 tools
   - Free tier indicator
   - Search bar
   - Ad banner

2. **Tool Flow - Input Selection**
   - Empty state
   - File list state
   - Primary button

3. **Tool Flow - Configuration**
   - Form controls
   - Segmented controls
   - Sliders
   - Advanced settings accordion

4. **Tool Flow - Processing**
   - Progress indicator
   - Cancel button

5. **Tool Flow - Result**
   - Success state
   - Output files
   - Stats
   - Action buttons

6. **Recents Screen**
   - Empty state
   - Job list with variants
   - Swipe actions

7. **Settings Screen**
   - Pro status card
   - Grouped lists
   - Toggle rows

8. **Paywall**
   - Feature list
   - Plan cards with variants
   - Purchase button

9. **Onboarding**
   - 4 slides
   - Page indicator
   - Skip/Next buttons

### Pro Tips for Screen Building

**Use Auto Layout Everywhere:**
```
- Frames with Auto Layout adapt automatically
- Easier to maintain and modify
- Better for responsive design
```

**Naming Convention:**
```
Screen/Section/Element
Example: "Home/ToolGrid/Card-ImagesToPDF"
```

**Component Overrides:**
```
- Use component properties
- Override text, colors, icons
- Don't detach unless absolutely necessary
```

**Prototype Links:**
```
- Add interactions between screens
- Use Smart Animate for smooth transitions
- Set proper easing (Ease In Out, 300ms)
```

---

## 🌙 Phase 4: Create Dark Mode Versions

Navigate to **Screens - iPhone (Dark)** page.

### Method 1: Duplicate & Swap (Recommended)

1. **Duplicate Light Mode Screens:**
   ```
   Select all artboards → Cmd+D
   Move to Dark Mode page
   ```

2. **Enable Dark Mode Variables:**
   ```
   Select all
   Right panel → Variables
   Change mode to "Dark"
   ```

3. **Update Manually (if needed):**
   ```
   - Swap color styles
   - Adjust shadows to borders
   - Verify contrast ratios
   ```

### Method 2: Variables (Advanced)

Set up variables for automatic mode switching:

```
1. Create variable collections:
   - "Colors/Light"
   - "Colors/Dark"

2. Bind color styles to variables

3. Switch between modes with one click
```

---

## 📐 Phase 5: Create Wireframes

Navigate to **Wireframes** page.

### Purpose
Low-fidelity wireframes for quick iteration and stakeholder review.

### Style Guide for Wireframes

```
- Use gray boxes (no colors)
- Use system font (no SF Pro)
- Focus on layout and hierarchy
- Add annotations for interactions
- No detailed content
```

### Process

1. **Create simplified versions of each screen**
2. **Use rectangles and simple shapes**
3. **Add text placeholders**
4. **Annotate user interactions**

---

## 🔄 Phase 6: Create User Flows

Navigate to **User Flows** page.

### Key Flows to Document

#### 1. First-Time User Flow
```
Launch → Onboarding (4 slides) → Home → Select Tool
→ Input → Configure → Process → Result → Home
```

#### 2. Images → PDF Flow
```
Home → Tap "Images → PDF" → Select Images (PhotoPicker)
→ Configure (Page Size, Orientation) → Process
→ Result → Save/Share → Home
```

#### 3. Free User Hits Limit Flow
```
Home → Tap Tool → (Check exports) → Show Paywall
→ User Purchases → Unlock Pro → Continue
```

#### 4. PDF Compress with Target Size
```
Home → Tap "Compress PDF" → Select PDF → Configure
→ Set Target Size (5 MB) → Process (may take longer)
→ Result (show savings) → Share
```

### Flow Diagram Format

```
Use FigJam or Figjam-style flowcharts:

┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Screen    │──────▶│   Screen    │──────▶│   Screen    │
│   Name      │ Tap  │   Name      │ Next │   Name      │
└─────────────┘      └─────────────┘      └─────────────┘
```

**Tools:**
- Use Figjam for flowcharts
- Use Autoflow plugin for Figma
- Or manually draw with arrows

---

## 📊 Phase 7: Developer Handoff

Navigate to **Developer Handoff** page.

### Create Specs Sheet

**Include:**

1. **Screen Inventory:**
   ```
   - List of all screens
   - Screen names and purposes
   - Links to screens
   ```

2. **Component Inventory:**
   ```
   - All components with variants
   - Usage guidelines
   - Code mapping (SwiftUI views)
   ```

3. **Color Tokens:**
   ```
   Export as JSON:
   {
     "color": {
       "light": {
         "brand": {
           "blue": "#007AFF"
         }
       }
     }
   }
   ```

4. **Typography Tokens:**
   ```
   {
     "text": {
       "display": {
         "large-title": {
           "size": 34,
           "weight": "bold",
           "lineHeight": 41
         }
       }
     }
   }
   ```

5. **Spacing Tokens:**
   ```
   {
     "spacing": {
       "xs": 8,
       "s": 12,
       "m": 16,
       "l": 20,
       "xl": 24
     }
   }
   ```

### Export Assets

**Icons:**
```
- Export as PDF (vectors)
- Or use SF Symbols (no export needed)
```

**Images:**
```
- Export at @1x, @2x, @3x
- Format: PNG-24 (with transparency)
- Naming: image-name@2x.png
```

**App Icon:**
```
- Size: 1024 × 1024
- Format: PNG-24
- No transparency
- Color Space: sRGB
```

### Handoff Checklist

- [ ] All screens designed for iPhone (light & dark)
- [ ] All screens designed for iPad (light & dark)
- [ ] All components created with variants
- [ ] Colors exported as tokens
- [ ] Typography exported as tokens
- [ ] Spacing documented
- [ ] Annotations added to screens
- [ ] Prototype interactions created
- [ ] Developer notes added
- [ ] Assets exported
- [ ] Figma file shared with developers (view access)

---

## 🔧 Figma Plugins to Use

### Essential Plugins

**1. Iconify (SF Symbols)**
```
Purpose: Insert SF Symbols
Usage: Search for icon → Insert → Customize color/size
```

**2. Content Reel**
```
Purpose: Generate realistic placeholder content
Usage: Select text → Plugins → Content Reel → Choose type
```

**3. Unsplash**
```
Purpose: Add placeholder images
Usage: Select frame → Plugins → Unsplash → Search
```

**4. Stark**
```
Purpose: Check accessibility (contrast, color blindness)
Usage: Plugins → Stark → Check Contrast
```

**5. Design Lint**
```
Purpose: Find design inconsistencies
Usage: Plugins → Design Lint → Run
```

**6. Component Inspector**
```
Purpose: Audit components usage
Usage: Plugins → Component Inspector
```

**7. Autoflow**
```
Purpose: Create flowcharts easily
Usage: Draw flows with automatic arrows
```

---

## 🎯 Quality Checklist

Before calling the design "done":

### Design System
- [ ] All colors defined with light/dark modes
- [ ] All text styles created (12+ styles)
- [ ] Effect styles created (shadows, blurs)
- [ ] Grid systems defined
- [ ] Spacing system documented

### Components
- [ ] All buttons created with variants
- [ ] All cards created with properties
- [ ] All inputs created with states
- [ ] Navigation components created
- [ ] All components properly named

### Screens
- [ ] 20+ screens designed
- [ ] Light mode complete
- [ ] Dark mode complete
- [ ] iPhone sizes covered
- [ ] iPad layouts created
- [ ] Safe areas respected
- [ ] Proper spacing (8pt grid)

### Interactions
- [ ] Prototype flows created
- [ ] Animations defined (timing, easing)
- [ ] Hover states defined
- [ ] Loading states shown
- [ ] Error states shown
- [ ] Empty states designed

### Accessibility
- [ ] Color contrast checked (WCAG AA)
- [ ] Touch targets ≥44pt
- [ ] Text sizes support Dynamic Type
- [ ] Alt text added to images
- [ ] Interaction states visible

### Developer Handoff
- [ ] Design tokens exported
- [ ] Assets exported at proper sizes
- [ ] Annotations added
- [ ] Component documentation written
- [ ] Spacing measurements added
- [ ] Figma file organized
- [ ] File shared with team

---

## 📚 Additional Resources

### Figma Resources
- [Figma Best Practices](https://www.figma.com/best-practices/)
- [Auto Layout Guide](https://help.figma.com/hc/en-us/articles/360040451373)
- [Component Documentation](https://help.figma.com/hc/en-us/articles/360038662654)

### iOS Design Resources
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Apple Design Resources](https://developer.apple.com/design/resources/)
- [SF Symbols App](https://developer.apple.com/sf-symbols/)

### Design Systems
- [iOS Design Kit (Community)](https://www.figma.com/community/file/984106517828483938)
- [Material Design 3 (Reference)](https://m3.material.io/)

---

## 🎊 Conclusion

With this guide, you now have a complete roadmap to create a professional, production-ready Figma design for OneBox. The design system, components, and screens will provide developers with everything they need to implement pixel-perfect iOS interfaces.

**Estimated Time:**
- Design System: 4-6 hours
- Components: 8-12 hours
- Screens (Light): 16-20 hours
- Dark Mode: 4-6 hours
- Wireframes & Flows: 4-6 hours
- Handoff & Polish: 4-6 hours

**Total: 40-56 hours of focused design work**

Remember: Great design is iterative. Start with the basics, get feedback, and refine!
