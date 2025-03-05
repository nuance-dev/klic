import Foundation
import Combine
import SwiftUI

class InputManager: ObservableObject {
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
    private let fadeOutDelay: TimeInterval = 1.5  // Shorter delay for better UX
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
    
    init() {
        Logger.info("Initializing InputManager", log: Logger.app)
        setupSubscriptions()
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
    
    private func startAllMonitors() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.keyboardMonitor.startMonitoring()
            self.mouseMonitor.startMonitoring()
            self.trackpadMonitor.startMonitoring()
            
            Logger.info("All input monitors started", log: Logger.app)
        }
    }
    
    private func filterRepeatKeyEvents(_ events: [InputEvent]) -> [InputEvent] {
        // Filter out excessive repeat events when typing fast
        var filteredEvents: [InputEvent] = []
        var lastCharacter: String?
        var repeatCount = 0
        var lastTimestamp = Date.distantPast
        
        for event in events {
            if let keyEvent = event.keyboardEvent, let char = keyEvent.characters {
                // Calculate time since last keypress
                let timeDelta = event.timestamp.timeIntervalSince(lastTimestamp)
                
                // Update typing speed metrics
                if timeDelta < 0.3 {
                    consecutiveKeyPresses += 1
                    // Adjust key press frequency based on typing speed
                    if consecutiveKeyPresses > keyPressThreshold {
                        keyPressFrequency = min(0.3, max(0.1, timeDelta * 2))
                    }
                } else {
                    consecutiveKeyPresses = 0
                }
                
                if char == lastCharacter && keyEvent.isRepeat {
                    // Count repeats of the same character
                    repeatCount += 1
                    if repeatCount <= 1 { // Only keep at most 2 repeats (original + 1 repeat)
                        filteredEvents.append(event)
                    }
                } else if timeDelta < keyPressFrequency && filteredEvents.count >= maxKeyboardEvents - 1 {
                    // If typing very fast and we already have many keys, skip some to avoid cluttering the display
                    // But still track the character for repeat detection
                    lastCharacter = char
                    lastTimestamp = event.timestamp
                } else {
                    // New character, add it and reset repeat count
                    repeatCount = 0
                    lastCharacter = char
                    lastTimestamp = event.timestamp
                    filteredEvents.append(event)
                }
                
                // Update last key press time
                lastKeyPressTime = event.timestamp
            } else {
                // Non-character event, just add it
                filteredEvents.append(event)
            }
        }
        
        // Limit to maximum number of events
        if filteredEvents.count > maxKeyboardEvents {
            filteredEvents = Array(filteredEvents.prefix(maxKeyboardEvents))
        }
        
        return filteredEvents
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
        // Combine all events and sort by timestamp (newest first)
        allEvents = (keyboardEvents + mouseEvents + trackpadEvents)
            .sorted { $0.timestamp > $1.timestamp }
        
        // Keep only the most recent events
        if allEvents.count > 15 {
            allEvents = Array(allEvents.prefix(15))
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
        
        // Only trigger animation if not already visible
        if !isOverlayVisible {
            withAnimation(.spring(response: fadeInDuration, dampingFraction: 0.8)) {
                isOverlayVisible = true
                overlayOpacity = UserDefaults.standard.double(forKey: "overlayOpacity") > 0 ? 
                                 UserDefaults.standard.double(forKey: "overlayOpacity") : 0.9
            }
            
            Logger.debug("Overlay shown", log: Logger.app)
        } else {
            // Already visible, just update opacity in case it was fading out
            withAnimation(.spring(response: fadeInDuration, dampingFraction: 0.8)) {
                overlayOpacity = UserDefaults.standard.double(forKey: "overlayOpacity") > 0 ? 
                                UserDefaults.standard.double(forKey: "overlayOpacity") : 0.9
            }
        }
        
        // Start hide timer only if no more inputs are coming in
        if activeInputTypes.isEmpty {
            startHideTimer()
        }
    }
    
    private func startHideTimer() {
        // Cancel existing timer
        visibilityTimer?.invalidate()
        
        // Create new timer only if there are no active inputs
        if activeInputTypes.isEmpty {
            visibilityTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDelay, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.hideOverlay()
            }
        }
    }
    
    public func hideOverlay() {
        // Cancel any pending hide timer
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        
        // Only hide if visible
        if isOverlayVisible {
            // First fade out the opacity
            withAnimation(.spring(response: fadeOutDuration, dampingFraction: 0.9)) {
                overlayOpacity = 0
            }
            
            // Then hide the overlay completely after the fade completes
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { [weak self] in
                guard let self = self else { return }
                
                withAnimation(.easeOut(duration: 0.1)) {
                    self.isOverlayVisible = false
                }
                
                Logger.debug("Overlay hidden", log: Logger.app)
            }
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
    
    func setOpacityPreference(_ opacity: Double) {
        // Store the user's opacity preference and update the current opacity if visible
        UserDefaults.standard.set(opacity, forKey: "overlayOpacity")
        
        if isOverlayVisible {
            withAnimation {
                overlayOpacity = opacity
            }
        }
    }
} 