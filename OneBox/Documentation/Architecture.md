# OneBox Architecture

## Overview

OneBox follows a **modular, layered architecture** designed for maintainability, testability, and scalability. The app is built using modern Swift patterns including async/await, actors for thread safety, and SwiftUI for declarative UI.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│                  (SwiftUI Views + MVVM)                  │
├─────────────────────────────────────────────────────────┤
│                   Application Layer                      │
│         (Coordinators, Managers, ViewModels)             │
├─────────────────────────────────────────────────────────┤
│                    Business Logic Layer                  │
│         (Job Engine, Processing Engines, IAP)            │
├─────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                    │
│        (File System, Persistence, System APIs)           │
└─────────────────────────────────────────────────────────┘
```

## Module Structure

### Core Processing Modules

#### CorePDF
**Purpose**: PDF manipulation and generation

**Components**:
- `PDFProcessor` (actor): Thread-safe PDF operations
- PDF merge/split algorithms
- Compression with quality control
- Watermarking engine
- Digital signature placement

**Key Design Decisions**:
- Actor isolation for thread safety
- Streaming for large PDFs (memory efficient)
- Binary search for target-size compression
- CGContext-based rendering for watermarks

#### CoreImageKit
**Purpose**: Image processing and format conversion

**Components**:
- `ImageProcessor` (actor): Thread-safe image operations
- Batch processing pipeline
- Format conversion (HEIC/JPEG/PNG)
- EXIF metadata handling

**Key Design Decisions**:
- Core Image for filters
- ImageIO for efficient encoding/decoding
- Streaming for large image sets
- Memory-mapped file I/O for huge files

### Application Modules

#### JobEngine
**Purpose**: Background job queue and processing

**Architecture**:
```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  JobManager  │──────▶│ JobProcessor │──────▶│   Engines    │
│  (Singleton) │       │    (Actor)   │       │ (CorePDF,    │
└──────────────┘       └──────────────┘       │  CoreImage)  │
      │                                        └──────────────┘
      ▼
┌──────────────┐
│ Persistence  │
│   (JSON)     │
└──────────────┘
```

**Key Features**:
- Serial job queue (one at a time)
- Progress tracking (0.0 - 1.0)
- Cancellation support
- Background task support (BGProcessingTask)
- Persistence (survives app restart)
- Temp file lifecycle management

**Key Design Decisions**:
- Single serial queue to avoid resource contention
- Actor-based processor for thread safety
- JSON persistence (simple, debuggable)
- Automatic cleanup on completion/cancellation

#### Payments
**Purpose**: In-app purchases and subscription management

**Architecture**:
```
┌──────────────────┐
│ PaymentsManager  │
│   (Singleton)    │
└────────┬─────────┘
         │
    ┌────┼────┐
    │    │    │
    ▼    ▼    ▼
┌──────┐┌──────┐┌──────┐
│Monthly││Yearly││Life- │
│ Sub  ││ Sub  ││time  │
└──────┘└──────┘└──────┘
```

**Key Features**:
- StoreKit 2 integration
- Transaction verification
- Free tier management (3 exports/day)
- Restore purchases
- Subscription status tracking

**Key Design Decisions**:
- MainActor isolation (UI-driven)
- Transaction.updates listener for real-time sync
- VerificationResult handling for security
- Daily export counter with midnight reset

### UI Layer

#### View Hierarchy
```
OneBoxApp (App)
    │
    ├── ContentView (TabView)
    │       │
    │       ├── HomeView
    │       │     └── ToolCard (Grid)
    │       │           └── ToolFlowView (Sheet)
    │       │                 ├── InputSelectionView
    │       │                 ├── ConfigurationView
    │       │                 ├── ProcessingView
    │       │                 └── JobResultView
    │       │
    │       ├── RecentsView
    │       │     └── JobRow (List)
    │       │           └── JobResultView (Sheet)
    │       │
    │       └── SettingsView
    │             ├── PaywallView (Sheet)
    │             ├── PrivacyPolicyView (Sheet)
    │             └── SupportView (Sheet)
    │
    └── Environment Objects
          ├── AppCoordinator
          ├── JobManager
          ├── PaymentsManager
          └── ThemeManager
```

#### MVVM Pattern
- **Views**: SwiftUI views (declarative UI)
- **ViewModels**: `@ObservableObject` classes (business logic)
- **Models**: Structs (data)

**Example**:
```swift
// Model
struct Job: Identifiable, Codable { ... }

// ViewModel
@MainActor
class JobManager: ObservableObject {
    @Published var jobs: [Job] = []
    func submitJob(_ job: Job) { ... }
}

// View
struct RecentsView: View {
    @EnvironmentObject var jobManager: JobManager
    var body: some View { ... }
}
```

## Data Flow

### 1. User Initiates Job
```
User taps tool
  → ToolFlowView presented
  → User selects input files (PhotosPicker/FilePicker)
  → User configures settings
  → Taps "Process"
```

### 2. Job Submission
```
ToolFlowView
  → Creates Job model
  → Calls jobManager.submitJob(_)
  → JobManager adds to queue
  → JobManager persists to disk
  → JobManager starts processing
```

### 3. Job Processing
```
JobManager
  → Spawns Task
  → Calls JobProcessor.process(job)
  → JobProcessor dispatches to appropriate engine
  → Engine processes with progress callback
  → JobManager updates job.progress
  → SwiftUI updates UI (via @Published)
```

### 4. Job Completion
```
Engine returns output URLs
  → JobProcessor updates job.status = .success
  → JobManager saves to disk
  → ToolFlowView transitions to ResultView
  → User can Save/Share outputs
```

## Concurrency Model

### Actors
Used for thread-safe mutable state:
- `PDFProcessor`
- `ImageProcessor`
- `JobProcessor`

### @MainActor
Used for UI-related classes:
- `JobManager` (updates @Published properties)
- `PaymentsManager` (updates @Published properties)
- All ViewModels

### Tasks
Used for async operations:
- Job processing
- StoreKit transactions
- File I/O (when needed)

## Performance Optimizations

### 1. Streaming
- Large PDFs: Process page-by-page
- Batch images: Process in chunks

### 2. Memory Management
- Use `autoreleasepool` in loops
- Release temp files immediately
- Limit concurrent operations (serial queue)

### 3. Background Processing
- `BGProcessingTask` for long-running jobs
- Task continuation when app enters background
- Cleanup on termination

### 4. Caching
- `NSCache` for thumbnails (roadmap)
- Cached job metadata (in-memory)

## Error Handling

### Typed Errors
Each module defines its own error enum:
```swift
public enum PDFError: LocalizedError {
    case invalidPDF(String)
    case writeFailed
    case targetSizeUnachievable

    var errorDescription: String? { ... }
}
```

### Error Propagation
```
Engine throws error
  → JobProcessor catches
  → Sets job.error
  → JobManager updates UI
  → User sees error banner
```

### Recovery Strategies
- Invalid input → Clear error message + link to supported formats
- Insufficient disk space → Preflight check + cleanup suggestion
- Target size unachievable → Lower target or reduce quality

## Testing Strategy

### Unit Tests (≥70% coverage)
- **What**: Core algorithms, business logic
- **How**: XCTest with actors
- **Mocking**: Protocol-based dependency injection

### UI Tests
- **What**: Critical user flows
- **How**: XCUITest
- **Coverage**: Top 5 flows (Images→PDF, Merge, Split, etc.)

### Performance Tests
- **What**: Processing speed benchmarks
- **How**: XCTest `measure` blocks
- **Targets**: 50 images→PDF <12s

### Snapshot Tests (Optional)
- **What**: UI consistency
- **How**: SwiftSnapshotTesting
- **Coverage**: Key screens (light/dark)

## Security Architecture

### Sandboxing
- Full App Sandbox enforcement
- No network access for core features
- File access via security-scoped URLs

### Input Validation
- File type verification (UTType)
- Size checks before processing
- Bounds checking on all operations

### Temp File Management
```
Job starts
  → Create temp files
Job completes
  → Delete temp files
Job cancelled/failed
  → Delete temp files (cleanup)
```

### Privacy
- No telemetry by default
- Optional diagnostics (user controlled)
- No IDFA usage (no ATT prompt)

## Scalability

### Horizontal Scaling (Feature Addition)
1. Create new module (`CoreOCR`, etc.)
2. Add to `Package.swift`
3. Implement `JobProcessor` case
4. Add UI flow

### Vertical Scaling (Performance)
- Use `ProcessInfo.processorCount` for parallelization
- Implement work-stealing queue (if needed)
- Add more aggressive caching

## Deployment Pipeline

```
Developer
  ↓ git push
GitHub Actions (CI)
  ↓ run tests
  ↓ build
  ↓ (if main branch)
Fastlane
  ↓ beta lane
TestFlight
  ↓ (manual trigger)
Fastlane
  ↓ release lane
App Store Connect
  ↓ (manual submit for review)
App Store
```

## Future Architectural Improvements

### 1. Modularize UI
- Extract `UIComponents` to separate package
- Create reusable design system

### 2. Plugin Architecture
- Allow third-party engines (sandboxed)
- Plugin API with `@_exported import`

### 3. Cloud Sync (Opt-In)
- iCloud Drive for job history
- CloudKit for settings sync

### 4. Advanced Concurrency
- Parallel job processing (configurable)
- Work-stealing queue
- Priority-based scheduling

## Conclusion

OneBox's architecture prioritizes:
1. **Modularity** – Easy to add features
2. **Testability** – Isolated, mockable components
3. **Performance** – Streaming, actors, memory efficiency
4. **Privacy** – On-device, no network, no tracking
5. **Maintainability** – Clear separation of concerns

This architecture supports the app's core mission: providing a fast, private, and reliable file processing tool for iOS users.
