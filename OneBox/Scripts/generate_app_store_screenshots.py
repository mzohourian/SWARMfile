#!/usr/bin/env python3
"""
OneBox App Store Screenshot Generation Script

This script automates the process of capturing screenshots for App Store submission.
It uses Xcode's Simulator and UI testing to generate consistent, high-quality screenshots.

Requirements:
- Xcode with iOS Simulators
- Python 3.7+
- xcodebuild command line tools

Usage:
    python3 generate_app_store_screenshots.py [--clean] [--device=DEVICE]
"""

import subprocess
import os
import sys
import argparse
import time
import json
from pathlib import Path

# App Store screenshot requirements
SCREENSHOT_DEVICES = {
    # iPhone screenshots (required)
    "iPhone 15 Pro Max": {
        "simulator": "iPhone 15 Pro Max",
        "size": "6.7-inch",
        "required": True,
        "screenshots": [
            "home_screen",
            "images_to_pdf_flow", 
            "pdf_merge_interface",
            "interactive_signing",
            "privacy_dashboard"
        ]
    },
    "iPhone 15": {
        "simulator": "iPhone 15",
        "size": "6.1-inch", 
        "required": True,
        "screenshots": [
            "home_screen",
            "tool_selection",
            "processing_progress",
            "export_options",
            "settings_privacy"
        ]
    },
    # iPad screenshots (required)
    "iPad Pro 12.9-inch": {
        "simulator": "iPad Pro (12.9-inch) (6th generation)",
        "size": "12.9-inch",
        "required": True,
        "screenshots": [
            "split_view_tools",
            "page_organizer_grid", 
            "workflow_automation",
            "settings_landscape"
        ]
    }
}

class ScreenshotGenerator:
    def __init__(self, project_path, scheme="OneBox"):
        self.project_path = Path(project_path)
        self.scheme = scheme
        self.output_dir = self.project_path / "Screenshots" / "AppStore"
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Test plan for UI tests that capture screenshots
        self.test_plan = "OneBoxUITests/ScreenshotTests.xctestplan"
        
    def clean_screenshots(self):
        """Remove existing screenshots"""
        print("🗑️  Cleaning existing screenshots...")
        
        if self.output_dir.exists():
            for file in self.output_dir.glob("*.png"):
                file.unlink()
        
    def boot_simulator(self, device_name):
        """Boot the specified simulator"""
        print(f"🚀 Booting {device_name} simulator...")
        
        # Get device UUID
        result = subprocess.run([
            "xcrun", "simctl", "list", "devices", "-j"
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ Failed to list simulators: {result.stderr}")
            return False
            
        devices = json.loads(result.stdout)
        device_uuid = None
        
        for runtime, device_list in devices["devices"].items():
            for device in device_list:
                if device["name"] == device_name and device["isAvailable"]:
                    device_uuid = device["udid"]
                    break
            if device_uuid:
                break
        
        if not device_uuid:
            print(f"❌ Device '{device_name}' not found or not available")
            return False
        
        # Boot simulator
        result = subprocess.run([
            "xcrun", "simctl", "boot", device_uuid
        ], capture_output=True, text=True)
        
        if result.returncode != 0 and "Unable to boot device in current state: Booted" not in result.stderr:
            print(f"❌ Failed to boot simulator: {result.stderr}")
            return False
            
        # Wait for boot to complete
        time.sleep(5)
        
        # Open Simulator app
        subprocess.run(["open", "-a", "Simulator"])
        time.sleep(2)
        
        return device_uuid
        
    def setup_simulator_environment(self, device_uuid):
        """Configure simulator for screenshot capture"""
        print("⚙️  Setting up simulator environment...")
        
        # Set up clean state
        commands = [
            # Reset content and settings for clean state
            ["xcrun", "simctl", "erase", device_uuid],
            
            # Configure device settings for screenshots
            ["xcrun", "simctl", "spawn", device_uuid, "defaults", "write", "com.apple.springboard", "SBShowNonDefaultSystemApps", "-bool", "true"],
            
            # Set appearance mode (light mode for screenshots)
            ["xcrun", "simctl", "ui", device_uuid, "appearance", "light"],
            
            # Disable auto-lock
            ["xcrun", "simctl", "spawn", device_uuid, "defaults", "write", "com.apple.springboard", "SBAutoLockTime", "0"],
        ]
        
        for cmd in commands:
            subprocess.run(cmd, capture_output=True)
            
        time.sleep(3)
        
    def install_app_to_simulator(self, device_uuid):
        """Build and install app to simulator"""
        print(f"📱 Installing OneBox to simulator...")
        
        # Build for simulator
        result = subprocess.run([
            "xcodebuild", 
            "-project", str(self.project_path / "OneBox.xcodeproj"),
            "-scheme", self.scheme,
            "-configuration", "Debug",
            "-sdk", "iphonesimulator",
            "-destination", f"id={device_uuid}",
            "build"
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ Failed to build app: {result.stderr}")
            return False
            
        # Install app
        result = subprocess.run([
            "xcodebuild",
            "-project", str(self.project_path / "OneBox.xcodeproj"), 
            "-scheme", self.scheme,
            "-configuration", "Debug",
            "-sdk", "iphonesimulator",
            "-destination", f"id={device_uuid}",
            "install"
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ Failed to install app: {result.stderr}")
            return False
            
        return True
        
    def run_screenshot_tests(self, device_uuid, device_config):
        """Run UI tests to capture screenshots"""
        print(f"📷 Capturing screenshots for {device_config['simulator']}...")
        
        # Set environment variables for screenshot tests
        env = os.environ.copy()
        env["SCREENSHOT_MODE"] = "true"
        env["SCREENSHOT_DEVICE"] = device_config["simulator"] 
        env["SCREENSHOT_OUTPUT_DIR"] = str(self.output_dir)
        
        # Run UI tests
        result = subprocess.run([
            "xcodebuild",
            "test",
            "-project", str(self.project_path / "OneBox.xcodeproj"),
            "-scheme", self.scheme,
            "-destination", f"id={device_uuid}",
            "-testPlan", self.test_plan,
            "OTHER_SWIFT_FLAGS=-DSCREENSHOT_MODE"
        ], env=env, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"⚠️  Screenshot tests completed with issues: {result.stderr}")
            # Don't fail completely - some screenshots might have been captured
        else:
            print(f"✅ Screenshot tests completed successfully")
            
        return True
        
    def organize_screenshots(self, device_config):
        """Organize screenshots into App Store directory structure"""
        device_name = device_config["simulator"].replace(" ", "_").replace("(", "").replace(")", "")
        device_dir = self.output_dir / device_name
        device_dir.mkdir(exist_ok=True)
        
        # Move screenshots to device-specific folders
        for screenshot_file in self.output_dir.glob("*.png"):
            if device_name.lower() in screenshot_file.name.lower():
                new_path = device_dir / screenshot_file.name
                screenshot_file.rename(new_path)
                print(f"📁 Moved {screenshot_file.name} to {device_dir.name}/")
                
    def create_screenshot_manifest(self):
        """Create a manifest of all captured screenshots"""
        manifest = {
            "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            "devices": {}
        }
        
        for device_dir in self.output_dir.iterdir():
            if device_dir.is_dir():
                screenshots = list(device_dir.glob("*.png"))
                manifest["devices"][device_dir.name] = {
                    "screenshot_count": len(screenshots),
                    "screenshots": [s.name for s in screenshots]
                }
                
        manifest_file = self.output_dir / "manifest.json"
        with open(manifest_file, "w") as f:
            json.dump(manifest, f, indent=2)
            
        print(f"📋 Created screenshot manifest: {manifest_file}")
        
    def generate_all_screenshots(self, clean=False, specific_device=None):
        """Generate all required screenshots"""
        print("🚀 Starting App Store screenshot generation...")
        
        if clean:
            self.clean_screenshots()
            
        devices_to_process = SCREENSHOT_DEVICES
        if specific_device:
            if specific_device in SCREENSHOT_DEVICES:
                devices_to_process = {specific_device: SCREENSHOT_DEVICES[specific_device]}
            else:
                print(f"❌ Device '{specific_device}' not found in configuration")
                return False
                
        success_count = 0
        total_devices = len(devices_to_process)
        
        for device_name, device_config in devices_to_process.items():
            print(f"\n📱 Processing {device_name} ({success_count + 1}/{total_devices})")
            
            try:
                # Boot simulator
                device_uuid = self.boot_simulator(device_name)
                if not device_uuid:
                    continue
                    
                # Setup environment
                self.setup_simulator_environment(device_uuid)
                
                # Install app
                if not self.install_app_to_simulator(device_uuid):
                    continue
                    
                # Capture screenshots
                if not self.run_screenshot_tests(device_uuid, device_config):
                    continue
                    
                # Organize screenshots
                self.organize_screenshots(device_config)
                
                success_count += 1
                print(f"✅ Completed {device_name}")
                
            except Exception as e:
                print(f"❌ Failed to process {device_name}: {e}")
                continue
                
        # Create manifest
        self.create_screenshot_manifest()
        
        print(f"\n🎉 Screenshot generation completed!")
        print(f"✅ Successfully processed {success_count}/{total_devices} devices")
        print(f"📁 Screenshots saved to: {self.output_dir}")
        
        if success_count < total_devices:
            print(f"⚠️  {total_devices - success_count} devices failed - check logs above")
            
        return success_count == total_devices

def main():
    parser = argparse.ArgumentParser(description="Generate App Store screenshots for OneBox")
    parser.add_argument("--clean", action="store_true", help="Clean existing screenshots before generating")
    parser.add_argument("--device", help="Generate screenshots for specific device only")
    parser.add_argument("--project-path", default=".", help="Path to Xcode project (default: current directory)")
    
    args = parser.parse_args()
    
    # Verify we're in the right directory
    project_path = Path(args.project_path)
    if not (project_path / "OneBox.xcodeproj").exists():
        print("❌ OneBox.xcodeproj not found. Run this script from the project root directory.")
        sys.exit(1)
        
    generator = ScreenshotGenerator(project_path)
    success = generator.generate_all_screenshots(
        clean=args.clean,
        specific_device=args.device
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()