import Foundation
import Cocoa
import Combine
import os.log

// Add the TrackpadMonitorDelegate protocol
protocol TrackpadMonitorDelegate: AnyObject {
    func trackpadMonitorDidDetectGesture(_ gesture: TrackpadGesture)
    func trackpadTouchesBegan(touches: [FingerTouch])
    func trackpadTouchesEnded(touches: [FingerTouch])
}

class TrackpadMonitor: NSResponder, ObservableObject {
    // MARK: - Types
    
    /// EventPhase enum to represent different phases of a touch event
    enum EventPhase {
        case began
        case moved
        case stationary
        case ended
        case cancelled
        case unknown
    }
    
    // MARK: - Properties
    
    @Published var currentEvents: [InputEvent] = []
    @Published var isMonitoring: Bool = false
    
    // New properties for improved touch handling
    @Published var rawTouches: [NSTouch] = []
    @Published var touchPhases: [Int: Set<NSTouch>] = [:]
    
    // Track touch identities for proper sequence tracking
    private var touchIdentityMap: [String: FingerTouch] = [:]
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let eventSubject = PassthroughSubject<InputEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Track finger touches
    private var currentTouches: [Int: FingerTouch] = [:]
    
    // Trackpad dimensions (will be updated when available)
    private var trackpadBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    // Gesture detection
    private var lastEventTimestamp = Date.distantPast
    private var recentMovements: [CGPoint] = []
    private let recentMovementMaxCount = 5
    
    // Gesture sequence tracking
    private var currentGesturePhase: NSEvent.Phase = NSEvent.Phase(rawValue: 0)
    private var gestureStartTime: Date?
    private var previousGestureType: TrackpadGesture.GestureType?
    
    // Momentum scrolling detection
    private var inMomentumScrolling = false
    private var lastScrollDelta: CGPoint = .zero
    
    // Add the movement threshold property
    private let movementThreshold: CGFloat = 3.0
    
    // Storage for previous touches to compare movement
    private var previousTouches: [FingerTouch] = []
    
    // Add a reference to the previous gesture
    private var previousGesture: TrackpadGesture?
    
    // Delegate to receive gesture events
    weak var delegate: TrackpadMonitorDelegate?
    
    // Add the touchIDCounter for generating unique touch IDs
    private var touchIDCounter: Int = 1
    
    // MARK: - Initialization
    override init() {
        super.init()
        Logger.info("Initializing TrackpadMonitor", log: Logger.trackpad)
        setupTrackpad()
        
        // Don't start monitoring in init - wait for explicit call
        detectTrackpadBounds()
        
        // Set up the responder chain
        NSApp.windows.forEach { window in
            window.contentView?.allowedTouchTypes = [.direct, .indirect]
            window.contentView?.nextResponder = self
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Touch Event Handling
    
    override func touchesBegan(with event: NSEvent) {
        super.touchesBegan(with: event)
        handleTouchesBeganEvent(event)
    }
    
    override func touchesMoved(with event: NSEvent) {
        super.touchesMoved(with: event)
        handleTouchesMovedEvent(event)
    }
    
    override func touchesEnded(with event: NSEvent) {
        super.touchesEnded(with: event)
        handleTouchesEndedEvent(event)
    }
    
    override func touchesCancelled(with event: NSEvent) {
        super.touchesCancelled(with: event)
        handleTouchesCancelledEvent(event)
    }
    
    // MARK: - Touch Event Notification Handlers
    
    private func handleTouchesBeganEvent(_ event: NSEvent) {
        processTouchEvent(event: event)
    }
    
    private func handleTouchesMovedEvent(_ event: NSEvent) {
        processTouchEvent(event: event)
    }
    
    private func handleTouchesEndedEvent(_ event: NSEvent) {
        processTouchEvent(event: event)
    }
    
    private func handleTouchesCancelledEvent(_ event: NSEvent) {
        processTouchEvent(event: event)
    }
    
    private func processTouchEvent(event: NSEvent) {
        // Get touches from the event
        let touches = event.touches(matching: .any, in: nil) 
        
        // Create FingerTouch objects from NSTouch objects
        var fingerTouches: [FingerTouch] = []
        
        for nsTouch in touches {
            // Generate a unique identifier for this touch
            let identityString = "\(UInt(bitPattern: ObjectIdentifier(nsTouch.identity).hashValue))"
            
            // Convert NSTouch phase to our EventPhase
            let phase = convertNSTouchPhaseToEventPhase(nsTouchPhase: nsTouch.phase)
            
            // If touch is ending, send the event and remove from our tracking map
            if phase == .ended || phase == .cancelled {
                if let existingTouch = touchIdentityMap[identityString] {
                    let touches = [existingTouch]
                    delegate?.trackpadTouchesEnded(touches: touches)
                    touchIdentityMap.removeValue(forKey: identityString)
                }
                continue
            }
            
            // If this is an existing touch, update our records
            if let existingTouch = touchIdentityMap[identityString] {
                fingerTouches.append(existingTouch)
            } else {
                // This is a new touch, create a new FingerTouch
                let fingerTouch = createFingerTouchFromNSTouch(nsTouch: nsTouch)
                touchIdentityMap[identityString] = fingerTouch
                fingerTouches.append(fingerTouch)
            }
        }
        
        // Notify delegate of the touches
        if !fingerTouches.isEmpty {
            delegate?.trackpadTouchesBegan(touches: fingerTouches)
        }
    }
    
    private func createFingerTouchFromNSTouch(nsTouch: NSTouch) -> FingerTouch {
        // Create a FingerTouch from an NSTouch with reasonable defaults
        return FingerTouch(
            id: nextTouchID(),
            position: nsTouch.normalizedPosition, // Use the normalized position directly
            pressure: 1.0, // Default pressure as NSTouch doesn't provide this
            majorRadius: 10.0, // Default radius
            minorRadius: 10.0, // Default radius
            fingerType: .unknown // Default finger type
        )
    }
    
    private func nextTouchID() -> Int {
        let id = touchIDCounter
        touchIDCounter += 1
        return id
    }
    
    // MARK: - Event Processing
    
    private func processGestures(event: NSEvent) {
        // Process different gesture types
        switch event.type {
        case .gesture:
            // Handle gesture events based on event type
            let eventType = event.type.rawValue
            if eventType == 29 { // NSEvent.EventType.gesture.rawValue
                // Pinch gesture (zoom)
                detectPinchGesture(event: event)
            } else if eventType == 30 { // NSEvent.EventType.magnify.rawValue
                // Rotation gesture
                detectRotationGesture(event: event)
            } else if eventType == 31 { // NSEvent.EventType.swipe.rawValue
                // Swipe gesture
                detectSwipeGesture(event: event)
            } else if eventType == 34 { // NSEvent.EventType.pressure.rawValue
                // Pressure gesture (Force Touch)
                detectPressureGesture(event: event)
            }
        case .magnify:
            detectPinchGesture(event: event)
        case .swipe:
            detectSwipeGesture(event: event)
        case .pressure:
            detectPressureGesture(event: event)
        case .scrollWheel:
            // Scroll gesture
            processScrollEvent(event: event)
        default:
            break
        }
    }
    
    // MARK: - Gesture Detection
    
    private func detectTapGesture(event: NSEvent, touches: [FingerTouch]) {
        // Simple tap detection
        let gesture = TrackpadGesture(
            type: .tap(count: touches.count),
            touches: touches,
            magnitude: 1.0, // Default magnitude for tap
            rotation: nil,
            isMomentumScroll: false
        )
        
        delegate?.trackpadMonitorDidDetectGesture(gesture)
    }
    
    private func detectSwipeGesture(event: NSEvent) {
        // Get the swipe direction
        var direction: TrackpadGesture.GestureType.SwipeDirection = .right
        
        // Determine swipe direction based on event
        if event.deltaX > 0 {
            direction = .right
        } else if event.deltaX < 0 {
            direction = .left
        } else if event.deltaY > 0 {
            direction = .up
        } else if event.deltaY < 0 {
            direction = .down
        }
        
        // Create the gesture with empty touches array (as we don't have touch info from swipe events)
        let gesture = TrackpadGesture(
            type: .swipe(direction: direction),
            touches: [],
            magnitude: 1.0, // Default magnitude for swipe
            rotation: nil,
            isMomentumScroll: false
        )
        
        delegate?.trackpadMonitorDidDetectGesture(gesture)
    }
    
    private func processScrollEvent(event: NSEvent) {
        Logger.debug("Scroll event detected: \(String(describing: event))", log: Logger.trackpad)
        
        // Determine if this is a momentum scroll
        let isMomentumScroll = event.momentumPhase != []
        
        // Calculate scroll direction and magnitude
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        let magnitude = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // Create empty touches array since scroll events don't have touch data
        let emptyTouches: [FingerTouch] = []
        
        // Create the gesture
        let gesture = TrackpadGesture(
            type: .scroll(fingerCount: event.buttonNumber + 1, deltaX: deltaX, deltaY: deltaY),
            touches: emptyTouches,
            magnitude: magnitude,
            rotation: nil,
            isMomentumScroll: isMomentumScroll
        )
        
        // Notify delegate
        delegate?.trackpadMonitorDidDetectGesture(gesture)
    }
    
    private func detectPinchGesture(event: NSEvent) {
        // Create the gesture
        let gesture = TrackpadGesture(
            type: .pinch,
            touches: [],
            magnitude: CGFloat(event.magnification * 10), // Scale the magnification
            rotation: nil,
            isMomentumScroll: false
        )
        
        delegate?.trackpadMonitorDidDetectGesture(gesture)
    }
    
    private func detectRotationGesture(event: NSEvent) {
        // Create the gesture
        let gesture = TrackpadGesture(
            type: .rotate,
            touches: [],
            magnitude: 1.0, // Default magnitude
            rotation: CGFloat(event.rotation),
            isMomentumScroll: false
        )
        
        delegate?.trackpadMonitorDidDetectGesture(gesture)
    }
    
    private func detectPressureGesture(event: NSEvent) {
        // Handle force touch / pressure gestures if needed
        // This is a placeholder for force touch handling
    }
    
    // MARK: - Setup Methods
    
    private func setupTrackpad() {
        // Enable trackpad gesture events
        NSEvent.addLocalMonitorForEvents(matching: .gesture) { (event) -> NSEvent? in
            self.processGestures(event: event)
            return event
        }
        
        // Enable trackpad touch events
        NSEvent.addLocalMonitorForEvents(matching: [.directTouch, .pressure]) { [weak self] (event) -> NSEvent? in
            guard let self = self else { return event }
            
            // Process touch events
            switch event.type {
            case .directTouch:
                // Direct touch event
                self.processTouchEvent(event: event)
            default:
                break
            }
            
            return event
        }
    }
    
    private func detectTrackpadBounds() {
        // Use screen bounds as a proxy for trackpad bounds initially
        if let screen = NSScreen.main {
            trackpadBounds = CGRect(x: 0, y: 0, width: screen.frame.width, height: screen.frame.height)
            Logger.debug("Using screen bounds as trackpad proxy: \(trackpadBounds)", log: Logger.trackpad)
        } else {
            trackpadBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
            Logger.debug("No screen available, using default trackpad bounds", log: Logger.trackpad)
        }
    }
    
    func startMonitoring() {
        isMonitoring = true
        Logger.info("Trackpad monitoring started", log: Logger.trackpad)
    }
    
    func stopMonitoring() {
        isMonitoring = false
        Logger.info("Trackpad monitoring stopped", log: Logger.trackpad)
    }
    
    // MARK: - Helper Methods
    
    private func allTouches() -> [FingerTouch] {
        return Array(touchIdentityMap.values)
    }
    
    // Add the convertNSTouchPhaseToEventPhase method
    private func convertNSTouchPhaseToEventPhase(nsTouchPhase: NSTouch.Phase) -> EventPhase {
        switch nsTouchPhase {
        case .touching:
            return .began
        case .began:
            return .began
        case .moved:
            return .moved
        case .stationary:
            return .stationary
        case .ended:
            return .ended
        case .cancelled:
            return .cancelled
        default:
            return .unknown
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        Logger.debug("Scroll event detected", log: Logger.trackpad)
        
        if event.phase == .began || event.phase == .changed || event.phase == .ended || event.momentumPhase != [] {
            processScrollEvent(event: event)
        }
    }
}

extension TrackpadGesture.GestureType.SwipeDirection: CustomStringConvertible {
    var description: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
}

// TrackpadGesture is now defined in InputEvent.swift with the isMomentumScroll property
// ... existing code ... 

// Add the extension for NSEvent to get all touches
extension NSEvent {
    func allTouches() -> Set<NSTouch>? {
        return self.touches(matching: .touching, in: nil)
    }
}

// ... existing code ... 