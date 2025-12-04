# Security Audit - Watermark Feature

## Core Security Principle
**OneBox is 100% on-device, API-free, and must work in airplane mode**

## Security Compliance Check ✅

### Current Implementation - COMPLIANT ✅
1. **CorePDF Watermarking**: Uses only PDFKit (Apple framework)
2. **No Network Calls**: Zero external API dependencies
3. **Airplane Mode**: Feature works perfectly offline
4. **Local Processing**: All watermark rendering happens in device memory
5. **No Cloud Storage**: PDFs never leave the device

### Security Concerns in Advanced View ⚠️

#### False Security Claims
The `AdaptiveWatermarkView` makes several misleading claims:
- "AI-powered placement" - Should clarify this is LOCAL Vision framework, not cloud AI
- "Anti-removal protection" - Feature doesn't exist, misleading users about security
- "Steganographic protection" - Not implemented, false claim

#### Recommendations
1. **Rename "AI-powered" to "Smart placement"** - Avoid implying cloud AI usage
2. **Remove security claims** that aren't implemented
3. **Add clear messaging** that all processing is 100% on-device

### What Should NEVER Be Added ❌
1. **Cloud watermarking services** (e.g., external watermark APIs)
2. **Online watermark templates** requiring downloads
3. **Watermark verification servers**
4. **Analytics on watermark usage**
5. **Cloud-based AI for positioning**
6. **External font downloads**
7. **Online image recognition**

### Security-First Watermark Features ✅
If expanding watermark functionality, only consider:
1. **Local Vision framework** for text detection (already on-device)
2. **Core Graphics** for advanced rendering
3. **Local steganography** using device-only algorithms
4. **Embedded metadata** using PDFKit properties
5. **Local QR generation** using Core Image

## Verification Checklist
- [x] Feature works in airplane mode
- [x] No import statements for networking libraries
- [x] No URL constructions for external services
- [x] All processing uses Apple frameworks
- [x] No third-party SDKs
- [x] No telemetry or usage tracking
- [x] Files remain in app sandbox

## Conclusion
The watermark feature is **security compliant** but the advanced view needs messaging updates to avoid misleading users about AI and security capabilities.