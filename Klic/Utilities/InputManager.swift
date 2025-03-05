import Foundation
import Combine
import SwiftUI

class InputManager: ObservableObject, TrackpadMonitorDelegate {
    @Published var keyboardEvents: [InputEvent] = []
    @Published var mouseEvents: [InputEvent] = []
    @Published var trackpadEvents: [InputEvent] = []
    @Published var allEvents: [InputEvent] = []
    
    // Properties to control visibility and active input types
    @Published var isOverlayVisible: Bool = false
    @Published var overlayOpacity: Double = 0.0
    @Published var activeInputTypes: Set<InputType> = []
    
    // Maximum events to keep per input type
    private let maxKeyboardEvents = 6
    private let maxMouseEvents = 3
    private let maxTrackpadTouches = 3
    
    private let keyboardMonitor = KeyboardMonitor()
    private let mouseMonitor = MouseMonitor()
    private let trackpadMonitor = TrackpadMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    // Access to the trackpad monitor for touch visualization
    var sharedTrackpadMonitor: TrackpadMonitor {
        return trackpadMonitor
    }
    
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
        case trackpad
    }
    
    // New property for managing user preference vs. actual opacity
    private var userOpacityPreference: Double = 0.9
    
    init() {
        Logger.info("Initializing InputManager", log: Logger.app)
        setupSubscriptions()
        
        // Set self as the trackpad monitor delegate
        trackpadMonitor.delegate = self
    }
    
    private func setupSubscriptions() {
        // Subscribe to keyboard events
        keyboardMonitor.$currentEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                if !events.isEmpty {
                    // Filter repeat events when typing fast to avoid clutter
                    let filteredEvents = self.filterRepeatKeyEvents(events)
                    self.keyboardEvents = Array(filteredEvents.prefix(self.maxKeyboardEvents))
                    self.updateActiveInputTypes(adding: .keyboard, removing: events.isEmpty)
                    self.updateAllEvents()
                    self.showOverlay()
                    
                    // Set a timer to clear this event type
                    self.scheduleClearEventTimer(for: .keyboard)
                    
                    Logger.debug("Received \(events.count) keyboard events", log: Logger.app)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to mouse events
        mouseMonitor.$currentEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                if !events.isEmpty {
                    self.mouseEvents = Array(events.prefix(self.maxMouseEvents))
                    self.updateActiveInputTypes(adding: .mouse, removing: events.isEmpty)
                    self.updateAllEvents()
                    self.showOverlay()
                    
                    // Set a timer to clear this event type
                    self.scheduleClearEventTimer(for: .mouse)
                    
                    Logger.debug("Received \(events.count) mouse events", log: Logger.app)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to trackpad events with enhanced touch handling
        trackpadMonitor.$currentEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                if !events.isEmpty {
                    self.trackpadEvents = Array(events.prefix(self.maxTrackpadTouches))
                    self.updateActiveInputTypes(adding: .trackpad, removing: events.isEmpty)
                    self.updateAllEvents()
                    self.showOverlay()
                    
                    // Set a timer to clear this event type
                    self.scheduleClearEventTimer(for: .trackpad)
                    
                    Logger.debug("Received \(events.count) trackpad events", log: Logger.app)
                }
            }
            .store(in: &cancellables)
        
        // Also subscribe to raw touches for enhanced visualization
        trackpadMonitor.$rawTouches
            .receive(on: RunLoop.main)
            .sink { [weak self] touches in
                guard let self = self else { return }
                if !touches.isEmpty {
                    // Only show the overlay if we have actual touches
                    self.updateActiveInputTypes(adding: .trackpad, removing: touches.isEmpty)
                    self.showOverlay()
                    
                    // Set a timer to clear touches
                    self.scheduleClearEventTimer(for: .trackpad)
                }
            }
            .store(in: &cancellables)
        
        Logger.debug("Input subscriptions set up", log: Logger.app)
        
        // Immediately start monitoring
        startAllMonitors()
    }
    
    private func scheduleClearEventTimer(for type: InputType) {
        // Cancel existing timer for this type
        let timerKey = "clear-\(type.rawValue)"
        eventTimers[timerKey]?.invalidate()
        
        // Create new timer
        eventTimers[timerKey] = Timer.scheduledTimer(withTimeInterval: fadeOutDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Clear events for this type
                switch type {
                case .keyboard:
                    self.keyboardEvents = []
                case .mouse:
                    self.mouseEvents = []
                case .trackpad:
                    self.trackpadEvents = []
                }
                
                // Update active types and all events
                self.updateActiveInputTypes(removing: type)
                self.updateAllEvents()
                
                Logger.debug("Auto-cleared events for \(type)", log: Logger.app)
            }
        }
    }
    
    public func startAllMonitors() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.keyboardMonitor.startMonitoring()
            self.mouseMonitor.startMonitoring()
            self.trackpadMonitor.startMonitoring()
            
            Logger.info("All input monitors started", log: Logger.app)
        }
    }
    
    private func filterRepeatKeyEvents(_ events: [InputEvent]) -> [InputEvent] {
        // Track time between keypresses
        let now = Date()
        let timeSinceLastKeyPress = now.timeIntervalSince(lastKeyPressTime)
        lastKeyPressTime = now
        
        // Adjust frequency based on timing between keypresses
        if timeSinceLastKeyPress < 0.1 {
            // Fast typing detected
            consecutiveKeyPresses += 1
            
            // Update typing frequency
            if consecutiveKeyPresses >= keyPressThreshold {
                keyPressFrequency = min(keyPressFrequency, timeSinceLastKeyPress * 1.5)
            }
        } else {
            // Reset counter when typing pauses
            consecutiveKeyPresses = 0
        }
        
        // Implement smart filtering
        if consecutiveKeyPresses >= keyPressThreshold {
            // When typing quickly, only show every other keypress
            var filtered = [InputEvent]()
            for (index, event) in events.enumerated() {
                if index % 2 == 0 || event.type != .keyboard || event.keyboardEvent?.isDown == false {
                    filtered.append(event)
                }
            }
            return filtered
        }
        
        return events
    }
    
    private func updateActiveInputTypes(adding type: InputType? = nil, removing isEmpty: Bool = false) {
        if let type = type, !isEmpty {
            activeInputTypes.insert(type)
        } else if let type = type, isEmpty {
            activeInputTypes.remove(type)
        }
    }
    
    private func updateActiveInputTypes(removing type: InputType) {
        activeInputTypes.remove(type)
        
        // When removing a type, check if any others are active
        if activeInputTypes.isEmpty {
            // Start the hide timer when no input types are active
            hideOverlay()
        }
    }
    
    // This public method will be used by both the internal class and the extensions
    public func updateAllEvents() {
        // Combine all events and sort by timestamp (oldest first for better readability)
        allEvents = (keyboardEvents + mouseEvents + trackpadEvents)
            .sorted { $0.timestamp < $1.timestamp }
        
        // Keep only the most recent events
        if allEvents.count > 15 {
            allEvents = Array(allEvents.suffix(15))
        }
        
        Logger.debug("Updated all events, count: \(allEvents.count)", log: Logger.app)
    }
    
    func requestPermissions() {
        // Request accessibility permissions if needed
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            Logger.error("Accessibility permissions are required for input monitoring", log: Logger.app)
            
            // Show an alert to the user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "Klic needs accessibility permissions to monitor your keyboard and trackpad inputs. Please grant access in System Preferences > Security & Privacy > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            Logger.info("Accessibility permissions granted", log: Logger.app)
            
            // Start all monitors when permissions are granted
            keyboardMonitor.startMonitoring()
            mouseMonitor.startMonitoring()
            trackpadMonitor.startMonitoring()
        }
    }
    
    // MARK: - Overlay Visibility Control
    
    func showOverlay() {
        // Cancel any pending hide timer
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        
        // If already showing, just reset the timer
        if isOverlayVisible {
            // Schedule auto-hide if no inputs are active after the delay
            scheduleAutoHide()
            return
        }
        
        // Start showing the overlay with a fade-in effect
        DispatchQueue.main.async {
            // Fade in the overlay
            withAnimation(.easeIn(duration: self.fadeInDuration)) {
                self.isOverlayVisible = true
                self.overlayOpacity = self.userOpacityPreference
            }
            
            Logger.debug("Overlay shown", log: Logger.app)
            
            // Schedule auto-hide if no inputs are active after the delay
            self.scheduleAutoHide()
        }
    }
    
    private func scheduleAutoHide() {
        // Create a new timer to hide the overlay after the delay
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Only hide if no input types are active
            if self.activeInputTypes.isEmpty {
                self.hideOverlay()
            }
        }
    }
    
    func hideOverlay() {
        // Cancel any existing timer
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        
        // If already hidden, do nothing
        if !isOverlayVisible {
            return
        }
        
        // Hide the overlay with a fade-out effect
        DispatchQueue.main.async {
            // Fade out the overlay
            withAnimation(.easeOut(duration: self.fadeOutDuration)) {
                self.isOverlayVisible = false
                self.overlayOpacity = 0.0
            }
            
            Logger.debug("Overlay hidden", log: Logger.app)
        }
    }
    
    func checkMonitoringStatus() -> Bool {
        return keyboardMonitor.isMonitoring && 
               mouseMonitor.isMonitoring && 
               trackpadMonitor.isMonitoring
    }
    
    func restartMonitoring() {
        // Clear events
        keyboardEvents = []
        mouseEvents = []
        trackpadEvents = []
        allEvents = []
        activeInputTypes = []
        
        // Stop all monitors
        keyboardMonitor.stopMonitoring()
        mouseMonitor.stopMonitoring()
        trackpadMonitor.stopMonitoring()
        
        // Small delay before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Start monitors again
            self.keyboardMonitor.startMonitoring()
            self.mouseMonitor.startMonitoring()
            self.trackpadMonitor.startMonitoring()
            
            Logger.info("Input monitors restarted", log: Logger.app)
        }
    }
    
    func setOpacityPreference(_ value: Double) {
        userOpacityPreference = value
        
        // If overlay is currently visible, update its opacity
        if isOverlayVisible {
            DispatchQueue.main.async {
                self.overlayOpacity = value
            }
        }
    }
    
    func setAutoHideDelay(_ delay: Double) {
        // Update the auto-hide delay
        fadeOutDelay = delay
    }
    
    func setInputTypeVisibility(keyboard: Bool, mouse: Bool, trackpad: Bool) {
        // Store visibility preferences in UserDefaults
        var visibleTypes: [String] = []
        
        if keyboard { visibleTypes.append("keyboard") }
        if mouse { visibleTypes.append("mouse") }
        if trackpad { visibleTypes.append("trackpad") }
        
        UserDefaults.standard.set(visibleTypes, forKey: "visibleInputTypes")
    }
    
    func clearAllEvents() {
        DispatchQueue.main.async {
            self.keyboardEvents.removeAll()
            self.mouseEvents.removeAll()
            self.trackpadEvents.removeAll()
            self.allEvents.removeAll()
            self.activeInputTypes.removeAll()
            
            // Hide the overlay if it's visible
            if self.isOverlayVisible {
                self.hideOverlay()
            }
            
            Logger.debug("All input events cleared", log: Logger.app)
        }
    }
    
    // Show demo inputs for demonstration purposes
    func showDemoInputs() {
        // Clear any existing events
        clearAllEvents()
        
        // Get current timestamp
        let now = Date()
        
        // Create demo keyboard events with sequential timestamps
        let keyboardEvents: [InputEvent] = [
            InputEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-0.3),
                type: .keyboard,
                keyboardEvent: KeyboardEvent(
                    key: "⌘", 
                    keyCode: 55, 
                    isDown: true, 
                    modifiers: [.command], 
                    characters: "⌘",
                    isRepeat: false
                ),
                mouseEvent: nil,
                trackpadGesture: nil,
                trackpadTouches: nil
            ),
            InputEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-0.2),
                type: .keyboard,
                keyboardEvent: KeyboardEvent(
                    key: "⇧", 
                    keyCode: 56, 
                    isDown: true, 
                    modifiers: [.shift], 
                    characters: "⇧",
                    isRepeat: false
                ),
                mouseEvent: nil,
                trackpadGesture: nil,
                trackpadTouches: nil
            ),
            InputEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(-0.1),
                type: .keyboard,
                keyboardEvent: KeyboardEvent(
                    key: "R", 
                    keyCode: 15, 
                    isDown: true, 
                    modifiers: [.command, .shift], 
                    characters: "R",
                    isRepeat: false
                ),
                mouseEvent: nil,
                trackpadGesture: nil,
                trackpadTouches: nil
            )
        ]
        
        // Create demo mouse events
        let mouseEvents: [InputEvent] = [
            InputEvent(
                id: UUID(),
                timestamp: now,
                type: .mouse,
                keyboardEvent: nil,
                mouseEvent: MouseEvent(
                    position: CGPoint(x: 0.5, y: 0.5), 
                    button: .left, 
                    scrollDelta: nil,
                    isDown: true
                ),
                trackpadGesture: nil,
                trackpadTouches: nil
            )
        ]
        
        // Create demo trackpad events
        let touch1 = FingerTouch(id: 1, position: CGPoint(x: 0.3, y: 0.5), pressure: 0.8, majorRadius: 10, minorRadius: 10, fingerType: .index, timestamp: now)
        let touch2 = FingerTouch(id: 2, position: CGPoint(x: 0.7, y: 0.5), pressure: 0.8, majorRadius: 10, minorRadius: 10, fingerType: .middle, timestamp: now)
        
        let gesture = TrackpadGesture(
            type: .pinch,
            touches: [touch1, touch2],
            magnitude: 0.8,
            rotation: nil,
            isMomentumScroll: false
        )
        
        let trackpadEvents: [InputEvent] = [
            InputEvent(
                id: UUID(),
                timestamp: now.addingTimeInterval(0.1),
                type: .trackpadGesture,
                keyboardEvent: nil,
                mouseEvent: nil,
                trackpadGesture: gesture,
                trackpadTouches: nil
            )
        ]
        
        // Show each type of input with a delay between them
        DispatchQueue.main.async {
            // First show keyboard
            self.temporarilyAddEvents(events: keyboardEvents, ofType: .keyboard)
            
            // Then show mouse after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.temporarilyAddEvents(events: mouseEvents, ofType: .mouse)
                
                // Finally show trackpad after another delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.temporarilyAddEvents(events: trackpadEvents, ofType: .trackpad)
                }
            }
        }
    }
    
    // MARK: - TrackpadMonitorDelegate Methods
    
    func trackpadMonitorDidDetectGesture(_ gesture: TrackpadGesture) {
        // Create an input event from the gesture
        let gestureEvent = InputEvent.trackpadGestureEvent(gesture: gesture)
        
        DispatchQueue.main.async {
            // Add to trackpad events
            if self.trackpadEvents.count >= self.maxTrackpadTouches {
                self.trackpadEvents.removeLast()
            }
            self.trackpadEvents.insert(gestureEvent, at: 0)
            
            // Update active types and all events
            self.updateActiveInputTypes(adding: .trackpad)
            self.updateAllEvents()
            self.showOverlay()
            
            // Set a timer to clear this event type
            self.scheduleClearEventTimer(for: .trackpad)
        }
    }
    
    func trackpadTouchesBegan(touches: [FingerTouch]) {
        // Handle new touches
        let touchEvent = InputEvent.trackpadTouchEvent(touches: touches)
        
        DispatchQueue.main.async {
            // Add to trackpad events
            if self.trackpadEvents.count >= self.maxTrackpadTouches {
                self.trackpadEvents.removeLast()
            }
            self.trackpadEvents.insert(touchEvent, at: 0)
            
            // Update active types and all events
            self.updateActiveInputTypes(adding: .trackpad)
            self.updateAllEvents()
            self.showOverlay()
            
            // Set a timer to clear this event type
            self.scheduleClearEventTimer(for: .trackpad)
        }
    }
    
    func trackpadTouchesEnded(touches: [FingerTouch]) {
        // No need to add ended touches to the event list
    }
    
    // Add events of specific type temporarily and show overlay
    func temporarilyAddEvents(events: [InputEvent], ofType type: InputType) {
        DispatchQueue.main.async {
            // Add events based on type - ensure they're properly sorted (oldest first)
            let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
            
            switch type {
            case .keyboard:
                self.keyboardEvents = sortedEvents
                self.activeInputTypes.insert(.keyboard)
            case .trackpad:
                self.trackpadEvents = sortedEvents
                self.activeInputTypes.insert(.trackpad)
            case .mouse:
                self.mouseEvents = sortedEvents
                self.activeInputTypes.insert(.mouse)
            }
            
            // Update all events
            self.updateAllEvents()
            
            // Show the overlay with animation
            withAnimation {
                self.isOverlayVisible = true
                
                // Get the saved opacity preference or use default
                let savedOpacity = UserDefaults.standard.double(forKey: "overlayOpacity")
                self.overlayOpacity = savedOpacity > 0 ? savedOpacity : 0.9
            }
            
            // Set up hide timer after a delay for menu-triggered displays
            let hideDelay: TimeInterval = 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) { [weak self] in
                guard let self = self else { return }
                
                // Only hide this specific input type
                switch type {
                case .keyboard:
                    self.keyboardEvents = []
                case .trackpad:
                    self.trackpadEvents = []
                case .mouse:
                    self.mouseEvents = []
                }
                
                // Remove type from active types
                self.activeInputTypes.remove(type)
                self.updateAllEvents()
                
                // If no active types remain, hide overlay
                if self.activeInputTypes.isEmpty {
                    self.hideOverlay()
                }
            }
        }
    }
} 