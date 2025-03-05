import Foundation
import Cocoa
import Combine

class MouseMonitor: ObservableObject {
    @Published var currentEvents: [InputEvent] = []
    @Published var isMonitoring: Bool = false
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cancellables = Set<AnyCancellable>()
    
    // For tracking mouse movement
    private var lastMousePosition: NSPoint = .zero
    private var lastMouseTime: Date = Date()
    private let movementThreshold: CGFloat = 3.0 // Reduced threshold for more responsive movement detection
    
    // For tracking click state
    private var isLeftMouseDown = false
    private var isRightMouseDown = false
    private var lastClickTime: Date = Date.distantPast
    private let doubleClickThreshold: TimeInterval = 0.3
    
    // For debouncing movement events
    private var lastMovementEventTime: Date = Date.distantPast
    private let movementDebounceInterval: TimeInterval = 0.05 // 50ms debounce for smoother visualization
    
    init() {
        Logger.info("Initializing MouseMonitor", log: Logger.mouse)
        setupEventFiltering()
    }
    
    private func setupEventFiltering() {
        // Set up filtering to keep only recent movement events
        $currentEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                
                // Filter movement events
                let movementEvents = events.filter { $0.mouseEvent != nil && $0.type == .mouse }
                
                // If we have too many movement events, remove the oldest ones
                if movementEvents.count > 3 { // Reduced from 5 to 3 for cleaner display
                    // Keep only the most recent movements
                    let toRemove = movementEvents.count - 3
                    self.currentEvents.removeAll { event in
                        event.mouseEvent != nil && event.type == .mouse && 
                        movementEvents.prefix(toRemove).contains { oldEvent in oldEvent.id == event.id }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        Logger.info("Starting mouse monitoring", log: Logger.mouse)
        
        // If already monitoring, stop first
        if isMonitoring {
            stopMonitoring()
        }
        
        // Create an event tap to monitor mouse events
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.leftMouseUp.rawValue) |
                        (1 << CGEventType.rightMouseDown.rawValue) |
                        (1 << CGEventType.rightMouseUp.rawValue) |
                        (1 << CGEventType.mouseMoved.rawValue) |
                        (1 << CGEventType.scrollWheel.rawValue) |
                        (1 << CGEventType.otherMouseDown.rawValue) | // Added for middle button
                        (1 << CGEventType.otherMouseUp.rawValue)     // Added for middle button
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // Get the mouse monitor instance from refcon
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let mouseMonitor = Unmanaged<MouseMonitor>.fromOpaque(refcon).takeUnretainedValue()
                mouseMonitor.handleMouseEvent(type: type, event: event)
                
                // Pass the event through
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.error("Failed to create event tap for mouse monitoring", log: Logger.mouse)
            return
        }
        
        self.eventTap = eventTap
        
        // Create a run loop source and add it to the main run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // Initialize last position
        let mouseLocation = NSEvent.mouseLocation
        lastMousePosition = mouseLocation
        lastMouseTime = Date()
        
        // Reset tracking state
        isLeftMouseDown = false
        isRightMouseDown = false
        
        isMonitoring = true
        Logger.info("Mouse monitoring started", log: Logger.mouse)
    }
    
    func stopMonitoring() {
        Logger.info("Stopping mouse monitoring", log: Logger.mouse)
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        
        Logger.info("Mouse monitoring stopped", log: Logger.mouse)
    }
    
    private func handleMouseEvent(type: CGEventType, event: CGEvent) {
        let timestamp = Date()
        let location = NSEvent.mouseLocation
        
        switch type {
        case .leftMouseDown:
            isLeftMouseDown = true
            
            // Check for double click
            let isDoubleClick = timestamp.timeIntervalSince(lastClickTime) < doubleClickThreshold
            lastClickTime = timestamp
            
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseDown,
                position: location,
                button: .left,
                isDown: true,
                isDoubleClick: isDoubleClick
            )
            DispatchQueue.main.async {
                // Remove any existing left mouse down events to avoid duplicates
                self.currentEvents.removeAll { $0.mouseEvent?.button == .left && $0.type == .mouse }
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Left mouse down at \(location)", log: Logger.mouse)
            
        case .leftMouseUp:
            isLeftMouseDown = false
            
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseUp,
                position: location,
                button: .left,
                isDown: false
            )
            DispatchQueue.main.async {
                // Remove any existing left mouse up events to avoid duplicates
                self.currentEvents.removeAll { $0.mouseEvent?.button == .left && $0.type == .mouse }
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Left mouse up at \(location)", log: Logger.mouse)
            
        case .rightMouseDown:
            isRightMouseDown = true
            
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseDown,
                position: location,
                button: .right,
                isDown: true
            )
            DispatchQueue.main.async {
                // Remove any existing right mouse down events to avoid duplicates
                self.currentEvents.removeAll { $0.mouseEvent?.button == .right && $0.type == .mouse }
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Right mouse down at \(location)", log: Logger.mouse)
            
        case .rightMouseUp:
            isRightMouseDown = false
            
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseUp,
                position: location,
                button: .right,
                isDown: false
            )
            DispatchQueue.main.async {
                // Remove any existing right mouse up events to avoid duplicates
                self.currentEvents.removeAll { $0.mouseEvent?.button == .right && $0.type == .mouse }
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Right mouse up at \(location)", log: Logger.mouse)
            
        case .otherMouseDown:
            // Handle middle button or other mouse buttons
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            
            // Button 2 is typically middle button
            if buttonNumber == 2 {
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseDown,
                    position: location,
                    button: .middle,
                    isDown: true
                )
                DispatchQueue.main.async {
                    self.currentEvents.removeAll { $0.mouseEvent?.button == .middle && $0.type == .mouse }
                    self.currentEvents.append(inputEvent)
                }
                Logger.debug("Middle mouse down at \(location)", log: Logger.mouse)
            } else if buttonNumber == 3 {
                // Extra button 1 (often back button)
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseDown,
                    position: location,
                    button: .extra1,
                    isDown: true
                )
                DispatchQueue.main.async {
                    self.currentEvents.append(inputEvent)
                }
            } else if buttonNumber == 4 {
                // Extra button 2 (often forward button)
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseDown,
                    position: location,
                    button: .extra2,
                    isDown: true
                )
                DispatchQueue.main.async {
                    self.currentEvents.append(inputEvent)
                }
            }
            
        case .otherMouseUp:
            // Handle middle button or other mouse buttons up events
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            
            if buttonNumber == 2 {
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseUp,
                    position: location,
                    button: .middle,
                    isDown: false
                )
                DispatchQueue.main.async {
                    self.currentEvents.removeAll { $0.mouseEvent?.button == .middle && $0.type == .mouse }
                    self.currentEvents.append(inputEvent)
                }
                Logger.debug("Middle mouse up at \(location)", log: Logger.mouse)
            } else if buttonNumber == 3 || buttonNumber == 4 {
                // Extra buttons up events
                let button: MouseButton = buttonNumber == 3 ? .extra1 : .extra2
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseUp,
                    position: location,
                    button: button,
                    isDown: false
                )
                DispatchQueue.main.async {
                    self.currentEvents.append(inputEvent)
                }
            }
            
        case .mouseMoved:
            // Check if we've moved enough to register a new event
            let distance = hypot(location.x - lastMousePosition.x, location.y - lastMousePosition.y)
            let timeDiff = timestamp.timeIntervalSince(lastMouseTime)
            let debounceTimeDiff = timestamp.timeIntervalSince(lastMovementEventTime)
            
            // Only register movement if:
            // 1. We've moved enough distance OR enough time has passed
            // 2. We're outside the debounce interval to prevent flooding
            if (distance > movementThreshold || timeDiff > 0.1) && debounceTimeDiff > movementDebounceInterval {
                // Calculate speed (pixels per second)
                let speed = CGFloat(distance / max(0.001, timeDiff))
                
                // Create movement event
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseMove,
                    position: location,
                    isDown: false
                )
                
                DispatchQueue.main.async {
                    // Remove any existing mouse movement events to distinguish from clicks
                    self.currentEvents.removeAll { event in
                        guard event.type == .mouse, 
                              let mouseEvent = event.mouseEvent,
                              mouseEvent.scrollDelta == nil else {
                            return false
                        }
                        // Check if it's a mouse move event (no button press)
                        return mouseEvent.button == nil && !mouseEvent.isDown
                    }
                    // Add the new movement event
                    self.currentEvents.append(inputEvent)
                }
                
                lastMousePosition = location
                lastMouseTime = timestamp
                lastMovementEventTime = timestamp
                Logger.debug("Mouse moved to \(location) with speed \(speed)", log: Logger.mouse)
            }
            
        case .scrollWheel:
            let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            
            // Check if this is a momentum scroll event
            let phase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            let isMomentum = phase != 0
            
            if abs(deltaY) > 0.1 || abs(deltaX) > 0.1 {
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseScroll,
                    position: location,
                    scrollDelta: CGPoint(x: deltaX, y: deltaY),
                    isDown: false,
                    isMomentumScroll: isMomentum
                )
                DispatchQueue.main.async {
                    // Replace any existing scroll events to avoid clutter
                    self.currentEvents.removeAll { $0.type == .mouse && $0.mouseEvent?.scrollDelta != nil }
                    self.currentEvents.append(inputEvent)
                }
                Logger.debug("Mouse scrolled (deltaY: \(deltaY), deltaX: \(deltaX), momentum: \(isMomentum))", log: Logger.mouse)
            }
            
        default:
            break
        }
    }
} 