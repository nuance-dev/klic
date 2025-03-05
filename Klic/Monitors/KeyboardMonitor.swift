import Foundation
import Cocoa
import Combine

class KeyboardMonitor: ObservableObject {
    @Published var currentEvents: [InputEvent] = []
    @Published var isMonitoring: Bool = false
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let eventSubject = PassthroughSubject<InputEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Add tracking properties to prevent duplicate events
    private var lastProcessedKeyCode: Int = -1
    private var lastProcessedModifiers: [KeyModifier] = []
    private var lastProcessedTime: Date = Date.distantPast
    private let duplicateThreshold: TimeInterval = 0.01 // 10ms threshold to prevent duplicates
    
    // Map of key codes to character representations
    private let keyCodeMap: [Int: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "\r",
        37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "n", 46: "m", 47: ".", 48: "\t", 49: " ", 50: "`",
        51: "\u{7f}", 53: "\u{1b}", 55: "⌘", 56: "⇧", 57: "⇪", 58: "⌥",
        59: "⌃", 60: "⇧", 61: "⌥", 62: "⌃", 63: "fn",
        65: ".", 67: "*", 69: "+", 71: "⌧", 75: "/", 76: "⏎", 78: "-",
        81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5",
        88: "6", 89: "7", 91: "8", 92: "9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        114: "⇞", 115: "⇟", 116: "↖", 117: "↘", 118: "⌦", 119: "F4", 120: "F2",
        121: "F1", 122: "F3", 123: "↓", 124: "→", 125: "↑", 126: "←"
    ]
    
    init() {
        setupSubscription()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func setupSubscription() {
        // Subscribe to keyboard events and update current events
        eventSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                // Add the new event to the top of the list
                self?.currentEvents.insert(event, at: 0)
                
                // Limit the number of events to 10
                if let count = self?.currentEvents.count, count > 10 {
                    self?.currentEvents.removeLast(count - 10)
                }
            }
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        Logger.info("Starting keyboard monitoring", log: Logger.keyboard)
        
        // If already monitoring, stop first
        if isMonitoring {
            stopMonitoring()
        }
        
        // Create an event tap to monitor keyboard events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // Get the keyboard monitor instance from refcon
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let keyboardMonitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                keyboardMonitor.handleCGEvent(type: type, event: event)
                
                // Pass the event through
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.error("Failed to create event tap for keyboard monitoring", log: Logger.keyboard)
            return
        }
        
        self.eventTap = eventTap
        
        // Create a run loop source and add it to the main run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isMonitoring = true
        Logger.info("Keyboard monitoring started", log: Logger.keyboard)
        
        // Send a test event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendTestEvent()
        }
    }
    
    func stopMonitoring() {
        Logger.info("Stopping keyboard monitoring", log: Logger.keyboard)
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        
        currentEvents.removeAll()
    }
    
    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        var modifiers: [KeyModifier] = []
        if flags.contains(.maskCommand) { modifiers.append(.command) }
        if flags.contains(.maskShift) { modifiers.append(.shift) }
        if flags.contains(.maskAlternate) { modifiers.append(.option) }
        if flags.contains(.maskControl) { modifiers.append(.control) }
        if flags.contains(.maskSecondaryFn) { modifiers.append(.function) }
        if flags.contains(.maskAlphaShift) { modifiers.append(.capsLock) }
        
        let characters = keyCodeToString(keyCode)
        let isRepeat = type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) == 1
        
        let isDown = type == .keyDown
        
        let currentTime = Date()
        
        // Check for duplicate events
        let isDuplicate = (keyCode == lastProcessedKeyCode) && 
                         (modifiers == lastProcessedModifiers) &&
                         (currentTime.timeIntervalSince(lastProcessedTime) < duplicateThreshold)
        
        if !isDuplicate {
            let inputEvent = InputEvent.keyboardEvent(key: characters, keyCode: keyCode, isDown: isDown, modifiers: modifiers, characters: characters, isRepeat: isRepeat)
            
            Logger.debug("Keyboard event: \(isDown ? "down" : "up") key=\(characters) modifiers=\(modifiers)", log: Logger.keyboard)
            
            eventSubject.send(inputEvent)
            
            // Update last processed values
            lastProcessedKeyCode = keyCode
            lastProcessedModifiers = modifiers
            lastProcessedTime = currentTime
        } else {
            Logger.debug("Ignored duplicate keyboard event for key=\(characters)", log: Logger.keyboard)
        }
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        return keyCodeMap[keyCode] ?? "key\(keyCode)"
    }
    
    private func sendTestEvent() {
        // Create a synthetic test event
        let testEvent = InputEvent.keyboardEvent(key: "Test", keyCode: 0, isDown: true, modifiers: [], characters: "Test", isRepeat: false)
        
        // Log that we're sending a test event
        Logger.debug("Sending keyboard test event", log: Logger.keyboard)
        
        // Send the test event to our subject
        eventSubject.send(testEvent)
        
        // Remove the test event after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.currentEvents.removeAll { 
                if let keyEvent = $0.keyboardEvent {
                    return keyEvent.key == "Test"
                }
                return false
            }
        }
    }
} 