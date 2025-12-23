//
//  ScreenshotTests.swift
//  OneBox - App Store Screenshot Automation
//
//  Captures 5 key screenshots for App Store listing:
//  1. Home Screen (Hero/Privacy Promise)
//  2. Tool Grid (All Features)
//  3. Privacy Dashboard (Security Focus)
//  4. Sign PDF (Feature Demo)
//  5. Success Screen (Results)
//

import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true

        // Configure app for screenshot mode
        app.launchArguments = [
            "--uitesting",
            "--screenshots",
            "--skip-onboarding",
            "--demo-mode"
        ]

        // Initialize fastlane snapshot helper
        setupSnapshot(app)

        app.launch()

        // Wait for app to fully load
        sleep(1)
    }

    override func tearDownWithError() throws {
        // Cleanup if needed
    }

    // MARK: - Main Screenshot Test

    func testCaptureAppStoreScreenshots() throws {
        // Screenshot 1: Home Screen (Hero Section)
        // Shows: Logo, "100% Offline" badge, premium aesthetic
        captureHomeScreen()

        // Screenshot 2: Tool Grid
        // Shows: All 10 PDF tools available
        captureToolGrid()

        // Screenshot 3: Privacy Dashboard
        // Shows: Security features, no data collection
        capturePrivacyDashboard()

        // Screenshot 4: Sign PDF Feature
        // Shows: Interactive signing capability
        captureSignPDF()

        // Screenshot 5: Success/Results Screen
        // Shows: Professional output, export options
        captureResultsScreen()
    }

    // MARK: - Individual Screenshot Captures

    private func captureHomeScreen() {
        // Ensure we're on the home tab
        let homeTab = app.tabBars.buttons["Toolbox"]
        if homeTab.exists && !homeTab.isSelected {
            homeTab.tap()
            sleep(1)
        }

        // Scroll to top to show hero section
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeDown()
            scrollView.swipeDown()
        }

        sleep(1)
        snapshot("01_HomeScreen_Hero")
    }

    private func captureToolGrid() {
        // Ensure we're on home
        let homeTab = app.tabBars.buttons["Toolbox"]
        if homeTab.exists && !homeTab.isSelected {
            homeTab.tap()
            sleep(1)
        }

        // Scroll down to show tool grid
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // Scroll past hero to show tool cards
            scrollView.swipeUp()
        }

        sleep(1)
        snapshot("02_ToolGrid_AllFeatures")
    }

    private func capturePrivacyDashboard() {
        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)
        }

        // Tap Privacy Dashboard
        let privacyDashboard = app.buttons["Privacy Dashboard"]
        if privacyDashboard.waitForExistence(timeout: 3) {
            privacyDashboard.tap()
            sleep(1)
        } else {
            // Try finding it as a cell or static text
            let privacyCell = app.cells.containing(.staticText, identifier: "Privacy Dashboard").firstMatch
            if privacyCell.exists {
                privacyCell.tap()
                sleep(1)
            }
        }

        snapshot("03_PrivacyDashboard_Security")

        // Navigate back
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    private func captureSignPDF() {
        // Go back to home
        let homeTab = app.tabBars.buttons["Toolbox"]
        if homeTab.exists {
            homeTab.tap()
            sleep(1)
        }

        // Find and tap Sign PDF tool
        let signPDFCard = app.buttons["Sign PDF"]
        if signPDFCard.waitForExistence(timeout: 3) {
            signPDFCard.tap()
            sleep(1)
        } else {
            // Try scrolling to find it
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                sleep(1)
            }

            if signPDFCard.waitForExistence(timeout: 2) {
                signPDFCard.tap()
                sleep(1)
            }
        }

        // If we're in the Sign PDF view, wait for it to load
        // In demo mode, a sample PDF should be pre-loaded
        sleep(2)

        snapshot("04_SignPDF_Feature")

        // Navigate back
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    private func captureResultsScreen() {
        // Go back to home
        let homeTab = app.tabBars.buttons["Toolbox"]
        if homeTab.exists {
            homeTab.tap()
            sleep(1)
        }

        // Use a quick tool to generate a result
        // In demo mode, this should show a pre-configured success state
        let imagesToPDF = app.buttons["Images → PDF"]
        if imagesToPDF.waitForExistence(timeout: 3) {
            imagesToPDF.tap()
            sleep(1)

            // In demo mode, simulate quick processing
            // The app should auto-load demo content
            let processButton = app.buttons["Begin Secure Processing"]
            if processButton.waitForExistence(timeout: 3) {
                processButton.tap()

                // Wait for processing to complete
                let successIndicator = app.staticTexts["Success"]
                if successIndicator.waitForExistence(timeout: 10) {
                    sleep(1)
                }
            }
        }

        snapshot("05_Results_Success")
    }

    // MARK: - Alternative Screenshots (Bonus)

    func testCaptureAlternativeScreenshots() throws {
        // These are optional additional screenshots

        // Merge PDFs tool
        let homeTab = app.tabBars.buttons["Toolbox"]
        homeTab.tap()
        sleep(1)

        let mergePDFs = app.buttons["Merge PDFs"]
        if mergePDFs.waitForExistence(timeout: 3) {
            mergePDFs.tap()
            sleep(2)
            snapshot("Alt_MergePDFs")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Redact PDF tool
        homeTab.tap()
        sleep(1)

        let redactPDF = app.buttons["Redact PDF"]
        if redactPDF.waitForExistence(timeout: 3) {
            redactPDF.tap()
            sleep(2)
            snapshot("Alt_RedactPDF")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Watermark PDF tool
        homeTab.tap()
        sleep(1)

        let watermarkPDF = app.buttons["Watermark PDF"]
        if watermarkPDF.waitForExistence(timeout: 3) {
            watermarkPDF.tap()
            sleep(2)
            snapshot("Alt_WatermarkPDF")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    // MARK: - Upgrade/Paywall Screenshot

    func testCapturePaywallScreenshot() throws {
        // Navigate to upgrade screen
        let homeTab = app.tabBars.buttons["Toolbox"]
        homeTab.tap()
        sleep(1)

        // Look for upgrade button or trigger paywall
        let upgradeButton = app.buttons["Unlock Unlimited"]
        if upgradeButton.waitForExistence(timeout: 3) {
            upgradeButton.tap()
            sleep(2)
            snapshot("Bonus_Upgrade_Paywall")
        }
    }
}
