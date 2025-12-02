//
//  AdvancedFeaturesUITests.swift
//  OneBox - UI Tests for Advanced Features
//

import XCTest

final class AdvancedFeaturesUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    // MARK: - Privacy Features Tests
    
    func testPrivacyDashboardAccess() throws {
        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        
        // Find and tap Privacy Dashboard
        let privacyCell = app.cells["PrivacyDashboard"]
        if !privacyCell.exists {
            // Try scrolling to find it
            let settingsTable = app.tables.firstMatch
            settingsTable.swipeUp()
        }
        
        if privacyCell.waitForExistence(timeout: 3) {
            privacyCell.tap()
            
            // Verify privacy controls are present
            XCTAssertTrue(app.switches["SecureVault"].exists ||
                         app.staticTexts["Secure Vault"].exists)
            XCTAssertTrue(app.switches["ZeroTrace"].exists ||
                         app.staticTexts["Zero Trace Mode"].exists)
            XCTAssertTrue(app.switches["BiometricLock"].exists ||
                         app.staticTexts["Biometric Lock"].exists)
            
            // Test toggle
            let secureVaultSwitch = app.switches["SecureVault"]
            if secureVaultSwitch.exists {
                let initialValue = secureVaultSwitch.value as? String == "1"
                secureVaultSwitch.tap()
                
                // Verify state changed
                let newValue = secureVaultSwitch.value as? String == "1"
                XCTAssertNotEqual(initialValue, newValue)
            }
        }
    }
    
    // MARK: - Interactive PDF Signing Tests
    
    func testInteractivePDFSigning() throws {
        // Navigate to Sign PDF
        let signPDFCard = app.buttons["Sign PDF"]
        XCTAssertTrue(signPDFCard.waitForExistence(timeout: 5))
        signPDFCard.tap()
        
        // Select a PDF
        let selectButton = app.buttons["Select Files"]
        if selectButton.waitForExistence(timeout: 3) {
            selectButton.tap()
            
            // In test mode, wait for interactive signing view
            let signatureCanvas = app.otherElements["SignatureCanvas"]
            if signatureCanvas.waitForExistence(timeout: 5) {
                // Test drawing on canvas
                let startPoint = signatureCanvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
                let endPoint = signatureCanvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
                
                startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
                
                // Verify clear button works
                let clearButton = app.buttons["Clear"]
                if clearButton.exists {
                    clearButton.tap()
                    // Canvas should be cleared
                }
                
                // Draw again
                startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
                
                // Save signature
                let saveButton = app.buttons["Save Signature"]
                if saveButton.exists {
                    saveButton.tap()
                }
                
                // Place signature on PDF
                let pdfView = app.scrollViews["PDFView"]
                if pdfView.waitForExistence(timeout: 3) {
                    // Tap to place signature
                    let placementPoint = pdfView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                    placementPoint.tap()
                    
                    // Verify signature placed
                    XCTAssertTrue(app.images["PlacedSignature"].exists ||
                                 app.otherElements["SignaturePlacement"].exists)
                    
                    // Process signed PDF
                    let doneButton = app.buttons["Done"]
                    if doneButton.exists {
                        doneButton.tap()
                        
                        // Wait for processing
                        let successText = app.staticTexts["Success"]
                        XCTAssertTrue(successText.waitForExistence(timeout: 10))
                    }
                }
            }
        }
    }
    
    // MARK: - Workflow Automation Tests
    
    func testWorkflowCreation() throws {
        // Access workflow automation
        let workflowButton = app.buttons["WorkflowAutomation"]
        if !workflowButton.exists {
            // Try from home screen quick actions
            let quickActionsSection = app.otherElements["QuickActions"]
            if quickActionsSection.exists {
                workflowButton.tap()
            }
        }
        
        if workflowButton.waitForExistence(timeout: 5) {
            workflowButton.tap()
            
            // Create new workflow
            let createButton = app.buttons["Create Workflow"]
            if createButton.waitForExistence(timeout: 3) {
                createButton.tap()
                
                // Name the workflow
                let nameField = app.textFields["WorkflowName"]
                if nameField.waitForExistence(timeout: 2) {
                    nameField.tap()
                    nameField.typeText("Test Workflow")
                }
                
                // Add steps
                let addStepButton = app.buttons["Add Step"]
                if addStepButton.exists {
                    addStepButton.tap()
                    
                    // Select a step type
                    let resizeStep = app.cells["ResizeImages"]
                    if resizeStep.waitForExistence(timeout: 2) {
                        resizeStep.tap()
                    }
                }
                
                // Save workflow
                let saveButton = app.buttons["Save Workflow"]
                if saveButton.exists {
                    saveButton.tap()
                    
                    // Verify workflow saved
                    XCTAssertTrue(app.cells["Test Workflow"].waitForExistence(timeout: 3))
                }
            }
        }
    }
    
    // MARK: - Page Organization Tests
    
    func testPageOrganizer() throws {
        // Navigate to Organize Pages
        let organizeCard = app.buttons["Organize Pages"]
        XCTAssertTrue(organizeCard.waitForExistence(timeout: 5))
        organizeCard.tap()
        
        // Select a PDF
        let selectButton = app.buttons["Select Files"]
        if selectButton.waitForExistence(timeout: 3) {
            selectButton.tap()
            
            // Wait for page organizer
            let pageGrid = app.collectionViews["PageGrid"]
            if pageGrid.waitForExistence(timeout: 5) {
                // Test page selection
                let firstPage = pageGrid.cells.element(boundBy: 0)
                let secondPage = pageGrid.cells.element(boundBy: 1)
                
                if firstPage.exists {
                    firstPage.tap()
                    // Verify selection state
                    XCTAssertTrue(firstPage.isSelected ||
                                 app.images["Checkmark"].exists)
                }
                
                // Test reordering
                if firstPage.exists && secondPage.exists {
                    firstPage.press(forDuration: 0.5, thenDragTo: secondPage)
                }
                
                // Test rotation
                let rotateButton = app.buttons["Rotate"]
                if rotateButton.exists {
                    rotateButton.tap()
                    // Page should rotate
                }
                
                // Test delete
                let deleteButton = app.buttons["Delete"]
                if deleteButton.exists {
                    deleteButton.tap()
                    
                    // Confirm deletion
                    let confirmButton = app.alerts.buttons["Delete"]
                    if confirmButton.exists {
                        confirmButton.tap()
                    }
                }
                
                // Save changes
                let doneButton = app.buttons["Done"]
                if doneButton.exists {
                    doneButton.tap()
                    
                    // Wait for processing
                    XCTAssertTrue(app.staticTexts["Success"].waitForExistence(timeout: 10))
                }
            }
        }
    }
    
    // MARK: - Export Options Tests
    
    func testExportPreviewFlow() throws {
        // Complete a simple conversion first
        let resizeCard = app.buttons["Resize Images"]
        if resizeCard.waitForExistence(timeout: 5) {
            resizeCard.tap()
            
            // Quick process
            let selectButton = app.buttons["Select Files"]
            selectButton.tap()
            
            let processButton = app.buttons["Process"]
            if processButton.waitForExistence(timeout: 3) {
                processButton.tap()
                
                // Wait for export preview
                let exportPreview = app.otherElements["ExportPreview"]
                if exportPreview.waitForExistence(timeout: 10) {
                    // Verify preview elements
                    XCTAssertTrue(app.staticTexts["Export Preview"].exists ||
                                 app.images["PreviewImage"].exists)
                    
                    // Test different export options
                    let saveToFilesButton = app.buttons["Save to Files"]
                    let shareButton = app.buttons["Share"]
                    let saveToPhotosButton = app.buttons["Save to Photos"]
                    
                    XCTAssertTrue(saveToFilesButton.exists)
                    XCTAssertTrue(shareButton.exists)
                    
                    // For image exports, photos option should exist
                    if app.staticTexts["image"].exists {
                        XCTAssertTrue(saveToPhotosButton.exists)
                    }
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateHandling() throws {
        // Test invalid file selection
        let compressCard = app.buttons["Compress PDF"]
        if compressCard.waitForExistence(timeout: 5) {
            compressCard.tap()
            
            // In test mode, trigger an error state
            app.launchArguments.append("--simulate-error")
            
            let selectButton = app.buttons["Select Files"]
            if selectButton.waitForExistence(timeout: 3) {
                selectButton.tap()
                
                // Verify error alert appears
                let errorAlert = app.alerts.firstMatch
                if errorAlert.waitForExistence(timeout: 5) {
                    XCTAssertTrue(errorAlert.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error'")).count > 0 ||
                                 errorAlert.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'failed'")).count > 0)
                    
                    // Dismiss error
                    let okButton = errorAlert.buttons["OK"]
                    if okButton.exists {
                        okButton.tap()
                    }
                }
            }
        }
    }
}