import Foundation
import SwiftUI

// Enum for overlay position options is now in KlicApp.swift

struct UserPreferences {
    // Keys for user preferences
    static let overlayOpacityKey = "overlayOpacity"
    static let minimalDisplayModeKey = "minimalDisplayMode"
    static let showKeyboardInputKey = "showKeyboardInput"
    static let showMouseInputKey = "showMouseInput"
    static let autoHideDelayKey = "autoHideDelay"
    
    // Default values
    static let defaultOverlayOpacity: Double = 0.85
    static let defaultAutoHideDelay: Double = 1.5
    
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
    
    // MARK: - Input Type Settings
    
    // Get keyboard input visibility
    static func getShowKeyboardInput() -> Bool {
        let exists = UserDefaults.standard.object(forKey: showKeyboardInputKey) != nil
        return exists ? UserDefaults.standard.bool(forKey: showKeyboardInputKey) : true
    }
    
    // Set keyboard input visibility
    static func setShowKeyboardInput(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: showKeyboardInputKey)
    }
    
    // Get mouse input visibility
    static func getShowMouseInput() -> Bool {
        let exists = UserDefaults.standard.object(forKey: showMouseInputKey) != nil
        return exists ? UserDefaults.standard.bool(forKey: showMouseInputKey) : true
    }
    
    // Set mouse input visibility
    static func setShowMouseInput(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: showMouseInputKey)
    }
    
    // MARK: - Auto-Hide Delay
    
    // Get auto-hide delay
    static func getAutoHideDelay() -> Double {
        let value = UserDefaults.standard.double(forKey: autoHideDelayKey)
        return value > 0 ? value : defaultAutoHideDelay
    }
    
    // Set auto-hide delay
    static func setAutoHideDelay(_ value: Double) {
        UserDefaults.standard.set(value, forKey: autoHideDelayKey)
    }
    
    // MARK: - Minimal Display Mode
    
    // Get minimal display mode
    static func getMinimalDisplayMode() -> Bool {
        return UserDefaults.standard.bool(forKey: minimalDisplayModeKey)
    }
    
    // Set minimal display mode
    static func setMinimalDisplayMode(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: minimalDisplayModeKey)
        NotificationCenter.default.post(name: .MinimalDisplayModeChanged, object: nil)
    }
    
    // MARK: - Register Default Values
    
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            overlayOpacityKey: defaultOverlayOpacity,
            minimalDisplayModeKey: false,
            showKeyboardInputKey: true,
            showMouseInputKey: true,
            autoHideDelayKey: defaultAutoHideDelay
        ])
    }
} 