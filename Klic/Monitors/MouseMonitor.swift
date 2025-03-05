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
    private let movementThreshold: CGFloat = 5.0 // Minimum pixels to register movement
    
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
                let movementEvents = events.filter { $0.type == .mouseMove }
                
                // If we have too many movement events, remove the oldest ones
                if movementEvents.count > 5 {
                    // Keep only the most recent movements
                    let toRemove = movementEvents.count - 5
                    self.currentEvents.removeAll { event in
                        event.type == .mouseMove && 
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
                        (1 << CGEventType.scrollWheel.rawValue)
        
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
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseDown,
                position: location,
                button: .left
            )
            DispatchQueue.main.async {
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Left mouse down at \(location)", log: Logger.mouse)
            
        case .leftMouseUp:
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseUp,
                position: location,
                button: .left
            )
            DispatchQueue.main.async {
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Left mouse up at \(location)", log: Logger.mouse)
            
        case .rightMouseDown:
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseDown,
                position: location,
                button: .right
            )
            DispatchQueue.main.async {
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Right mouse down at \(location)", log: Logger.mouse)
            
        case .rightMouseUp:
            let inputEvent = InputEvent.mouseEvent(
                type: .mouseUp,
                position: location,
                button: .right
            )
            DispatchQueue.main.async {
                self.currentEvents.append(inputEvent)
            }
            Logger.debug("Right mouse up at \(location)", log: Logger.mouse)
            
        case .mouseMoved:
            // Check if we've moved enough to register a new event
            let distance = hypot(location.x - lastMousePosition.x, location.y - lastMousePosition.y)
            let timeDiff = timestamp.timeIntervalSince(lastMouseTime)
            
            if distance > movementThreshold || timeDiff > 0.1 {
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseMove,
                    position: location,
                    speed: CGFloat(distance / max(0.001, timeDiff))
                )
                DispatchQueue.main.async {
                    self.currentEvents.append(inputEvent)
                }
                
                lastMousePosition = location
                lastMouseTime = timestamp
                Logger.debug("Mouse moved to \(location)", log: Logger.mouse)
            }
            
        case .scrollWheel:
            let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            
            if abs(deltaY) > 0.1 || abs(deltaX) > 0.1 {
                let inputEvent = InputEvent.mouseEvent(
                    type: .mouseScroll,
                    position: location,
                    scrollDelta: CGPoint(x: deltaX, y: deltaY)
                )
                DispatchQueue.main.async {
                    self.currentEvents.append(inputEvent)
                }
                Logger.debug("Mouse scrolled (deltaY: \(deltaY), deltaX: \(deltaX))", log: Logger.mouse)
            }
            
        default:
            break
        }
    }
} 