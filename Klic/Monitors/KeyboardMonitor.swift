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
    
    // Map of key codes to their display names
    private let keyCodeMap: [Int: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "return",
        37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "n", 46: "m", 47: ".", 48: "tab", 49: "space", 50: "`",
        51: "delete", 53: "escape", 55: "command", 56: "shift", 57: "capslock",
        58: "option", 59: "control", 60: "rightshift", 61: "rightoption",
        62: "rightcontrol", 63: "fn", 64: "f17", 65: ".", 67: "*", 69: "+",
        71: "clear", 72: "volumeup", 73: "volumedown", 74: "mute", 75: "/",
        76: "enter", 78: "-", 79: "f18", 80: "f19", 81: "=", 82: "0",
        83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
        91: "8", 92: "9", 96: "f5", 97: "f6", 98: "f7", 99: "f3",
        100: "f8", 101: "f9", 103: "f11", 105: "f13", 106: "f16", 107: "f14",
        109: "f10", 111: "f12", 113: "f15", 114: "help", 115: "home",
        116: "pageup", 117: "forwarddelete", 118: "f4", 119: "end", 120: "f2",
        121: "pagedown", 122: "f1", 123: "left", 124: "right", 125: "down",
        126: "up", 144: "numlock", 145: "scrolllock", 160: "^", 161: "!",
        162: "\"", 163: "#", 164: "$", 165: "%", 166: "&", 167: "*",
        168: "(", 169: ")", 170: "_", 171: "+", 172: "|", 173: "-",
        174: "{", 175: "}", 176: "~"
    ]
    
    init() {
        setupPublisher()
        // Don't start monitoring in init - wait for explicit call
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func setupPublisher() {
        eventSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                
                // Add the new event
                self.currentEvents.append(event)
                
                // Remove events older than 1.5 seconds
                let cutoffTime = Date().addingTimeInterval(-1.5)
                self.currentEvents.removeAll { $0.timestamp < cutoffTime }
            }
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        // If already monitoring, don't try to start again
        if isMonitoring {
            Logger.debug("Keyboard monitoring already active", log: Logger.keyboard)
            return
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let keyboardMonitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                keyboardMonitor.handleCGEvent(type: type, event: event)
                
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.error("Failed to create keyboard event tap", log: Logger.keyboard)
            isMonitoring = false
            
            // Try to get more specific information about why it failed
            let accessEnabled = AXIsProcessTrustedWithOptions(nil)
            Logger.error("Accessibility permissions status: \(accessEnabled)", log: Logger.keyboard)
            return
        }
        
        self.eventTap = eventTap
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isMonitoring = true
        Logger.info("Keyboard monitoring started", log: Logger.keyboard)
        
        // Send a test event to verify the tap is working
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.sendTestEvent()
        }
    }
    
    func stopMonitoring() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        isMonitoring = false
        Logger.info("Keyboard monitoring stopped", log: Logger.keyboard)
        
        // Clear current events
        currentEvents.removeAll()
    }
    
    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        var modifiers = KeyboardEvent.ModifierKeys()
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        if flags.contains(.maskAlphaShift) { modifiers.insert(.capsLock) }
        
        let characters = keyCodeToString(keyCode)
        let isRepeat = type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) == 1
        
        let eventType: InputEventType = type == .keyDown ? .keyDown : .keyUp
        
        let inputEvent = InputEvent.keyEvent(
            type: eventType,
            keyCode: keyCode,
            characters: characters,
            modifiers: modifiers,
            isRepeat: isRepeat
        )
        
        Logger.debug("Keyboard event: \(eventType) key=\(characters) modifiers=\(modifiers.rawValue)", log: Logger.keyboard)
        
        eventSubject.send(inputEvent)
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        return keyCodeMap[keyCode] ?? "key\(keyCode)"
    }
    
    private func sendTestEvent() {
        // Create a synthetic test event
        let testEvent = InputEvent.keyEvent(
            type: .keyDown,
            keyCode: 0,
            characters: "Test",
            modifiers: [],
            isRepeat: false
        )
        
        // Log that we're sending a test event
        Logger.debug("Sending keyboard test event", log: Logger.keyboard)
        
        // Send the test event to our subject
        eventSubject.send(testEvent)
        
        // Remove the test event after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.currentEvents.removeAll { $0.keyboardEvent?.characters == "Test" }
        }
    }
} 