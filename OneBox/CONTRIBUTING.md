# Contributing to OneBox

Thank you for your interest in contributing to OneBox! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)

## Code of Conduct

By participating in this project, you agree to:

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/onebox.git
   cd onebox/OneBox
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/yourcompany/onebox.git
   ```
4. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- Xcode 15.0+
- macOS Ventura (13.0)+
- Swift 5.9+
- Fastlane (optional, for CI/CD)

### Install Dependencies

```bash
# Install SwiftLint
brew install swiftlint

# Install Fastlane (optional)
gem install fastlane
```

### Build the Project

```bash
# Open in Xcode
xed .

# Or build from command line
xcodebuild -scheme OneBox \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

## How to Contribute

### Types of Contributions

- **Bug Fixes**: Fix existing issues
- **Features**: Add new functionality
- **Documentation**: Improve or add documentation
- **Tests**: Add or improve test coverage
- **Performance**: Optimize existing code
- **Refactoring**: Improve code structure

### Finding Issues to Work On

- Check the [Issues](https://github.com/yourcompany/onebox/issues) page
- Look for issues labeled `good first issue` or `help wanted`
- Ask in the issue comments if you want to work on something

## Coding Standards

### Swift Style Guide

Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and our SwiftLint configuration.

### Key Rules

1. **Naming**:
   - Use clear, descriptive names
   - Types: `PascalCase` (e.g., `PDFProcessor`)
   - Variables/functions: `camelCase` (e.g., `processImages`)
   - Constants: `camelCase` (e.g., `maxFileSize`)

2. **Formatting**:
   - Indent with 4 spaces
   - Max line length: 120 characters
   - Always use braces for control flow

3. **SwiftUI**:
   - Extract complex views into separate structs
   - Use `@State` for local state, `@Binding` for passed state
   - Prefer `@EnvironmentObject` for shared app state

4. **Async/Await**:
   - Use `async/await` instead of completion handlers
   - Use actors for shared mutable state
   - Mark functions `@MainActor` when updating UI

### Example

```swift
// Good ✅
public actor ImageProcessor {
    public func processImage(
        _ imageURL: URL,
        quality: Double = 0.8
    ) async throws -> URL {
        guard let imageData = try? Data(contentsOf: imageURL) else {
            throw ImageError.invalidImage(imageURL.lastPathComponent)
        }
        // Process image...
        return outputURL
    }
}

// Bad ❌
func processImage(url: URL, q: Double, completion: @escaping (URL?, Error?) -> Void) {
    // Avoid completion handlers and unclear names
}
```

## Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process, CI, dependencies

### Examples

```
feat(pdf): add watermark tiling mode

- Implement tiled watermark rendering
- Add UI controls for tile spacing
- Update tests

Closes #123
```

```
fix(video): correct bitrate calculation for target size

The previous formula was too aggressive, resulting in files
larger than the target. Adjusted the safety factor from 0.95 to 0.9.

Fixes #456
```

## Pull Request Process

### Before Submitting

1. **Update your branch**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests**:
   ```bash
   fastlane tests
   # or
   xcodebuild test -scheme OneBox
   ```

3. **Run SwiftLint**:
   ```bash
   swiftlint
   ```

4. **Update documentation** if needed

### Submitting the PR

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request** on GitHub

3. **Fill out the PR template**:
   - Description of changes
   - Related issue(s)
   - Screenshots (if UI changes)
   - Checklist completion

### PR Review Process

- A maintainer will review your PR within 2-3 business days
- Address any requested changes
- Once approved, a maintainer will merge your PR

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] No new warnings
- [ ] Commit messages follow convention

## Testing Guidelines

### Unit Tests

- Write tests for all new functionality
- Aim for ≥70% code coverage
- Use descriptive test names: `testCreatePDFFromImages()`
- Follow AAA pattern: Arrange, Act, Assert

```swift
func testCompressPDFReducesFileSize() async throws {
    // Arrange
    let sourcePDF = try await createTestPDF(pageCount: 10)
    let originalSize = try fileSize(of: sourcePDF)

    // Act
    let compressedURL = try await processor.compressPDF(
        sourcePDF,
        quality: .medium
    )

    // Assert
    let compressedSize = try fileSize(of: compressedURL)
    XCTAssertLessThan(compressedSize, originalSize)

    // Cleanup
    try FileManager.default.removeItem(at: sourcePDF)
    try FileManager.default.removeItem(at: compressedURL)
}
```

### UI Tests

- Write UI tests for critical user flows
- Use accessibility identifiers
- Keep tests stable (avoid hardcoded delays)

### Performance Tests

Use `measure` blocks for performance-critical code:

```swift
func testImageProcessingPerformance() {
    measure {
        // Code to test
    }
}
```

## Documentation

### Code Comments

- Use `///` for public APIs (DocC format)
- Explain **why**, not **what**
- Keep comments up-to-date

### Example

```swift
/// Compresses a PDF to a target file size using binary search on JPEG quality.
///
/// This method iteratively compresses the PDF, adjusting the JPEG quality of embedded
/// images until the output size is below the target. It may take multiple iterations.
///
/// - Parameters:
///   - pdfURL: The source PDF URL
///   - targetSizeMB: The desired maximum file size in megabytes
///   - progressHandler: Callback for progress updates (0.0 to 1.0)
/// - Returns: URL of the compressed PDF
/// - Throws: `PDFError.targetSizeUnachievable` if the target cannot be met
public func compressPDF(
    _ pdfURL: URL,
    targetSizeMB: Double,
    progressHandler: @escaping (Double) -> Void
) async throws -> URL {
    // Implementation...
}
```

## Questions?

- Open an [Issue](https://github.com/yourcompany/onebox/issues)
- Start a [Discussion](https://github.com/yourcompany/onebox/discussions)
- Email: dev@yourcompany.com

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to OneBox! 🙌**
