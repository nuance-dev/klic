import Foundation
import Combine
import SwiftUI

class InputManager: ObservableObject {
    @Published var keyboardEvents: [InputEvent] = []
    @Published var mouseEvents: [InputEvent] = []
    @Published var allEvents: [InputEvent] = []
    
    // Properties to control visibility and active input types
    @Published var isOverlayVisible: Bool = false
    @Published var overlayOpacity: Double = 0.0
    @Published var activeInputTypes: Set<InputType> = []
    
    // Add publishing of input visibility preferences  
    @Published var showKeyboardInput: Bool = true
    @Published var showMouseInput: Bool = true
    
    // Maximum events to keep per input type
    private let maxKeyboardEvents = 6
    private let maxMouseEvents = 3
    
    private let keyboardMonitor = KeyboardMonitor()
    private let mouseMonitor = MouseMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    // Timer for auto-hiding the overlay
    private var visibilityTimer: Timer?
    private var eventTimers: [String: Timer] = [:]
    private var fadeOutDelay: TimeInterval = 1.5  // Shorter delay for better UX
    private let fadeInDuration: TimeInterval = 0.2
    private let fadeOutDuration: TimeInterval = 0.3
    
    // Smart filtering settings
    private var lastKeyPressTime: Date = Date.distantPast
    private var keyPressFrequency: TimeInterval = 0.5 // Adjusted based on typing speed
    private let keyPressThreshold: Int = 3 // Number of keypresses to consider "typing"
    private var consecutiveKeyPresses: Int = 0
    
    // Enum to track active input types
    enum InputType: Int, CaseIterable {
        case keyboard
        case mouse
    }
    
    // New property for managing user preference vs. actual opacity
    private var userOpacityPreference: Double = 0.9
    
    init() {
        Logger.info("Initializing InputManager", log: Logger.app)
        
        // Initialize visibility preferences from user defaults
        self.showKeyboardInput = UserPreferences.getShowKeyboardInput()
        self.showMouseInput = UserPreferences.getShowMouseInput()
        
        setupSubscriptions()
        
        // Listen for input type changes
        NotificationCenter.default.addObserver(
            forName: .InputTypesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Update visibility settings from user defaults
            self.showKeyboardInput = UserPreferences.getShowKeyboardInput()
            self.showMouseInput = UserPreferences.getShowMouseInput()
            
            // Clear events for disabled input types
            if !self.showKeyboardInput {
                self.keyboardEvents = []
                self.updateActiveInputTypes(adding: .keyboard, removing: true)
            }
            
            if !self.showMouseInput {
                self.mouseEvents = []
                self.updateActiveInputTypes(adding: .mouse, removing: true)
            }
            
            self.updateAllEvents()
        }
    }
    
    private func setupSubscriptions() {
        // Subscribe to keyboard events
        keyboardMonitor.$currentEvents
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] events in
                guard let self = self else { return }
                
                // Only process keyboard events if keyboard input is enabled
                if self.showKeyboardInput && !events.isEmpty {
                    // Filter repeat events when typing fast to avoid clutter
                    let filteredEvents = self.filterRepeatKeyEvents(events)
                    
                    // Clean up any duplicate events that might have slipped through
                    let uniqueEvents = self.removeDuplicateEvents(filteredEvents)
                    
                    self.keyboardEvents = Array(uniqueEvents.prefix(self.maxKeyboardEvents))
                    self.updateActiveInputTypes(adding: .keyboard, removing: events.isEmpty)
                    self.updateAllEvents()
                    self.showOverlay()
                    
                    // Set a timer to clear this event type
                    self.scheduleClearEventTimer(for: .keyboard)
                    
                    Logger.debug("Received \(events.count) keyboard events", log: Logger.app)
                } else if !self.showKeyboardInput && !self.keyboardEvents.isEmpty {
                    // Clear keyboard events if keyboard input is disabled
                    self.keyboardEvents = []
                    self.updateActiveInputTypes(adding: .keyboard, removing: true)
                    self.updateAllEvents()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to mouse events
        mouseMonitor.$currentEvents
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] events in
                guard let self = self else { return }
                if self.showMouseInput && !events.isEmpty {
                    self.mouseEvents = Array(events.prefix(self.maxMouseEvents))
                    self.updateActiveInputTypes(adding: .mouse, removing: events.isEmpty)
                    self.updateAllEvents()
                    self.showOverlay()
                    
                    // Set a timer to clear this event type
                    self.scheduleClearEventTimer(for: .mouse)
                    
                    Logger.debug("Received \(events.count) mouse events", log: Logger.app)
                } else if !self.showMouseInput && !self.mouseEvents.isEmpty {
                    // Clear mouse events if mouse input is disabled
                    self.mouseEvents = []
                    self.updateActiveInputTypes(adding: .mouse, removing: true)
                    self.updateAllEvents()
                }
            }
            .store(in: &cancellables)
    }
    
    // Update the active input types set
    private func updateActiveInputTypes(adding type: InputType, removing: Bool = false) {
        if removing {
            activeInputTypes.remove(type)
            Logger.debug("Removed input type: \(type)", log: Logger.app)
        } else {
            activeInputTypes.insert(type)
            Logger.debug("Added input type: \(type)", log: Logger.app)
        }
    }
    
    // Clear a specific event type after a delay
    private func scheduleClearEventTimer(for inputType: InputType) {
        // Cancel any existing timer for this input type
        eventTimers["\(inputType)"]?.invalidate()
        
        // Create a new timer to clear events after delay
        eventTimers["\(inputType)"] = Timer.scheduledTimer(withTimeInterval: fadeOutDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                Logger.debug("Timer fired for input type: \(inputType)", log: Logger.app)
                
                switch inputType {
                case .keyboard:
                    if !self.keyboardEvents.isEmpty {
                        self.keyboardEvents = []
                        self.updateActiveInputTypes(adding: .keyboard, removing: true)
                        self.updateAllEvents()
                    }
                case .mouse:
                    if !self.mouseEvents.isEmpty {
                        self.mouseEvents = []
                        self.updateActiveInputTypes(adding: .mouse, removing: true)
                        self.updateAllEvents()
                    }
                }
                
                // If no active input types, hide the overlay
                if self.activeInputTypes.isEmpty {
                    self.hideOverlay()
                }
            }
        }
    }
    
    // Show the overlay with smooth fade-in
    func showOverlay() {
        isOverlayVisible = true
        
        // Use animation for smooth transition
        withAnimation(.easeIn(duration: fadeInDuration)) {
            overlayOpacity = userOpacityPreference
        }
    }
    
    // Hide the overlay with smooth fade-out
    func hideOverlay() {
        // Use animation for smooth transition
        withAnimation(.easeOut(duration: fadeOutDuration)) {
            overlayOpacity = 0.0
        }
        
        // Schedule setting isOverlayVisible to false after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration + 0.05) { [weak self] in
            guard let self = self else { return }
            if self.overlayOpacity == 0.0 {
                self.isOverlayVisible = false
            }
        }
    }
    
    // Filter repeated keyboard events during fast typing
    private func filterRepeatKeyEvents(_ events: [InputEvent]) -> [InputEvent] {
        let now = Date()
        let timeSinceLastPress = now.timeIntervalSince(lastKeyPressTime)
        
        // Adjust key press frequency based on typing speed
        if timeSinceLastPress < 0.2 {
            consecutiveKeyPresses += 1
            if consecutiveKeyPresses > keyPressThreshold {
                // Fast typing detected, reduce keyPressFrequency
                keyPressFrequency = max(0.05, keyPressFrequency * 0.9)
            }
        } else {
            // Reset consecutive count if not typing fast
            consecutiveKeyPresses = 0
            // Gradually restore normal keyPressFrequency
            keyPressFrequency = min(0.5, keyPressFrequency * 1.1)
        }
        
        lastKeyPressTime = now
        
        // Apply filtering based on calculated frequency and input types
        return events.filter { event in
            // Keep non-keyboard events
            if event.type != .keyboard {
                return true
            }
            
            // Keep special keys like modifiers always
            if let keyEvent = event.keyboardEvent, keyEvent.isModifierKey {
                return true
            }
            
            // Apply time-based filtering for normal keys during fast typing
            return true
        }
    }
    
    // Remove duplicate events to prevent clutter
    private func removeDuplicateEvents(_ events: [InputEvent]) -> [InputEvent] {
        var uniqueEvents: [InputEvent] = []
        var seenKeys = Set<String>()
        
        for event in events {
            // Create a unique identifier for the event
            let key = "\(event.id)"
            if !seenKeys.contains(key) {
                uniqueEvents.append(event)
                seenKeys.insert(key)
            }
        }
        
        return uniqueEvents
    }
    
    // Update the consolidated event list for rendering
    private func updateAllEvents() {
        allEvents = keyboardEvents + mouseEvents
    }
    
    // Public methods for controlling the overlay
    
    // Manually show the overlay (e.g., from menu command)
    func showOverlayManually() {
        Logger.info("Manually showing overlay", log: Logger.app)
        showOverlay()
    }
    
    // Start all monitors
    func startMonitoring() {
        Logger.info("Starting all input monitors", log: Logger.app)
        keyboardMonitor.startMonitoring()
        mouseMonitor.startMonitoring()
    }
    
    // Stop all monitors
    func stopMonitoring() {
        Logger.info("Stopping all input monitors", log: Logger.app)
        keyboardMonitor.stopMonitoring()
        mouseMonitor.stopMonitoring()
    }
    
    // Update opacity from user preference
    func updateOpacity(_ newOpacity: Double) {
        userOpacityPreference = newOpacity
        
        // If overlay is visible, update its opacity immediately
        if isOverlayVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                overlayOpacity = newOpacity
            }
        }
    }
    
    // Show demo mode with example inputs
    func showDemoMode() {
        Logger.info("Showing demo mode", log: Logger.app)
        
        // Stop monitoring to prevent real events from interfering
        stopMonitoring()
        
        // Clear any existing events
        keyboardEvents = []
        mouseEvents = []
        
        // Create welcome message using keyboard events - now "READY" instead of "WELCOME"
        let rKey = KeyboardEvent(
            key: "R",
            keyCode: 15,
            isDown: true,
            modifiers: [],
            characters: "R",
            isRepeat: false
        )
        
        let eKey = KeyboardEvent(
            key: "E",
            keyCode: 14,
            isDown: true,
            modifiers: [],
            characters: "E",
            isRepeat: false
        )
        
        let aKey = KeyboardEvent(
            key: "A",
            keyCode: 0,
            isDown: true,
            modifiers: [],
            characters: "A",
            isRepeat: false
        )
        
        let dKey = KeyboardEvent(
            key: "D",
            keyCode: 2,
            isDown: true,
            modifiers: [],
            characters: "D",
            isRepeat: false
        )
        
        let yKey = KeyboardEvent(
            key: "Y",
            keyCode: 16,
            isDown: true,
            modifiers: [],
            characters: "Y",
            isRepeat: false
        )
        
        // Create a keyboard shortcut demo
        let cmdKey = KeyboardEvent(
            key: "Command",
            keyCode: 55,
            isDown: true,
            modifiers: [.command],
            characters: "⌘",
            isRepeat: false
        )
        
        let shiftKey = KeyboardEvent(
            key: "Shift",
            keyCode: 56,
            isDown: true,
            modifiers: [.shift],
            characters: "⇧",
            isRepeat: false
        )
        
        let sKey = KeyboardEvent(
            key: "S",
            keyCode: 1,
            isDown: true,
            modifiers: [.command, .shift],
            characters: "S",
            isRepeat: false
        )
        
        // Create some mouse demo events
        let leftClick = MouseEvent(
            position: CGPoint(x: 400, y: 300),
            button: .left,
            scrollDelta: nil,
            isDown: true,
            isDoubleClick: false
        )
        
        let rightClick = MouseEvent(
            position: CGPoint(x: 500, y: 300),
            button: .right,
            scrollDelta: nil,
            isDown: true,
            isDoubleClick: false
        )
        
        // Immediately ensure overlay is visible
        isOverlayVisible = true
        showOverlay()
        
        // Show the READY message first
        keyboardEvents = [
            InputEvent.keyboardEvent(event: rKey),
            InputEvent.keyboardEvent(event: eKey),
            InputEvent.keyboardEvent(event: aKey),
            InputEvent.keyboardEvent(event: dKey),
            InputEvent.keyboardEvent(event: yKey)
        ]
        
        // Update active input types
        activeInputTypes.insert(.keyboard)
        
        // Update the all events array
        updateAllEvents()
        
        // Cancel all timers first to ensure demo stays visible
        cancelAllEventTimers()
        
        // After a delay, show keyboard shortcut
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.keyboardEvents = [
                InputEvent.keyboardEvent(event: cmdKey),
                InputEvent.keyboardEvent(event: shiftKey),
                InputEvent.keyboardEvent(event: sKey)
            ]
            self.updateAllEvents()
        }
        
        // After another delay, show mouse events
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.mouseEvents = [
                InputEvent.mouseEvent(event: leftClick),
                InputEvent.mouseEvent(event: rightClick)
            ]
            self.activeInputTypes.insert(.mouse)
            self.updateAllEvents()
        }
        
        // Schedule hiding after a longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            // Clear events gradually
            self.mouseEvents = []
            self.updateActiveInputTypes(adding: .mouse, removing: true)
            self.updateAllEvents()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.keyboardEvents = []
                self.updateActiveInputTypes(adding: .keyboard, removing: true)
                self.updateAllEvents()
                self.hideOverlay()
                
                // Restart monitoring after demo is done
                self.startMonitoring()
            }
        }
    }
    
    // Cancel all event timers to prevent premature hiding
    private func cancelAllEventTimers() {
        for (_, timer) in eventTimers {
            timer.invalidate()
        }
        eventTimers.removeAll()
        
        if let visibilityTimer = visibilityTimer {
            visibilityTimer.invalidate()
            self.visibilityTimer = nil
        }
    }
    
    // Set input type visibility
    func setInputTypeVisibility(keyboard: Bool, mouse: Bool) {
        // Store visibility preferences in UserDefaults
        UserPreferences.setShowKeyboardInput(keyboard)
        UserPreferences.setShowMouseInput(mouse)
        
        // Update published properties
        self.showKeyboardInput = keyboard
        self.showMouseInput = mouse
        
        // Update active input types based on visibility settings
        if !keyboard {
            activeInputTypes.remove(.keyboard)
            keyboardEvents = []
        }
        
        if !mouse {
            activeInputTypes.remove(.mouse)
            mouseEvents = []
        }
        
        // Update all events
        updateAllEvents()
        
        // Hide overlay if no input types are visible
        if activeInputTypes.isEmpty {
            hideOverlay()
        }
    }
    
    // Set auto-hide delay
    func setAutoHideDelay(_ delay: Double) {
        fadeOutDelay = delay
    }
    
    // Add a method to check monitoring status
    func checkMonitoringStatus() -> Bool {
        return keyboardMonitor.isMonitoring && mouseMonitor.isMonitoring
    }
    
    // Add a method to restart monitoring
    func restartMonitoring() {
        Logger.info("Restarting all input monitors", log: Logger.app)
        stopMonitoring()
        startMonitoring()
    }
    
    // Clear all events
    func clearAllEvents() {
        Logger.info("Clearing all events", log: Logger.app)
        keyboardEvents = []
        mouseEvents = []
        updateAllEvents()
    }
    
    // Show demo inputs
    func showDemoInputs() {
        Logger.info("Showing demo inputs", log: Logger.app)
        showDemoMode()
    }
    
    // Set the opacity preference
    func setOpacityPreference(_ opacity: Double) {
        Logger.info("Setting opacity preference to \(opacity)", log: Logger.app)
        userOpacityPreference = opacity
        updateOpacity(opacity)
    }
    
    private func shouldKeepEvent(_ event: InputEvent) -> Bool {
        // Keep recent events from the last fadeOutDelay seconds
        let currentTime = Date()
        let eventAge = currentTime.timeIntervalSince(event.timestamp)
        
        if eventAge <= fadeOutDelay {
            // For key events, apply smart filtering
            if event.type == .keyboard {
                // Keep modifiers and special keys
                if let keyEvent = event.keyboardEvent, keyEvent.isModifierKey {
                    return true
                }
            }
            
            // Apply time-based filtering for normal keys during fast typing
            return true
        }
        
        // Keep special keys like modifiers always
        if let keyEvent = event.keyboardEvent, keyEvent.isModifierKey {
            return true
        }
        
        // Apply time-based filtering for normal keys during fast typing
        return true
    }
} 