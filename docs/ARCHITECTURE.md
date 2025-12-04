# Architecture Reference

**Last Updated:** 2025-12-04

*Read this when making structural changes or need to understand how things connect.*

## Project Structure

```
SWARMfile/
├── CLAUDE.md              # AI behavior rules
├── PROJECT.md             # Current state dashboard
├── docs/                  # Documentation
│   ├── INDEX.md
│   ├── HEALTH_CHECK.md
│   ├── ARCHITECTURE.md    # (this file)
│   ├── SESSION_LOG.md
│   └── DECISIONS.md
│
└── OneBox/                # The iOS app
    ├── OneBox/            # Main app target
    │   ├── OneBoxApp.swift        # App entry point
    │   ├── ContentView.swift      # Tab bar (Home, Recents, Settings)
    │   ├── Views/                 # All UI screens
    │   │   ├── NewHomeView.swift  # Main home screen
    │   │   ├── ToolFlowView.swift # Universal tool flow
    │   │   ├── Advanced/          # Advanced tools
    │   │   ├── Signing/           # PDF signing views
    │   │   └── ...
    │   └── Services/              # App services
    │
    └── Modules/           # Core functionality
        ├── CorePDF/       # PDF processing
        ├── CoreImageKit/  # Image processing
        ├── JobEngine/     # Background job queue
        ├── Payments/      # In-app purchases
        ├── Privacy/       # Privacy features
        └── UIComponents/  # Reusable UI components
```

## How the App Works

### User Flow
1. User opens app → sees Home screen with tool grid
2. User taps a tool → ToolFlowView opens
3. User selects files → configures options → taps "Process"
4. JobEngine creates a Job and processes it
5. Appropriate module (CorePDF or CoreImageKit) does the work
6. Results shown → User can save/share

### Key Components

| Component | What It Does | File |
|-----------|--------------|------|
| JobManager | Manages job queue, tracks progress | `Modules/JobEngine/JobEngine.swift` |
| PDFProcessor | All PDF operations | `Modules/CorePDF/CorePDF.swift` |
| ImageProcessor | All image operations | `Modules/CoreImageKit/CoreImageKit.swift` |
| PaymentsManager | Subscriptions, free tier | `Modules/Payments/Payments.swift` |

### Job Types
| Job Type | What It Does |
|----------|--------------|
| `imagesToPDF` | Convert images to PDF |
| `pdfMerge` | Combine multiple PDFs |
| `pdfSplit` | Split PDF into parts |
| `pdfCompress` | Reduce PDF file size |
| `pdfWatermark` | Add watermarks |
| `pdfSign` | Add signatures |
| `imageResize` | Resize/compress images |

## Code Patterns

### Pattern 1: MVVM
- **Views:** SwiftUI views (what users see)
- **ViewModels:** Logic classes with `@Published` properties
- **Models:** Data structures (Job, etc.)

### Pattern 2: Actors for Thread Safety
```swift
actor PDFProcessor {
    func merge(pdfs: [URL]) async throws -> URL
}
```

### Pattern 3: @MainActor for UI
```swift
@MainActor
class JobManager: ObservableObject {
    @Published var jobs: [Job] = []
}
```

## Design System

| Token | Usage |
|-------|-------|
| `OneBoxColors` | App colors |
| `OneBoxSpacing` | Consistent spacing |
| `OneBoxRadius` | Corner radius (.small, .medium, .large) |
| `OneBoxTypography` | Font styles |

**Note:** Use `.small` for radius, not `.tiny` (doesn't exist)

## iOS Compatibility

- **Minimum:** iOS 16.0
- **Button syntax:** Use `Button(action: {}) { Text("") }` not `Button("")`
- **Picker syntax:** Use `Picker(selection:label:)` format

## Core Principle - 100% OFFLINE (NON-NEGOTIABLE)

**This app must work in airplane mode. No exceptions.**

| Rule | Description |
|------|-------------|
| No cloud | Never upload user files anywhere |
| No APIs | Never call external services |
| No internet | Core features need zero connectivity |
| Local only | Use device storage, RAM, CPU only |

### Large File Handling

Files should be processed using streaming/chunking, NOT by loading entirely into memory:

| Bad | Good |
|-----|------|
| Load entire PDF into RAM | Process page-by-page |
| Hold all images at once | Process one, release, next |
| Create full copy in memory | Stream to disk as you go |

This ensures the app can handle large files (100MB+ PDFs, hundreds of images) without freezing or crashing.

### Data Storage
- UserDefaults for settings
- FileManager for documents
- Core Spotlight for on-device search (no cloud index)

---

*For detailed technical architecture, see `OneBox/Documentation/Architecture.md`*
