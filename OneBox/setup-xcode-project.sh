#!/bin/bash
# OneBox Xcode Project Setup Script
# This script sets up the Xcode project structure automatically

set -e  # Exit on error

echo "🎯 OneBox Xcode Project Setup"
echo "================================"
echo ""

# Check if we're in the right directory
if [ ! -f "project.yml" ]; then
    echo "❌ Error: project.yml not found. Please run from OneBox directory."
    exit 1
fi

# Step 1: Check prerequisites
echo "📋 Step 1: Checking prerequisites..."

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "⚠️  Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
else
    echo "✅ XcodeGen already installed"
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode not found. Please install Xcode from the App Store."
    exit 1
else
    echo "✅ Xcode found"
fi

# Step 2: Create necessary directories
echo ""
echo "📁 Step 2: Creating directory structure..."

mkdir -p OneBox/Assets.xcassets/AppIcon.appiconset
mkdir -p OneBox/Assets.xcassets/AccentColor.colorset
mkdir -p "OneBox/Preview Content"

echo "✅ Directories created"

# Step 3: Create Assets.xcassets Contents.json
echo ""
echo "🎨 Step 3: Creating asset catalogs..."

cat > OneBox/Assets.xcassets/Contents.json << 'ASSET_EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ASSET_EOF

cat > OneBox/Assets.xcassets/AppIcon.appiconset/Contents.json << 'APPICON_EOF'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
APPICON_EOF

cat > OneBox/Assets.xcassets/AccentColor.colorset/Contents.json << 'ACCENT_EOF'
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ACCENT_EOF

cat > "OneBox/Preview Content/Preview Assets.xcassets/Contents.json" << 'PREVIEW_EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
PREVIEW_EOF

echo "✅ Asset catalogs created"

# Step 4: Generate Xcode project
echo ""
echo "🔨 Step 4: Generating Xcode project..."

xcodegen generate

if [ -f "OneBox.xcodeproj/project.pbxproj" ]; then
    echo "✅ Xcode project generated successfully!"
else
    echo "❌ Failed to generate Xcode project"
    exit 1
fi

# Step 5: Open project in Xcode
echo ""
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Open OneBox.xcodeproj in Xcode"
echo "2. Update DEVELOPMENT_TEAM in project settings"
echo "3. Add app icon to Assets.xcassets/AppIcon.appiconset"
echo "4. Build and run (⌘R)"
echo ""
read -p "Would you like to open the project in Xcode now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open OneBox.xcodeproj
    echo "✅ Opened in Xcode!"
fi

echo ""
echo "📚 For more information, see: README.md"
