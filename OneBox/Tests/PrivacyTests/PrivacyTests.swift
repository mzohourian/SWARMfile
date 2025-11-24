//
//  PrivacyTests.swift
//  OneBox - Privacy Module Tests
//
//  Tests for privacy and security features
//

import XCTest
@testable import Privacy

final class PrivacyTests: XCTestCase {
    var privacyManager: PrivacyManager!
    
    override func setUp() {
        super.setUp()
        privacyManager = PrivacyManager.shared
    }
    
    override func tearDown() {
        // Reset privacy settings
        privacyManager.enableSecureVault(false)
        privacyManager.enableZeroTrace(false)
        privacyManager.enableBiometricLock(false)
        privacyManager.enableStealthMode(false)
        privacyManager.setComplianceMode(.none)
        super.tearDown()
    }
    
    // MARK: - Privacy Settings Tests
    
    func testSecureVaultToggle() {
        // Given
        XCTAssertFalse(privacyManager.isSecureVaultEnabled)
        
        // When
        privacyManager.enableSecureVault(true)
        
        // Then
        XCTAssertTrue(privacyManager.isSecureVaultEnabled)
    }
    
    func testZeroTraceToggle() {
        // Given
        XCTAssertFalse(privacyManager.isZeroTraceEnabled)
        
        // When
        privacyManager.enableZeroTrace(true)
        
        // Then
        XCTAssertTrue(privacyManager.isZeroTraceEnabled)
    }
    
    func testBiometricLockToggle() {
        // Given
        XCTAssertFalse(privacyManager.isBiometricLockEnabled)
        
        // When
        privacyManager.enableBiometricLock(true)
        
        // Then
        XCTAssertTrue(privacyManager.isBiometricLockEnabled)
    }
    
    func testStealthModeToggle() {
        // Given
        XCTAssertFalse(privacyManager.isStealthModeEnabled)
        
        // When
        privacyManager.enableStealthMode(true)
        
        // Then
        XCTAssertTrue(privacyManager.isStealthModeEnabled)
    }
    
    // MARK: - Compliance Mode Tests
    
    func testComplianceModeNone() {
        // Given
        XCTAssertEqual(privacyManager.selectedComplianceMode, .none)
        
        // When
        privacyManager.setComplianceMode(.none)
        
        // Then
        XCTAssertEqual(privacyManager.selectedComplianceMode, .none)
        XCTAssertFalse(privacyManager.isSecureVaultEnabled)
        XCTAssertFalse(privacyManager.isZeroTraceEnabled)
        XCTAssertFalse(privacyManager.isBiometricLockEnabled)
    }
    
    func testComplianceModeHealthcare() {
        // When
        privacyManager.setComplianceMode(.healthcare)
        
        // Then
        XCTAssertEqual(privacyManager.selectedComplianceMode, .healthcare)
        XCTAssertTrue(privacyManager.isSecureVaultEnabled)
        XCTAssertTrue(privacyManager.isZeroTraceEnabled)
        XCTAssertTrue(privacyManager.isBiometricLockEnabled)
    }
    
    func testComplianceModeFinance() {
        // When
        privacyManager.setComplianceMode(.finance)
        
        // Then
        XCTAssertEqual(privacyManager.selectedComplianceMode, .finance)
        XCTAssertTrue(privacyManager.isSecureVaultEnabled)
        XCTAssertTrue(privacyManager.isZeroTraceEnabled)
        XCTAssertTrue(privacyManager.isBiometricLockEnabled)
        XCTAssertTrue(privacyManager.isStealthModeEnabled)
    }
    
    func testComplianceModeLegal() {
        // When
        privacyManager.setComplianceMode(.legal)
        
        // Then
        XCTAssertEqual(privacyManager.selectedComplianceMode, .legal)
        XCTAssertTrue(privacyManager.isSecureVaultEnabled)
        XCTAssertTrue(privacyManager.isBiometricLockEnabled)
    }
    
    // MARK: - Secure File Management Tests
    
    func testCreateSecureTemporaryURL() {
        // When
        let secureURL = privacyManager.createSecureTemporaryURL()
        
        // Then
        XCTAssertTrue(secureURL.path.contains("SecureVault"))
        XCTAssertTrue(secureURL.pathExtension == "tmp")
    }
    
    func testCleanupSecureFiles() {
        // Given
        let secureURL = privacyManager.createSecureTemporaryURL()
        try? "test data".write(to: secureURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: secureURL.path))
        
        // When
        privacyManager.cleanupSecureFiles()
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: secureURL.path))
    }
    
    // MARK: - Document Sanitization Tests
    
    func testDocumentSanitization() throws {
        // Given
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: tempURL, atomically: true, encoding: .utf8)
        
        // When
        let report = try privacyManager.sanitizeDocument(at: tempURL)
        
        // Then
        XCTAssertEqual(report.originalURL, tempURL)
        XCTAssertTrue(report.metadataRemoved)
        XCTAssertTrue(report.hiddenContentRemoved)
        XCTAssertTrue(report.commentsRemoved)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - File Forensics Tests
    
    func testFileForensicsReportGeneration() throws {
        // Given
        let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent("input.txt")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.txt")
        
        try "input content".write(to: inputURL, atomically: true, encoding: .utf8)
        try "output content".write(to: outputURL, atomically: true, encoding: .utf8)
        
        // When
        let report = privacyManager.generateFileForensics(inputURL: inputURL, outputURL: outputURL)
        
        // Then
        XCTAssertEqual(report.inputURL, inputURL)
        XCTAssertEqual(report.outputURL, outputURL)
        XCTAssertFalse(report.inputHash.isEmpty)
        XCTAssertFalse(report.outputHash.isEmpty)
        XCTAssertNotEqual(report.inputHash, report.outputHash) // Different content = different hashes
        XCTAssertTrue(report.processedOnDevice)
        XCTAssertTrue(report.isValid)
        
        // Cleanup
        try? FileManager.default.removeItem(at: inputURL)
        try? FileManager.default.removeItem(at: outputURL)
    }
    
    // MARK: - Encryption Tests
    
    func testFileEncryption() throws {
        // Given
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("source.txt")
        let testContent = "sensitive content"
        let password = "testPassword123"
        
        try testContent.write(to: sourceURL, atomically: true, encoding: .utf8)
        
        // When
        let encryptedURL = try privacyManager.encryptFile(at: sourceURL, password: password)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedURL.path))
        XCTAssertTrue(encryptedURL.pathExtension == "encrypted")
        
        // Verify content is different (encrypted)
        let encryptedData = try Data(contentsOf: encryptedURL)
        let originalData = testContent.data(using: .utf8)!
        XCTAssertNotEqual(encryptedData, originalData)
        
        // Cleanup
        try? FileManager.default.removeItem(at: sourceURL)
        try? FileManager.default.removeItem(at: encryptedURL)
    }
    
    // MARK: - Audit Trail Tests
    
    func testAuditTrailLogging() {
        // Given
        let initialCount = privacyManager.getAuditTrail().count
        
        // When
        privacyManager.enableSecureVault(true)
        privacyManager.enableZeroTrace(true)
        
        // Then
        let finalCount = privacyManager.getAuditTrail().count
        XCTAssertEqual(finalCount, initialCount + 2)
        
        let latestEntries = privacyManager.getAuditTrail().suffix(2)
        XCTAssertTrue(latestEntries.contains { entry in
            if case .secureVaultToggled(true) = entry.event {
                return true
            }
            return false
        })
        XCTAssertTrue(latestEntries.contains { entry in
            if case .zeroTraceToggled(true) = entry.event {
                return true
            }
            return false
        })
    }
    
    func testAuditTrailClear() {
        // Given
        privacyManager.enableSecureVault(true) // Generate an audit entry
        XCTAssertFalse(privacyManager.getAuditTrail().isEmpty)
        
        // When
        privacyManager.clearAuditTrail()
        
        // Then
        // Should have one entry (the clear operation itself)
        XCTAssertEqual(privacyManager.getAuditTrail().count, 1)
        if case .auditTrailCleared = privacyManager.getAuditTrail().first?.event {
            // Expected
        } else {
            XCTFail("Expected audit trail cleared event")
        }
    }
    
    // MARK: - Compliance Mode Display Names Tests
    
    func testComplianceModeDisplayNames() {
        XCTAssertEqual(ComplianceMode.none.displayName, "Standard")
        XCTAssertEqual(ComplianceMode.healthcare.displayName, "Healthcare (HIPAA)")
        XCTAssertEqual(ComplianceMode.legal.displayName, "Legal")
        XCTAssertEqual(ComplianceMode.finance.displayName, "Finance (SOX)")
    }
    
    // MARK: - Error Handling Tests
    
    func testEncryptionWithEmptyPassword() {
        // Given
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("source.txt")
        try? "test".write(to: sourceURL, atomically: true, encoding: .utf8)
        
        // When/Then
        XCTAssertThrowsError(try privacyManager.encryptFile(at: sourceURL, password: "")) { error in
            if let privacyError = error as? PrivacyError {
                XCTAssertEqual(privacyError, .encryptionFailed)
            }
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: sourceURL)
    }
    
    func testDocumentSanitizationReport() throws {
        // Given
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        try "test pdf content".write(to: tempURL, atomically: true, encoding: .utf8)
        
        // When
        let report = try privacyManager.sanitizeDocument(at: tempURL)
        
        // Then
        XCTAssertFalse(report.summary.isEmpty)
        XCTAssertTrue(report.summary.contains("Removed:") || report.summary.contains("No sensitive data found"))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
}