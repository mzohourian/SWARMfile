//
//  OneBoxUITests.swift
//  OneBox - UI Tests for Critical User Journeys
//

import XCTest

final class OneBoxUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Reset app state for consistent testing
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        // Clean up
    }
    
    // MARK: - Test Journey 1: Images to PDF Conversion
    
    func testImagesToPDFConversion() throws {
        // Navigate to Images → PDF tool
        let imagesToPDFCard = app.buttons["Images → PDF"]
        XCTAssertTrue(imagesToPDFCard.waitForExistence(timeout: 5))
        imagesToPDFCard.tap()
        
        // Wait for tool flow view
        let selectFilesButton = app.buttons["Select Files"]
        XCTAssertTrue(selectFilesButton.waitForExistence(timeout: 3))
        
        // Tap select files (would open photo picker in real app)
        selectFilesButton.tap()
        
        // In UI test mode, we'd mock the photo picker response
        // Wait for configuration screen
        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 5) {
            // Verify we're on configuration step
            XCTAssertTrue(app.staticTexts["Page Settings"].exists)
            
            // Test page size picker
            let pageSizePicker = app.pickers["PageSizePicker"]
            if pageSizePicker.exists {
                pageSizePicker.pickerWheels.element.adjust(toPickerWheelValue: "Letter")
            }
            
            // Test orientation toggle
            let portraitButton = app.buttons["Portrait"]
            let landscapeButton = app.buttons["Landscape"]
            if landscapeButton.exists {
                landscapeButton.tap()
                XCTAssertTrue(landscapeButton.isSelected)
            }
            
            // Proceed to process
            let processButton = app.buttons["Process"]
            XCTAssertTrue(processButton.exists)
            processButton.tap()
            
            // Verify processing view appears
            let progressView = app.progressIndicators.firstMatch
            XCTAssertTrue(progressView.waitForExistence(timeout: 2))
            
            // Wait for result
            let successText = app.staticTexts["Success"]
            XCTAssertTrue(successText.waitForExistence(timeout: 10))
            
            // Verify export options
            XCTAssertTrue(app.buttons["Save to Files"].exists)
            XCTAssertTrue(app.buttons["Share"].exists)
        }
    }
    
    // MARK: - Test Journey 2: PDF Merge
    
    func testPDFMerge() throws {
        // Navigate to Merge PDFs tool
        let mergePDFsCard = app.buttons["Merge PDFs"]
        XCTAssertTrue(mergePDFsCard.waitForExistence(timeout: 5))
        mergePDFsCard.tap()
        
        // Wait for tool flow view
        let selectFilesButton = app.buttons["Select Files"]
        XCTAssertTrue(selectFilesButton.waitForExistence(timeout: 3))
        selectFilesButton.tap()
        
        // In UI test mode, mock file selection
        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 5) {
            // Verify we're on merge configuration
            XCTAssertTrue(app.staticTexts["Drag to reorder"].exists || 
                         app.staticTexts["File Order"].exists)
            
            // Test reordering (if list exists)
            let fileList = app.tables.firstMatch
            if fileList.exists {
                let firstCell = fileList.cells.element(boundBy: 0)
                let secondCell = fileList.cells.element(boundBy: 1)
                
                if firstCell.exists && secondCell.exists {
                    // Attempt drag and drop
                    firstCell.press(forDuration: 0.5, thenDragTo: secondCell)
                }
            }
            
            // Process merge
            let processButton = app.buttons["Process"]
            XCTAssertTrue(processButton.exists)
            processButton.tap()
            
            // Verify processing
            let progressView = app.progressIndicators.firstMatch
            XCTAssertTrue(progressView.waitForExistence(timeout: 2))
            
            // Wait for success
            let successText = app.staticTexts["Success"]
            XCTAssertTrue(successText.waitForExistence(timeout: 10))
        }
    }
    
    // MARK: - Test Journey 3: PDF Compression
    
    func testPDFCompression() throws {
        // Navigate to Compress PDF tool
        let compressPDFCard = app.buttons["Compress PDF"]
        XCTAssertTrue(compressPDFCard.waitForExistence(timeout: 5))
        compressPDFCard.tap()
        
        // Select file
        let selectFilesButton = app.buttons["Select Files"]
        XCTAssertTrue(selectFilesButton.waitForExistence(timeout: 3))
        selectFilesButton.tap()
        
        // Wait for configuration
        let nextButton = app.buttons["Next"]
        if nextButton.waitForExistence(timeout: 5) {
            // Verify compression settings
            XCTAssertTrue(app.staticTexts["Compression Settings"].exists ||
                         app.staticTexts["Quality"].exists)
            
            // Test quality preset buttons
            let mediumQualityButton = app.buttons["Medium"]
            let highQualityButton = app.buttons["High"]
            
            if mediumQualityButton.exists {
                mediumQualityButton.tap()
                // Verify selection state if available
            }
            
            // Test target size mode toggle
            let targetSizeSwitch = app.switches["Target Size Mode"]
            if targetSizeSwitch.exists {
                targetSizeSwitch.tap()
                
                // Verify target size field appears
                let targetSizeField = app.textFields["TargetSizeField"]
                if targetSizeField.waitForExistence(timeout: 2) {
                    targetSizeField.tap()
                    targetSizeField.typeText("5")
                }
            }
            
            // Process compression
            let processButton = app.buttons["Process"]
            XCTAssertTrue(processButton.exists)
            processButton.tap()
            
            // Verify processing
            XCTAssertTrue(app.progressIndicators.firstMatch.waitForExistence(timeout: 2))
            
            // Wait for result with size comparison
            let successText = app.staticTexts["Success"]
            XCTAssertTrue(successText.waitForExistence(timeout: 15)) // Compression can take time
            
            // Verify size reduction info
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'MB'")).count > 0)
        }
    }
    
    // MARK: - Additional Core Flow Tests
    
    func testPaywallAppearanceAfterThreeExports() throws {
        // This test would simulate using up the free tier
        // and verify paywall appears correctly
        
        // Perform 3 quick exports
        for i in 1...3 {
            // Navigate to a simple tool
            let resizeImagesCard = app.buttons["Resize Images"]
            if resizeImagesCard.waitForExistence(timeout: 2) {
                resizeImagesCard.tap()
                
                // Quick process simulation
                let selectButton = app.buttons["Select Files"]
                if selectButton.waitForExistence(timeout: 2) {
                    selectButton.tap()
                }
                
                let processButton = app.buttons["Process"]
                if processButton.waitForExistence(timeout: 3) {
                    processButton.tap()
                }
                
                // Wait for success and go back
                let successText = app.staticTexts["Success"]
                if successText.waitForExistence(timeout: 5) {
                    // Navigate back to home
                    app.navigationBars.buttons.element(boundBy: 0).tap()
                }
            }
        }
        
        // Fourth attempt should show paywall
        let imagesToPDFCard = app.buttons["Images → PDF"]
        if imagesToPDFCard.waitForExistence(timeout: 2) {
            imagesToPDFCard.tap()
            
            // Verify paywall appears
            let paywallTitle = app.staticTexts["Upgrade to Pro"]
            XCTAssertTrue(paywallTitle.waitForExistence(timeout: 5))
            
            // Verify subscription options
            XCTAssertTrue(app.buttons["Pro Monthly"].exists)
            XCTAssertTrue(app.buttons["Pro Yearly"].exists)
            XCTAssertTrue(app.buttons["Pro Lifetime"].exists)
        }
    }
    
    func testNavigationBetweenTabs() throws {
        // Test tab navigation
        let homeTab = app.tabBars.buttons["Toolbox"]
        let recentsTab = app.tabBars.buttons["Recents"]
        let settingsTab = app.tabBars.buttons["Settings"]
        
        // Start on home
        XCTAssertTrue(homeTab.isSelected)
        
        // Navigate to recents
        recentsTab.tap()
        XCTAssertTrue(recentsTab.isSelected)
        XCTAssertTrue(app.navigationBars["Recents"].exists ||
                     app.staticTexts["Recents"].exists)
        
        // Navigate to settings
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected)
        XCTAssertTrue(app.navigationBars["Settings"].exists ||
                     app.staticTexts["Settings"].exists)
        
        // Back to home
        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected)
    }
    
    func testSearchFunctionality() throws {
        // Test on-device search
        let searchField = app.searchFields.firstMatch
        
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("PDF")
            
            // Verify search results appear
            let searchResults = app.cells.matching(identifier: "SearchResult")
            let pdfTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'PDF'"))
            XCTAssertTrue(searchResults.count > 0 ||
                         pdfTexts.count > 1) // At least one result
            
            // Clear search
            if app.buttons["Clear"].exists {
                app.buttons["Clear"].tap()
            } else {
                searchField.buttons.firstMatch.tap() // Clear button in search field
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testVoiceOverLabels() throws {
        // Enable accessibility testing
        let homeButton = app.buttons["Images → PDF"]
        
        if homeButton.waitForExistence(timeout: 3) {
            // Verify accessibility label
            XCTAssertEqual(homeButton.label, "Images to PDF. Convert photos to PDF")
            
            // Test other important elements
            let recentsTab = app.tabBars.buttons["Recents"]
            XCTAssertTrue(recentsTab.isAccessibilityElement)
            
            // Verify security badge has accessibility
            let securityBadge = app.otherElements["SecurityBadge"]
            if securityBadge.exists {
                XCTAssertTrue(securityBadge.isAccessibilityElement)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(iOS 15.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

// MARK: - UI Test Helpers

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and type text into a non string value")
            return
        }
        
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}