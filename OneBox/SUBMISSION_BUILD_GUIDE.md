# OneBox App Store Submission Build Guide

## Overview

This guide provides step-by-step instructions for building and submitting OneBox to the App Store. Follow these steps exactly to ensure a successful submission.

## Prerequisites

### Development Environment
- **Xcode**: 15.0 or later
- **iOS Deployment Target**: 16.0+
- **macOS**: 14.0+ (Sonoma)
- **Apple Developer Account**: Active membership required

### Required Tools
```bash
# Install fastlane (if not already installed)
sudo gem install fastlane

# Install xcode command line tools
xcode-select --install

# Verify tools are available
fastlane --version
xcodebuild -version
```

### Certificates and Provisioning Profiles
- ✅ iOS Distribution Certificate in Keychain
- ✅ App Store Distribution Provisioning Profile
- ✅ Bundle ID registered: `com.yourcompany.onebox`

## Pre-Submission Checklist

### 1. Code Quality ✅
```bash
# Run all tests
xcodebuild test -scheme OneBox -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Check for Swift 6 compatibility
xcodebuild build -scheme OneBox SWIFT_VERSION=6
```

### 2. Version Configuration ✅
- **MARKETING_VERSION**: `1.0.0`
- **CURRENT_PROJECT_VERSION**: `1` (increment for each build)
- **Bundle ID**: `com.yourcompany.onebox`
- **Deployment Target**: `16.0`

### 3. App Store Connect Configuration ✅
- App listing created with all metadata
- In-app purchase products configured:
  - `com.onebox.pro.monthly` - $4.99/month
  - `com.onebox.pro.yearly` - $29.99/year
  - `com.onebox.pro.lifetime` - $69.99
- Privacy information set to "Data Not Collected"

## Build Process

### Step 1: Prepare Release Configuration

```bash
# Navigate to project directory
cd /path/to/OneBox

# Clean previous builds
xcodebuild clean -scheme OneBox

# Update build number (increment from previous)
agvtool next-version -all
```

### Step 2: Create Archive Build

```bash
# Create archive for App Store distribution
xcodebuild archive \
  -scheme OneBox \
  -configuration Release \
  -destination generic/platform=iOS \
  -archivePath "OneBox.xcarchive"
```

**Expected output:**
```
** ARCHIVE SUCCEEDED **
Archive created at: /path/to/OneBox.xcarchive
```

### Step 3: Export IPA for App Store

```bash
# Export signed IPA using distribution profile
xcodebuild -exportArchive \
  -archivePath "OneBox.xcarchive" \
  -exportPath "Export/" \
  -exportOptionsPlist "ExportOptions.plist"
```

**Create ExportOptions.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

### Step 4: Upload to App Store Connect

```bash
# Upload using Application Loader or xcodebuild
xcrun altool --upload-app \
  --type ios \
  --file "Export/OneBox.ipa" \
  --username "your@apple.id" \
  --password "@keychain:Application Loader: your@apple.id"
```

**Alternative using Transporter:**
1. Open Transporter app
2. Drag OneBox.ipa to upload area
3. Wait for upload completion and processing

## Validation Steps

### Pre-Upload Validation
```bash
# Validate archive before upload
xcrun altool --validate-app \
  --type ios \
  --file "Export/OneBox.ipa" \
  --username "your@apple.id" \
  --password "@keychain:Application Loader: your@apple.id"
```

**Common validation errors and fixes:**
- **Missing icons**: Ensure all required app icon sizes are in Assets.xcassets
- **Invalid bundle**: Check Bundle ID matches App Store Connect
- **Missing launch screen**: Verify Launch Screen.storyboard is configured

### Post-Upload Verification
1. ✅ Build appears in App Store Connect within 30 minutes
2. ✅ No processing errors in App Store Connect
3. ✅ Build shows "Ready to Submit" status
4. ✅ All metadata and screenshots are properly configured

## Performance Verification

Run performance benchmarks to ensure targets are met:

```bash
# Run performance tests on device
xcodebuild test -scheme OneBox \
  -destination 'platform=iOS,name=YOUR_DEVICE_NAME' \
  -testPlan PerformanceTests.xctestplan

# Expected results (must pass):
# ✅ 50 images → PDF: < 12 seconds
# ✅ PDF merge (5 docs): < 3 seconds  
# ✅ Memory usage: < 200MB peak
# ✅ App launch: < 2 seconds
```

## TestFlight Distribution

### Internal Testing
```bash
# Submit for internal testing first
1. Go to App Store Connect > TestFlight
2. Select the uploaded build
3. Add internal testers
4. Provide test information
5. Submit for internal testing
```

### External Testing (Optional)
```bash
# After internal testing passes
1. Create external test group
2. Add test notes and instructions
3. Submit for external beta review
4. Distribute to external testers
```

## Final Submission to App Store

### 1. Review Submission Details
- ✅ App version: 1.0.0
- ✅ Build selected: Latest uploaded build
- ✅ Release type: Automatic after approval
- ✅ Phased release: Enabled (7-day rollout)

### 2. Export Compliance
- ✅ "No" - App doesn't use encryption beyond HTTPS

### 3. Content Rights
- ✅ Confirm you have rights to all content

### 4. Advertising Identifier (IDFA)
- ✅ "No" - OneBox doesn't use advertising identifiers

### 5. Submit for Review
```bash
# Final submission checklist:
- [ ] All App Store Connect metadata complete
- [ ] Screenshots uploaded for all device sizes
- [ ] App description and keywords optimized
- [ ] Privacy policy URL provided
- [ ] Support URL provided
- [ ] Age rating completed
- [ ] In-app purchase products approved
- [ ] Final build selected and tested
- [ ] Export compliance completed
```

## Post-Submission Monitoring

### Review Status Tracking
Monitor submission status in App Store Connect:

1. **Waiting for Review** (24-48 hours typical)
2. **In Review** (24-48 hours typical) 
3. **Pending Developer Release** / **Ready for Sale**

### Expedited Review (If Needed)
Only use for critical bug fixes:
1. Go to App Store Connect > Contact Us
2. Select "App Review" > "Request Expedited Review"
3. Provide detailed justification

### Common Rejection Reasons and Solutions

**Performance Issues:**
- App crashes during review → Fix crashes, re-submit
- Slow performance → Optimize critical paths, verify on older devices

**Privacy Policy:**
- Missing privacy policy → Add privacy policy URL to App Store Connect
- Inaccurate data collection claims → Update privacy information

**Metadata Issues:**
- Misleading description → Update app description for accuracy
- Invalid keywords → Remove trademarked or irrelevant keywords

**In-App Purchase Issues:**
- Purchase flow doesn't work → Test all purchase scenarios thoroughly
- Missing restore purchases → Implement and test restore functionality

## Success Metrics

### Technical Targets ✅
- Build uploads successfully without errors
- All validation passes
- Performance benchmarks met
- No crashes in TestFlight

### Business Targets
- App approved within 7 days
- Privacy-first positioning clear in listing
- Competitive pricing ($4.99/month) set
- Feature differentiation highlighted

## Emergency Procedures

### Critical Bug After Submission
```bash
# If critical bug found after submission:
1. Immediately fix the bug
2. Increment build number
3. Create new archive and upload
4. Contact App Review team to review latest build
5. Consider expedited review if user-affecting
```

### Rejection Response
```bash
# If app is rejected:
1. Read rejection reason carefully
2. Address ALL issues mentioned
3. Test fixes thoroughly
4. Include resolution notes in "Review Notes"
5. Re-submit with incremented build number
```

## Support Resources

### Apple Documentation
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)

### Troubleshooting
- **Build Fails**: Check Xcode logs, verify certificates
- **Upload Fails**: Check network, try Transporter app
- **Validation Errors**: Review bundle configuration and assets

---

**Status**: 🟢 Ready for Submission
**Estimated Timeline**: 3-7 days for initial review
**Next Steps**: Execute build process and submit for review