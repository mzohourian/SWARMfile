# OneBox Quick Start Guide

## 🚀 Get the App Running in 5 Minutes

### Prerequisites

Before you begin, ensure you have:
- **macOS** Ventura (13.0) or later
- **Xcode** 15.0 or later (download from App Store)
- **Command Line Tools** installed

### Step-by-Step Setup

#### Option A: Automatic Setup (Recommended)

Run the automated setup script:

```bash
cd OneBox
./setup-xcode-project.sh
```

This script will:
1. ✅ Check for Homebrew (install if needed)
2. ✅ Install XcodeGen
3. ✅ Create necessary directories
4. ✅ Generate asset catalogs
5. ✅ Generate Xcode project
6. ✅ Open in Xcode

**Time: ~5 minutes**

---

#### Option B: Manual Setup

If you prefer to set up manually:

##### 1. Install XcodeGen

```bash
brew install xcodegen
```

##### 2. Create Required Directories

```bash
mkdir -p OneBox/Assets.xcassets/AppIcon.appiconset
mkdir -p OneBox/Assets.xcassets/AccentColor.colorset
mkdir -p "OneBox/Preview Content"
```

##### 3. Generate Xcode Project

```bash
xcodegen generate
```

##### 4. Open in Xcode

```bash
open OneBox.xcodeproj
```

**Time: ~10 minutes**

---

### First Build & Run

Once Xcode opens:

#### 1. Configure Signing

```
1. Click on "OneBox" in the project navigator (top-left)
2. Select "OneBox" target
3. Go to "Signing & Capabilities" tab
4. Select your Team from the dropdown
5. Xcode will automatically manage signing
```

#### 2. Select Device/Simulator

```
Click the device selector (top-left, next to "OneBox")
Choose: "iPhone 15 Pro" (or any simulator)
```

#### 3. Build & Run

```
Press ⌘R or click the Play button
```

**First build takes 2-3 minutes. Subsequent builds are faster.**

---

### What Happens on First Run

The app will:
1. Show onboarding (4 slides)
2. Load the Home screen with 10 tool cards
3. Allow 3 free exports

**Try it:**
1. Tap "Images → PDF"
2. Select some photos
3. Configure settings
4. Tap "Process Files"
5. See the result!

---

## 🔧 Troubleshooting

### "No such module 'JobEngine'"

**Cause:** Xcode hasn't built the frameworks yet.

**Fix:**
```
Product → Build (⌘B)
Wait for build to complete
Product → Clean Build Folder (⌘⇧K)
Product → Build (⌘B) again
```

### "Signing certificate not found"

**Cause:** No Apple Developer account configured.

**Fix:**
```
Xcode → Settings → Accounts → + Add Apple ID
Select your account in Signing & Capabilities
```

### "Command not found: xcodegen"

**Cause:** XcodeGen not installed.

**Fix:**
```bash
brew install xcodegen
```

### "Homebrew not found"

**Cause:** Homebrew not installed.

**Fix:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## 📱 Testing on Device

### Prerequisites
- iPhone or iPad with iOS 16.0+
- Lightning/USB-C cable
- Apple Developer account (free account works)

### Steps

1. **Connect your device**
2. **Trust computer on device** (popup will appear)
3. **Select your device** in Xcode's device selector
4. **Build & Run** (⌘R)
5. **Trust developer on device:**
   ```
   Settings → General → VPN & Device Management
   → Developer App → Trust
   ```

---

## 🧪 Running Tests

```bash
# Run all tests
⌘U in Xcode

# Or via command line
xcodebuild test \
  -scheme OneBox \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## 📦 Building for App Store

### 1. Update Version

Edit `project.yml`:
```yaml
settings:
  MARKETING_VERSION: "1.0.0"  # Change this
  CURRENT_PROJECT_VERSION: "1"  # And this
```

Regenerate project:
```bash
xcodegen generate
```

### 2. Add App Icon

1. Create 1024×1024 PNG icon (no transparency)
2. Drag to `OneBox/Assets.xcassets/AppIcon.appiconset`

### 3. Configure Code Signing

```
1. Update DEVELOPMENT_TEAM in project.yml
2. Regenerate project
3. Or set in Xcode Signing & Capabilities
```

### 4. Archive

```
Product → Archive
Wait for completion (~5 mins)
Organizer opens automatically
```

### 5. Distribute

```
Click "Distribute App"
Choose "App Store Connect"
Follow prompts
```

---

## ⚡ Quick Commands

```bash
# Regenerate Xcode project (after changing project.yml)
xcodegen generate

# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/OneBox-*

# Run tests
xcodebuild test -scheme OneBox

# Build release
xcodebuild -scheme OneBox -configuration Release

# Open in Xcode
open OneBox.xcodeproj
```

---

## 📂 Project Structure

```
OneBox/
├── OneBox/                  # Main app
│   ├── OneBoxApp.swift      # App entry point
│   ├── ContentView.swift    # Root view
│   ├── Views/               # All UI screens
│   ├── Assets.xcassets/     # Images, colors
│   └── Info.plist           # App configuration
│
├── Modules/                 # Core engines
│   ├── CorePDF/
│   ├── CoreImageKit/
│   ├── CoreVideo/
│   ├── CoreZip/
│   ├── JobEngine/
│   ├── Payments/
│   ├── Ads/
│   └── UIComponents/
│
├── Tests/                   # Unit tests
│
├── project.yml              # XcodeGen config
├── Package.swift            # SPM manifest
└── setup-xcode-project.sh   # Setup script
```

---

## 🎯 Next Steps

### After First Successful Build:

1. **Add Real App Icon**
   - Design 1024×1024 icon
   - Add to Assets.xcassets

2. **Test All Features**
   - Try each of the 10 tools
   - Test with real files
   - Verify IAP (requires App Store Connect setup)

3. **Customize Branding**
   - Update bundle ID in project.yml
   - Change colors in code if desired
   - Update app name

4. **Set Up App Store Connect**
   - Create app record
   - Configure IAP products
   - Add metadata

5. **TestFlight Beta**
   - Archive and upload
   - Invite testers
   - Gather feedback

6. **App Store Submission**
   - Generate screenshots
   - Write description
   - Submit for review

---

## 💡 Pro Tips

### Speed Up Builds

```bash
# Enable parallel builds
Xcode → Settings → Build System → New Build System
```

### Better Debugging

```bash
# Enable better error messages
Product → Scheme → Edit Scheme → Run
Environment Variables:
  OS_ACTIVITY_MODE = disable
```

### Preview SwiftUI Views

```swift
// Add to any View file
#Preview {
    HomeView()
        .environmentObject(JobManager.shared)
}
```

Then click "Resume" in the preview canvas.

---

## 🆘 Getting Help

### Resources

- **README.md** - Full documentation
- **Architecture.md** - Technical details
- **DesignSystem.md** - UI/UX specifications
- **CONTRIBUTING.md** - Development guidelines

### Common Issues

1. **Build fails:** Clean build folder (⌘⇧K)
2. **Simulator slow:** Use iPhone SE (smaller)
3. **Memory issues:** Restart Xcode
4. **Can't find module:** Build all targets (⌘B)

### Support

- GitHub Issues: [Report a bug]
- Discussions: [Ask a question]
- Email: support@yourcompany.com

---

## ✅ Success Checklist

After setup, you should be able to:

- [ ] Open OneBox.xcodeproj in Xcode
- [ ] Build successfully (⌘B)
- [ ] Run in simulator (⌘R)
- [ ] See the Home screen with 10 tools
- [ ] Complete onboarding
- [ ] Process a file (Images → PDF)
- [ ] See result screen
- [ ] Run tests (⌘U)
- [ ] No crashes

**If all checked: You're ready to develop! 🎉**

---

## ⏱️ Time Estimates

| Task | Time |
|------|------|
| Setup (automatic) | 5 mins |
| First build | 2-3 mins |
| Testing features | 15 mins |
| Total to running app | **~20 mins** |

---

**Ready to build? Run `./setup-xcode-project.sh` and let's go! 🚀**
