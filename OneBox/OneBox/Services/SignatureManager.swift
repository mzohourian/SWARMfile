//
//  SignatureManager.swift
//  OneBox
//
//  Manages signature persistence and retrieval
//

import Foundation
import UIKit

class SignatureManager {
    static let shared = SignatureManager()
    private let userDefaults = UserDefaults.standard
    private let signatureKey = "SavedSignatureData"
    private let signatureTextKey = "SavedSignatureText"
    
    private init() {}
    
    // Save drawn signature image
    func saveSignatureImage(_ data: Data) {
        userDefaults.set(data, forKey: signatureKey)
    }
    
    // Get saved signature image
    func getSavedSignatureImage() -> Data? {
        return userDefaults.data(forKey: signatureKey)
    }
    
    // Save text signature
    func saveSignatureText(_ text: String) {
        userDefaults.set(text, forKey: signatureTextKey)
    }
    
    // Get saved signature text
    func getSavedSignatureText() -> String? {
        return userDefaults.string(forKey: signatureTextKey)
    }
    
    // Get saved signature as SignatureData
    func getSavedSignature() -> SignatureData? {
        if let imageData = getSavedSignatureImage() {
            return .image(imageData)
        } else if let text = getSavedSignatureText(), !text.isEmpty {
            return .text(text)
        }
        return nil
    }
    
    // Clear saved signature
    func clearSavedSignature() {
        userDefaults.removeObject(forKey: signatureKey)
        userDefaults.removeObject(forKey: signatureTextKey)
    }
    
    // Check if signature exists
    func hasSavedSignature() -> Bool {
        return getSavedSignature() != nil
    }
}

