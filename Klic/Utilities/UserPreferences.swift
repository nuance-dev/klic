import Foundation
import SwiftUI

// Enum for overlay position options is now in KlicApp.swift

struct UserPreferences {
    // Keys for user preferences
    static let overlayPositionKey = "overlayPosition"
    static let overlayOpacityKey = "overlayOpacity"
    static let minimalDisplayModeKey = "minimalDisplayMode"
    
    // Default values
    static let defaultOverlayOpacity: Double = 0.85
    
    // MARK: - Overlay Position
    
    // Get overlay position preference
    static func getOverlayPosition() -> String {
        return UserDefaults.standard.string(forKey: overlayPositionKey) ?? "bottomCenter"
    }
    
    // Set overlay position preference
    static func setOverlayPosition(_ value: String) {
        UserDefaults.standard.set(value, forKey: overlayPositionKey)
        NotificationCenter.default.post(name: .ReconfigureOverlayPosition, object: nil)
    }
    
    // MARK: - Overlay Opacity
    
    // Get overlay opacity preference
    static func getOverlayOpacity() -> Double {
        let value = UserDefaults.standard.double(forKey: overlayOpacityKey)
        return value > 0 ? value : defaultOverlayOpacity
    }
    
    // Set overlay opacity preference
    static func setOverlayOpacity(_ value: Double) {
        UserDefaults.standard.set(value, forKey: overlayOpacityKey)
    }
    
    // MARK: - Minimal Display Mode
    
    // Get minimal display mode preference
    static func getMinimalDisplayMode() -> Bool {
        return UserDefaults.standard.bool(forKey: minimalDisplayModeKey)
    }
    
    // Set minimal display mode preference
    static func setMinimalDisplayMode(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: minimalDisplayModeKey)
        NotificationCenter.default.post(name: .MinimalDisplayModeChanged, object: nil)
    }
    
    // MARK: - Register Default Values
    
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            overlayPositionKey: "bottomCenter",
            overlayOpacityKey: defaultOverlayOpacity,
            minimalDisplayModeKey: false
        ])
    }
} 