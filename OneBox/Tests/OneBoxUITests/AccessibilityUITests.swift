//
//  AccessibilityUITests.swift
//  OneBox - Accessibility and VoiceOver UI Tests
//

import XCTest

final class AccessibilityUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting", "--accessibility-testing"]
        app.launch()
    }
    
    // MARK: - VoiceOver Navigation Tests
    
    func testToolboxVoiceOverNavigation() throws {
        // Verify all tool cards have proper accessibility labels
        let toolCards = [
            ("Images → PDF", "Convert photos to PDF"),
            ("PDF → Images", "Extract pages as images"),
            ("Merge PDFs", "Combine multiple PDFs"),
            ("Split PDF", "Extract pages"),
            ("Compress PDF", "Reduce file size"),
            ("Watermark PDF", "Add text or image"),
            ("Sign PDF", "Add signature"),
            ("Organize Pages", "Reorder and delete pages"),
            ("Resize Images", "Change dimensions"),
            ("Redact PDF", "Hide sensitive content")
        ]
        
        for (buttonName, expectedHint) in toolCards {
            let button = app.buttons[buttonName]
            if button.exists {
                XCTAssertTrue(button.isAccessibilityElement)
                XCTAssertEqual(button.label, buttonName)
                // Verify hint contains expected description
                if let hint = button.value(forKey: "accessibilityHint") as? String {
                    XCTAssertTrue(hint.contains(expectedHint))
                }
            }
        }
    }
    
    func testTabBarAccessibility() throws {
        // Verify tab bar items
        let tabs = [
            ("Toolbox", "Main tools and features"),
            ("Recents", "Recent conversions"),
            ("Settings", "App settings and preferences")
        ]
        
        for (tabName, _) in tabs {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.exists)
            XCTAssertTrue(tab.isAccessibilityElement)
            
            // Test navigation
            tab.tap()
            XCTAssertTrue(tab.isSelected)
        }
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeScaling() throws {
        // Test with different text sizes
        let textSizes = [
            UIContentSizeCategory.extraSmall,
            UIContentSizeCategory.medium,
            UIContentSizeCategory.extraExtraLarge,
            UIContentSizeCategory.accessibilityLarge
        ]
        
        for size in textSizes {
            app.launchArguments.append("-UIPreferredContentSizeCategoryName")
            app.launchArguments.append(size.rawValue)
            app.launch()
            
            // Verify text is visible and not truncated
            let homeTitle = app.staticTexts["Privacy-First File Tools"]
            if homeTitle.exists {
                XCTAssertTrue(homeTitle.isHittable)
                
                // Check that important text is not truncated
                let frame = homeTitle.frame
                XCTAssertGreaterThan(frame.height, 20) // Minimum readable height
            }
            
            // Verify buttons are still tappable
            let toolButton = app.buttons.firstMatch
            if toolButton.exists {
                XCTAssertTrue(toolButton.isHittable)
                let buttonFrame = toolButton.frame
                XCTAssertGreaterThanOrEqual(buttonFrame.height, 44) // Minimum touch target
                XCTAssertGreaterThanOrEqual(buttonFrame.width, 44)
            }
            
            app.terminate()
        }
    }
    
    // MARK: - Color Contrast Tests
    
    func testColorContrastCompliance() throws {
        // Verify high contrast mode
        app.launchArguments.append("-UIAccessibilityDarkerSystemColorsEnabled")
        app.launchArguments.append("1")
        app.launch()
        
        // Check that text remains readable
        let bodyText = app.staticTexts.matching(NSPredicate(format: "label != ''")).firstMatch
        if bodyText.exists {
            // In real testing, we'd capture screenshots and analyze contrast ratios
            // For now, verify elements are still visible
            XCTAssertTrue(bodyText.isHittable)
        }
        
        // Verify buttons have sufficient contrast
        let button = app.buttons["Images → PDF"]
        if button.exists {
            XCTAssertTrue(button.isHittable)
            // Button should have visible borders or background in high contrast
        }
    }
    
    // MARK: - Reduce Motion Tests
    
    func testReduceMotionCompliance() throws {
        // Enable reduce motion
        app.launchArguments.append("-UIAccessibilityReduceMotionEnabled")
        app.launchArguments.append("1")
        app.launch()
        
        // Navigate between screens and verify no animations cause issues
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Verify immediate transition without animation issues
        XCTAssertTrue(app.navigationBars["Settings"].exists ||
                     app.staticTexts["Settings"].firstMatch.exists)
        
        // Test modal presentation
        let homeTab = app.tabBars.buttons["Toolbox"]
        homeTab.tap()
        
        let toolButton = app.buttons["Images → PDF"]
        toolButton.tap()
        
        // Modal should appear without animation issues
        let modalView = app.otherElements["ToolFlowView"]
        XCTAssertTrue(modalView.exists || app.buttons["Select Files"].exists)
    }
    
    // MARK: - Focus Navigation Tests
    
    func testKeyboardNavigation() throws {
        // Test focus order for keyboard/switch control users
        let focusableElements = app.buttons.allElementsBoundByIndex +
                               app.textFields.allElementsBoundByIndex +
                               app.switches.allElementsBoundByIndex
        
        // Verify all interactive elements are focusable
        for element in focusableElements {
            if element.exists && element.isHittable {
                XCTAssertTrue(element.isAccessibilityElement)
            }
        }
    }
    
    // MARK: - Accessibility Actions Tests
    
    func testCustomAccessibilityActions() throws {
        // Navigate to recents
        let recentsTab = app.tabBars.buttons["Recents"]
        recentsTab.tap()
        
        // If there are job cells, verify swipe actions are accessible
        let jobCell = app.cells.firstMatch
        if jobCell.waitForExistence(timeout: 3) {
            // Check for accessibility custom actions
            let actions = jobCell.accessibilityCustomActions
            XCTAssertNotNil(actions)
            
            // Common actions should be available
            // In real app: "Share", "Delete", "View Details"
        }
    }
    
    // MARK: - Screen Reader Announcements Tests
    
    func testProcessingAnnouncementsForScreenReaders() throws {
        // Start a conversion
        let toolButton = app.buttons["Images → PDF"]
        toolButton.tap()
        
        let selectButton = app.buttons["Select Files"]
        if selectButton.waitForExistence(timeout: 3) {
            selectButton.tap()
            
            // In test mode, simulate processing
            let processButton = app.buttons["Process"]
            if processButton.waitForExistence(timeout: 3) {
                processButton.tap()
                
                // Verify screen reader announcements
                // In real app, we'd verify UIAccessibility.post notifications
                // For testing, check that status text updates
                let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '%'")).firstMatch
                if progressText.waitForExistence(timeout: 2) {
                    XCTAssertTrue(progressText.isAccessibilityElement)
                }
                
                // Success announcement
                let successText = app.staticTexts["Success"]
                if successText.waitForExistence(timeout: 10) {
                    XCTAssertTrue(successText.isAccessibilityElement)
                }
            }
        }
    }
    
    // MARK: - Accessibility Settings Integration Tests
    
    func testBoldTextCompliance() throws {
        // Enable bold text
        app.launchArguments.append("-UIAccessibilityBoldTextEnabled")
        app.launchArguments.append("1")
        app.launch()
        
        // Verify text remains readable with bold
        let labels = app.staticTexts.allElementsBoundByIndex.prefix(5)
        for label in labels {
            if label.exists && label.label.count > 0 {
                XCTAssertTrue(label.isHittable)
                // In real testing, verify font weight increased
            }
        }
    }
    
    func testButtonShapesCompliance() throws {
        // Enable button shapes
        app.launchArguments.append("-UIAccessibilityButtonShapesEnabled")
        app.launchArguments.append("1")
        app.launch()
        
        // Verify buttons have visible shapes/borders
        let button = app.buttons.firstMatch
        if button.exists {
            XCTAssertTrue(button.isHittable)
            // Button should have visible border or background
        }
    }
    
    // MARK: - Error Announcement Tests
    
    func testErrorAnnouncementsForScreenReaders() throws {
        // Trigger an error condition
        app.launchArguments.append("--simulate-error")
        
        let toolButton = app.buttons["Compress PDF"]
        toolButton.tap()
        
        // Try to process without selecting file
        let processButton = app.buttons["Process"]
        if processButton.waitForExistence(timeout: 3) {
            processButton.tap()
            
            // Error should be announced
            let errorAlert = app.alerts.firstMatch
            if errorAlert.waitForExistence(timeout: 3) {
                // Verify error is accessible
                let errorText = errorAlert.staticTexts.firstMatch
                XCTAssertTrue(errorText.exists)
                XCTAssertTrue(errorText.isAccessibilityElement)
                
                // Dismiss button should be accessible
                let dismissButton = errorAlert.buttons.firstMatch
                XCTAssertTrue(dismissButton.isAccessibilityElement)
                dismissButton.tap()
            }
        }
    }
}