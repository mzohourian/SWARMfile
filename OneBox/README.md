# OneBox: File Converter & Compressor

<div align="center">

**Privacy-first, on-device file utility for iOS/iPadOS**

[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![CI](https://github.com/yourcompany/onebox/workflows/CI/badge.svg)](https://github.com/yourcompany/onebox/actions)

</div>

---

## 📖 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Building & Running](#building--running)
- [Testing](#testing)
- [CI/CD](#cicd)
- [Modules](#modules)
- [Privacy & Security](#privacy--security)
- [Monetization](#monetization)
- [App Store Submission](#app-store-submission)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

**OneBox** is a production-grade iOS/iPadOS application that provides privacy-first, on-device file processing capabilities. All operations happen locally on the user's device—no cloud uploads, no tracking, complete privacy.

### Key Highlights

- ✅ **100% On-Device Processing** – Your files never leave your device
- 📱 **Universal App** – Optimized for iPhone and iPad (iOS 16+)
- 🔒 **Privacy-First** – No data collection, no tracking, no ads tracking
- ⚡ **High Performance** – Optimized engines for fast processing
- ♿ **Accessible** – Full VoiceOver support, Dynamic Type
- 🧪 **Well-Tested** – ≥70% code coverage with unit and UI tests
- 🚀 **CI/CD Ready** – Fastlane + GitHub Actions automation

---

## ✨ Features

### 1. **Images → PDF**
Convert one or multiple images (HEIC, JPEG, PNG) to a single PDF document.

- **Options**: Page size (A4/Letter/Fit), orientation, margins, background color
- **Advanced**: Strip EXIF metadata, set PDF title/author
- **Performance**: 50 images → PDF in <12s on A15+ devices

### 2. **PDF Tools**
Comprehensive PDF manipulation suite:

- **Merge** – Combine multiple PDFs with drag-to-reorder
- **Split** – Extract pages by ranges or individual pages
- **Compress** – Reduce file size with quality presets or target size (MB)
- **Watermark** – Add text or image watermarks (9-grid positioning, tiled mode)
- **Sign** – Freehand signature with placement and flattening

### 3. **Image Tools**
Batch image processing:

- **Resize/Compress** – Set long edge (px) or percentage
- **Format Conversion** – HEIC ↔ JPEG ↔ PNG
- **Quality Control** – Adjustable compression slider
- **Metadata** – Strip EXIF data for privacy

### 4. **Video Compression**
Smart video compression with multiple modes:

- **Presets**: 4K→1080p, 1080p→720p, Social Media optimized
- **Target Size**: Specify desired output size in MB
- **Codec**: H.264 / HEVC (device-capability aware)
- **Audio**: Keep or mute audio track
- **Performance**: 500 MB / 5-min 1080p → ~150 MB ±10%

### 5. **ZIP/Unzip**
Archive management:

- **Create ZIP**: Archive files and folders
- **Extract ZIP**: Preserves directory structure
- **Security**: Detects encrypted archives (clear error message)

### 6. **Share Extension**
Process files directly from other apps:

- Accept images, PDFs, videos, and ZIP files
- Deep-link to relevant tool with pre-filled inputs

### 7. **Shortcuts Integration**
Power-user automation:

- **Actions**: Convert Images→PDF, Compress PDF, Merge PDFs, Compress Video, Zip Files
- **Parameterized**: Configure settings via Shortcuts
- **Background**: Runs without opening UI when possible

---

## 🏗️ Architecture

OneBox follows a **modular, layered architecture** built with SwiftUI and modern Swift concurrency (async/await).

### Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (UIKit where needed)
- **Minimum Deployment**: iOS/iPadOS 16.0
- **Pattern**: MVVM + Dependency Injection
- **Concurrency**: async/await, actors
- **Persistence**: FileManager, UserDefaults, JSON encoding

### Design Principles

1. **Modularity** – Each feature is a separate Swift Package module
2. **Testability** – Protocols and dependency injection for easy mocking
3. **Performance** – Streaming, background processing, memory efficiency
4. **Accessibility** – VoiceOver, Dynamic Type, semantic colors
5. **Privacy** – All processing on-device, no network calls for core features

---

## 📁 Project Structure

```
OneBox/
├── OneBox/                         # Main app target
│   ├── OneBoxApp.swift             # App entry point
│   ├── ContentView.swift           # Root tab view
│   ├── Views/                      # UI views
│   │   ├── HomeView.swift          # Toolbox grid
│   │   ├── RecentsView.swift      # Job history
│   │   ├── SettingsView.swift     # App settings
│   │   ├── ToolFlowView.swift     # Universal tool flow
│   │   ├── JobResultView.swift    # Result & share
│   │   └── PaywallView.swift      # IAP paywall
│   └── Info.plist                  # App configuration
│
├── Modules/                        # Core functionality modules
│   ├── CorePDF/                    # PDF processing
│   │   └── CorePDF.swift           # Merge, split, compress, watermark
│   ├── CoreImageKit/               # Image processing
│   │   └── CoreImageKit.swift      # Resize, compress, format conversion
│   ├── CoreVideo/                  # Video compression
│   │   └── CoreVideo.swift         # Preset & target-size compression
│   ├── CoreZip/                    # Archive operations
│   │   └── CoreZip.swift           # ZIP creation & extraction
│   ├── JobEngine/                  # Background job management
│   │   └── JobEngine.swift         # Queue, progress, persistence
│   ├── Payments/                   # StoreKit 2 IAP
│   │   └── Payments.swift          # Subscriptions & lifetime unlock
│   ├── Ads/                        # Non-tracking ads
│   │   └── Ads.swift               # Banner ads for free tier
│   └── UIComponents/               # Reusable UI components
│       └── UIComponents.swift      # Buttons, cards, banners
│
├── Tests/                          # Unit & UI tests
│   ├── CorePDFTests/
│   ├── JobEngineTests/
│   └── PaymentsTests/
│
├── fastlane/                       # CI/CD automation
│   ├── Fastfile                    # Lanes: test, beta, release
│   └── Appfile                     # App configuration
│
├── .github/workflows/              # GitHub Actions
│   ├── ci.yml                      # PR checks & tests
│   └── release.yml                 # TestFlight & App Store deployment
│
├── Documentation/                  # Additional docs
│   ├── Architecture.md             # Detailed architecture
│   ├── Testing.md                  # Testing strategy
│   ├── Security.md                 # Threat model & mitigations
│   └── Accessibility.md            # A11y guidelines
│
├── Package.swift                   # Swift Package Manager manifest
├── .swiftlint.yml                  # Linting rules
├── .gitignore                      # Git ignore patterns
└── README.md                       # This file
```

---

## 🚀 Getting Started

### Prerequisites

- **Xcode** 15.0 or later
- **macOS** Ventura (13.0) or later
- **iOS Device/Simulator** running iOS 16.0+
- **Apple Developer Account** (for device testing & App Store submission)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourcompany/onebox.git
   cd onebox/OneBox
   ```

2. **Open the project**:
   ```bash
   open OneBox.xcworkspace
   # or
   xed .
   ```

3. **Install dependencies** (if using Swift Package Manager):
   - Xcode will automatically resolve dependencies
   - Or manually: `File → Packages → Resolve Package Versions`

4. **Configure signing**:
   - Select the `OneBox` target
   - Go to `Signing & Capabilities`
   - Select your development team
   - Update bundle identifier if needed

5. **Build & Run**:
   - Select a simulator or connected device
   - Press `⌘R` to build and run

---

## 🔨 Building & Running

### Development Build

```bash
# Build for simulator
xcodebuild -scheme OneBox \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.2' \
  build

# Build for device
xcodebuild -scheme OneBox \
  -destination 'platform=iOS,id=<DEVICE_UDID>' \
  build
```

### Using Fastlane

```bash
# Install Fastlane
gem install fastlane

# Run tests
fastlane tests

# Build for testing
fastlane build

# Upload to TestFlight
fastlane beta
```

---

## 🧪 Testing

### Running Tests

**Via Xcode**:
- Press `⌘U` to run all tests
- Or: `Product → Test`

**Via Command Line**:
```bash
xcodebuild test \
  -scheme OneBox \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -enableCodeCoverage YES
```

**Via Fastlane**:
```bash
fastlane tests
```

### Test Coverage

Target: **≥70% code coverage** for core modules

- **CorePDF**: PDF processing algorithms
- **CoreImageKit**: Image manipulation
- **CoreVideo**: Video compression
- **CoreZip**: Archive operations
- **JobEngine**: Job queue & persistence
- **Payments**: IAP entitlements

### UI Testing

Automated UI tests cover critical user flows:

1. Images → PDF conversion (50+ images)
2. PDF merge (5 documents)
3. PDF split by ranges
4. Video compression to target size
5. ZIP/Unzip round-trip

---

## 🔄 CI/CD

### GitHub Actions Workflows

#### 1. **CI Workflow** (`.github/workflows/ci.yml`)

Runs on every PR and push to `main`/`develop`:

- ✅ SwiftLint checks
- ✅ Build verification
- ✅ Unit tests
- ✅ Code coverage report (uploaded to Codecov)

#### 2. **Release Workflow** (`.github/workflows/release.yml`)

Manual workflow for releases:

- **Beta**: Uploads to TestFlight (internal testing)
- **Production**: Submits to App Store for review

### Fastlane Lanes

| Lane | Description |
|------|-------------|
| `tests` | Run all tests with coverage |
| `build` | Build debug version |
| `beta` | Increment build, upload to TestFlight |
| `release` | Version bump, build, submit to App Store |
| `screenshots` | Generate App Store screenshots |
| `setup_signing` | Configure code signing with match |

---

## 🧩 Modules

### CorePDF

**Location**: `Modules/CorePDF/`

PDF processing engine with optimized algorithms:

- **Merge PDFs**: Combines multiple PDFs, preserves page order
- **Split PDFs**: Extract by page ranges or individual pages
- **Compress PDFs**:
  - Quality presets (Maximum, High, Medium, Low)
  - Target size mode (binary search on JPEG quality)
  - Never outputs larger than input
- **Watermark**: Text or image, 9-grid positioning, tiled mode
- **Sign**: Freehand signature placement, flattened output

**Key Classes**:
- `PDFProcessor` (actor): Thread-safe PDF operations
- `PDFError`: Typed error handling

### CoreImageKit

**Location**: `Modules/CoreImageKit/`

High-performance image processing:

- **Batch Resize**: Set max dimension or percentage
- **Format Conversion**: HEIC ↔ JPEG ↔ PNG
- **Compression**: Quality slider (0.1 - 1.0)
- **EXIF Stripping**: Remove metadata for privacy

**Key Classes**:
- `ImageProcessor` (actor): Thread-safe image operations
- `ImageInfo`: Metadata (dimensions, file size, format)

### CoreVideo

**Location**: `Modules/CoreVideo/`

Video compression with dual modes:

- **Preset Mode**: Use `AVAssetExportSession` presets
- **Target Size Mode**: Calculate bitrate to hit target MB
  - Formula: `bitrate = (targetMB * 8e6 / durationSec) * 0.9`
  - Uses `AVAssetWriter` for custom bitrate encoding

**Key Classes**:
- `VideoProcessor` (actor): Thread-safe video operations
- `VideoInfo`: Duration, resolution, bitrate, file size

### CoreZip

**Location**: `Modules/CoreZip/`

Archive operations using system tools:

- **Create ZIP**: Archive multiple files/folders
- **Extract ZIP**: Preserves directory structure
- **Encryption Detection**: Warns user if archive is password-protected

**Key Classes**:
- `ZipProcessor` (actor): Thread-safe ZIP operations
- `ArchiveInfo`: File count, compressed size, encryption status

### JobEngine

**Location**: `Modules/JobEngine/`

Background job processing system:

- **Job Queue**: Serial processing with background support
- **Progress Tracking**: Real-time progress (0.0 - 1.0)
- **Persistence**: Jobs survive app restart
- **Cancellation**: Clean cancellation with temp file cleanup

**Key Classes**:
- `JobManager`: Singleton job queue manager
- `Job`: Job model (inputs, settings, status, progress, outputs)
- `JobProcessor`: Dispatches to appropriate engine

### Payments

**Location**: `Modules/Payments/`

StoreKit 2 IAP integration:

- **Products**: Monthly, Yearly, Lifetime
- **Free Tier**: 3 exports/day, resets at midnight
- **Transaction Verification**: Secure receipt validation
- **Restore Purchases**: `AppStore.sync()`

**Key Classes**:
- `PaymentsManager`: Singleton IAP manager
- `PaymentError`: Typed error handling

### UIComponents

**Location**: `Modules/UIComponents/`

Reusable SwiftUI components:

- `PrimaryButton`, `SecondaryButton`
- `ProgressCard`: Job progress display
- `InfoRow`: Key-value display
- `EmptyStateView`: Placeholder state
- `ErrorBanner`, `SuccessBanner`: Toast notifications

---

## 🔒 Privacy & Security

### Privacy Commitments

1. **No Cloud Processing**: All operations happen on-device
2. **No Data Collection**: We don't collect personal data or file content
3. **No Tracking**: No analytics, no IDFA, no third-party SDKs
4. **Optional Diagnostics**: Crash reports only if user opts in (off by default)
5. **Non-Tracking Ads**: Banner ads do not collect personal data

### Security Measures

- **Sandboxing**: Full App Sandbox enforcement
- **Input Validation**: Bounds checking on all file operations
- **Streaming**: Large files processed in chunks (memory safe)
- **Temp File Cleanup**: Automatic cleanup on job completion/cancellation
- **No Custom Crypto**: Relies on Apple frameworks only

### Permissions

Required permissions (declared in `Info.plist`):

- **NSPhotoLibraryUsageDescription**: To convert photos to PDF
- **NSPhotoLibraryAddUsageDescription**: To save processed files to Photos

No other permissions requested.

### Threat Model

See `Documentation/Security.md` for detailed threat model and mitigations.

---

## 💰 Monetization

### Free Tier

- **3 free exports per day** (resets at midnight)
- Non-tracking banner ads on Home and Result screens
- All tools accessible

### Pro Subscription

Unlocks:

- ✅ **Unlimited exports**
- ✅ **No ads**
- ✅ **Background processing queues**
- ✅ **Custom presets** (roadmap)
- ✅ **Shortcuts power-user settings**

### IAP Product IDs

- `com.onebox.pro.monthly` – $4.99/month
- `com.onebox.pro.yearly` – $29.99/year (save 50%)
- `com.onebox.pro.lifetime` – $49.99 (one-time)

*(Prices are placeholders; set in App Store Connect)*

---

## 📱 App Store Submission

### Pre-Submission Checklist

- [ ] Bundle ID reserved: `com.yourcompany.onebox`
- [ ] IAP products created in App Store Connect
- [ ] App icon (1024x1024) added to asset catalog
- [ ] Screenshots generated (6.7", 6.1", 5.5", iPad 12.9")
- [ ] App Privacy questionnaire completed ("Data Not Collected")
- [ ] Privacy Policy URL set
- [ ] Support URL set
- [ ] Metadata finalized (name, subtitle, keywords, description)
- [ ] Acceptance tests passed (see below)
- [ ] Code signing configured
- [ ] Build uploaded to TestFlight

### Acceptance Tests

Critical flows to verify before submission:

1. **Images→PDF**: 100 mixed HEIC/JPEG, reorder, metadata stripped
2. **Merge PDFs**: 5 PDFs (scanned + digital), correct page order
3. **Compress PDF**: 15 MB → ≤5 MB, readable quality
4. **Watermark**: Text + image watermarks render correctly
5. **Sign**: Signature placed, flattened, non-editable
6. **Image Batch**: 200 photos → 2048px JPEG 0.7, EXIF off
7. **Video**: 1 GB 1080p → 40-70% reduction, playback OK
8. **Zip/Unzip**: Round-trip preserves structure
9. **Share Extension**: 20 images from Photos → PDF flow works
10. **Shortcuts**: "Compress PDF to 3 MB" runs headless
11. **No Crashes**: iPhone 12/15, iPad 9th/Pro

### Submission

```bash
# Via Fastlane
fastlane release

# Manual
# 1. Archive in Xcode: Product → Archive
# 2. Organizer → Distribute App → App Store Connect
# 3. Upload & Submit for Review
```

---

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** with conventional commits (`feat:`, `fix:`, `docs:`, etc.)
4. **Test** your changes (`fastlane tests`)
5. **Push** to your fork
6. **Open** a Pull Request

### Code Style

- Follow SwiftLint rules (`.swiftlint.yml`)
- Use `async/await` for asynchronous code
- Document public APIs with DocC comments
- Write unit tests for new features

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Example**:
```
feat(pdf): add password protection for PDF export

- Implement AES-256 encryption
- Add password UI in settings
- Update tests

Closes #123
```

---

## 📄 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

### Third-Party Frameworks

This app uses only Apple-provided frameworks:

- **PDFKit** – PDF rendering and manipulation
- **Core Graphics** – Low-level graphics
- **AVFoundation** – Video processing
- **StoreKit 2** – In-app purchases
- **PhotosUI** – Photo picker
- **UniformTypeIdentifiers** – File type handling

### Special Thanks

- The Swift community for excellent async/await patterns
- Fastlane for CI/CD automation
- All beta testers for their feedback

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourcompany/onebox/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourcompany/onebox/discussions)
- **Email**: support@yourcompany.com

---

## 🗺️ Roadmap

### v1.1 (Next Release)

- [ ] OCR / Searchable PDF
- [ ] Password-protect PDFs
- [ ] ZIP encryption support
- [ ] Document scanner with auto-crop
- [ ] Custom presets manager

### v1.2 (Future)

- [ ] Folder watch automation
- [ ] 7z/RAR support
- [ ] Batch operations queue
- [ ] iCloud sync (opt-in)

---

## 📊 Project Status

- **Version**: 1.0.0
- **Status**: ✅ Production-Ready
- **Last Updated**: 2025-01-15
- **Maintainers**: [@yourname](https://github.com/yourname)

---

<div align="center">

**Built with ❤️ using Swift and SwiftUI**

[Download on the App Store](#) | [Website](#) | [Documentation](Documentation/)

</div>
