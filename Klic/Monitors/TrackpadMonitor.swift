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
    
    // Computed property for active touches
    var activeTouches: [FingerTouch] {
        return touchIdentityMap.values.map { $0 }
    }
    
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
    private var momentumStartTime: Date?
    private var scrollTimeThreshold: TimeInterval = 0.1
    
    // Lower the movement threshold for better gesture detection
    private let movementThreshold: CGFloat = 1.5
    
    // Storage for previous touches to compare movement
    private var previousTouches: [FingerTouch] = []
    
    // Add a reference to the previous gesture
    private var previousGesture: TrackpadGesture?
    
    // Delegate to receive gesture events
    weak var delegate: TrackpadMonitorDelegate?
    
    // Add the touchIDCounter for generating unique touch IDs
    private var touchIDCounter: Int = 1
    
    // Timer for cleaning up stale touches
    private var touchCleanupTimer: Timer?
    
    // Right-click detection
    private var rightClickDetectionTimer: Timer?
    private var potentialRightClickTouches: [NSTouch] = []
    private let rightClickThreshold: TimeInterval = 0.25 // Lower threshold for faster right-click detection
    
    // MARK: - Initialization
    override init() {
        super.init()
        Logger.info("Initializing TrackpadMonitor", log: Logger.trackpad)
        setupTrackpad()
        
        // Don't start monitoring in init - wait for explicit call
        detectTrackpadBounds()
        
        // Set up the responder chain for all windows
        setupResponderChain()
        
        // Configure the touch cleanup timer - runs every 0.5 seconds
        touchCleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.cleanupStaleTouches()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        stopMonitoring()
        touchCleanupTimer?.invalidate()
        rightClickDetectionTimer?.invalidate()
    }
    
    private func setupResponderChain() {
        // Set up the responder chain for all windows
        NSApp.windows.forEach { window in
            // Allow both direct and indirect touches
            window.contentView?.allowedTouchTypes = [.direct, .indirect]
            window.contentView?.nextResponder = self
        }
        
        // Add notification observer for new windows
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow {
                window.contentView?.allowedTouchTypes = [.direct, .indirect]
                window.contentView?.nextResponder = self
            }
        }
    }
    
    // MARK: - Touch Event Handling
    
    override func touchesBegan(with event: NSEvent) {
        super.touchesBegan(with: event)
        
        guard isMonitoring else { return }
        
        if let touches = event.allTouches() {
            processTouchesBeganEvent(touches: touches)
        }
    }
    
    override func touchesMoved(with event: NSEvent) {
        super.touchesMoved(with: event)
        
        guard isMonitoring else { return }
        
        if let touches = event.allTouches() {
            processTouchesMovedEvent(touches: touches)
        }
    }
    
    override func touchesEnded(with event: NSEvent) {
        super.touchesEnded(with: event)
        
        guard isMonitoring else { return }
        
        if let touches = event.allTouches() {
            processTouchesEndedEvent(touches: touches)
        }
    }
    
    override func touchesCancelled(with event: NSEvent) {
        super.touchesCancelled(with: event)
        
        guard isMonitoring else { return }
        
        if let touches = event.allTouches() {
            processTouchesEndedEvent(touches: touches)
        }
    }
    
    private func processTouchesBeganEvent(touches: Set<NSTouch>) {
        // Update raw touches for visualization
        DispatchQueue.main.async {
            self.rawTouches = Array(touches)
        }
        
        // Process new touches
        var newTouches: [FingerTouch] = []
        
        for touch in touches {
            let identity = touch.identity.description
            
            // Only process touches that aren't already being tracked
            if touchIdentityMap[identity] == nil {
                let fingerTouch = createFingerTouchFromNSTouch(nsTouch: touch)
                touchIdentityMap[identity] = fingerTouch
                newTouches.append(fingerTouch)
            }
        }
        
        // If we have exactly two touches that just began, start a timer for right-click detection
        if touches.count == 2 && newTouches.count == 2 {
            potentialRightClickTouches = Array(touches)
            rightClickDetectionTimer?.invalidate()
            rightClickDetectionTimer = Timer.scheduledTimer(withTimeInterval: rightClickThreshold, repeats: false) { [weak self] _ in
                self?.checkForRightClick()
            }
        } else {
            // More than two touches, cancel right-click detection
            rightClickDetectionTimer?.invalidate()
            potentialRightClickTouches.removeAll()
        }
        
        if !newTouches.isEmpty {
            // Notify delegate
            delegate?.trackpadTouchesBegan(touches: newTouches)
            
            // Create and publish event
            let touchEvent = InputEvent.trackpadTouchEvent(touches: newTouches)
            
            DispatchQueue.main.async {
                self.currentEvents.append(touchEvent)
            }
        }
    }
    
    private func processTouchesMovedEvent(touches: Set<NSTouch>) {
        // Update raw touches for visualization
        DispatchQueue.main.async {
            self.rawTouches = Array(touches)
        }
        
        // Process touch movements
        var updatedTouches: [FingerTouch] = []
        
        for touch in touches {
            let identity = touch.identity.description
            
            if var fingerTouch = touchIdentityMap[identity] {
                // Update position
                fingerTouch.position = touch.normalizedPosition
                fingerTouch.pressure = 1.0  // Default pressure since supportsPressure is not available
                fingerTouch.timestamp = Date()
                
                touchIdentityMap[identity] = fingerTouch
                updatedTouches.append(fingerTouch)
            }
        }
        
        // If we have potential right-click touches, check if they've moved too much
        if !potentialRightClickTouches.isEmpty && rightClickDetectionTimer != nil {
            let currentTouches = Array(touches)
            
            // Check if the touches have moved significantly
            var hasMoved = false
            for i in 0..<min(potentialRightClickTouches.count, currentTouches.count) {
                let originalPos = potentialRightClickTouches[i].normalizedPosition
                let currentPos = currentTouches[i].normalizedPosition
                
                let distance = hypot(originalPos.x - currentPos.x, originalPos.y - currentPos.y)
                if distance > 0.02 { // Small threshold for movement
                    hasMoved = true
                    break
                }
            }
            
            if hasMoved {
                // Cancel right-click detection if touches moved too much
                rightClickDetectionTimer?.invalidate()
                rightClickDetectionTimer = nil
                potentialRightClickTouches.removeAll()
            }
        }
        
        // Detect gestures based on touch movements
        if updatedTouches.count >= 2 {
            detectGesture(touches: updatedTouches)
        }
    }
    
    private func processTouchesEndedEvent(touches: Set<NSTouch>) {
        // Find touches that have ended
        var removedIdentities: [String] = []
        
        // First, identify touches that have ended
        for touch in touches {
            let identity = touch.identity.description
            
            if touch.phase == .ended || touch.phase == .cancelled {
                removedIdentities.append(identity)
            }
        }
        
        // Update raw touches for visualization - keep only active touches
        DispatchQueue.main.async {
            self.rawTouches = Array(touches).filter { $0.phase != .ended && $0.phase != .cancelled }
        }
        
        if !removedIdentities.isEmpty {
            var endedTouchList: [FingerTouch] = []
            
            for identity in removedIdentities {
                if let touch = touchIdentityMap[identity] {
                    endedTouchList.append(touch)
                }
                touchIdentityMap.removeValue(forKey: identity)
            }
            
            if !endedTouchList.isEmpty {
                delegate?.trackpadTouchesEnded(touches: endedTouchList)
            }
        }
        
        // If all touches have ended, cancel right-click detection
        if touchIdentityMap.isEmpty {
            rightClickDetectionTimer?.invalidate()
            rightClickDetectionTimer = nil
            potentialRightClickTouches.removeAll()
        }
    }
    
    private func checkForRightClick() {
        // If we still have exactly two touches that haven't moved much, trigger a right-click
        if potentialRightClickTouches.count == 2 && touchIdentityMap.count == 2 {
            // Convert to finger touches
            let fingerTouches = potentialRightClickTouches.map { createFingerTouchFromNSTouch(nsTouch: $0) }
            
            // Create a right-click gesture
            let gesture = TrackpadGesture(
                type: .tap(count: 2),
                touches: fingerTouches,
                magnitude: 1.0,
                rotation: nil,
                isMomentumScroll: false
            )
            
            // Publish the right-click gesture
            publishGestureEvent(gesture)
            
            Logger.debug("Detected right-click (two-finger tap)", log: Logger.trackpad)
        }
        
        // Clear the potential right-click state
        potentialRightClickTouches.removeAll()
        rightClickDetectionTimer = nil
    }
    
    private func createFingerTouchFromNSTouch(nsTouch: NSTouch) -> FingerTouch {
        // Create a FingerTouch with accurate properties
        return FingerTouch(
            id: nextTouchID(),
            position: nsTouch.normalizedPosition,
            pressure: 1.0,  // Default pressure since supportsPressure is not available
            majorRadius: 10.0,
            minorRadius: 10.0,
            fingerType: .unknown,
            timestamp: Date()
        )
    }
    
    private func detectGesture(touches: [FingerTouch]) {
        // Skip if we don't have enough history
        if previousTouches.isEmpty {
            previousTouches = touches
            return
        }
        
        // Calculate movement vectors between current and previous touches
        var totalDeltaX: CGFloat = 0
        var totalDeltaY: CGFloat = 0
        var totalDistance: CGFloat = 0
        var matchedTouches = 0
        
        // Match touches by ID and calculate movement
        for currentTouch in touches {
            if let previousIndex = previousTouches.firstIndex(where: { $0.id == currentTouch.id }) {
                let previousTouch = previousTouches[previousIndex]
                
                let deltaX = currentTouch.position.x - previousTouch.position.x
                let deltaY = currentTouch.position.y - previousTouch.position.y
                let distance = hypot(deltaX, deltaY)
                
                totalDeltaX += deltaX
                totalDeltaY += deltaY
                totalDistance += distance
                matchedTouches += 1
            }
        }
        
        // Reduce threshold for more sensitive gesture detection
        let adjustedThreshold = movementThreshold * 0.5 * CGFloat(matchedTouches)
        
        // Only process if we have matched touches and significant movement
        if matchedTouches > 0 && (
            // Either significant movement or multi-touch (which might be a static gesture)
            totalDistance > adjustedThreshold || touches.count >= 2
        ) {
            // Average the deltas
            let avgDeltaX = totalDeltaX / CGFloat(matchedTouches)
            let avgDeltaY = totalDeltaY / CGFloat(matchedTouches)
            
            // Determine gesture type based on touch count and movement
            let gestureType: TrackpadGesture.GestureType
            
            // Check for pinch/zoom gesture
            if touches.count == 2 {
                let touch1 = touches[0]
                let touch2 = touches[1]
                
                // Calculate distance between touches
                let currentDistance = hypot(touch1.position.x - touch2.position.x, 
                                           touch1.position.y - touch2.position.y)
                
                // Find corresponding previous touches
                if let prevTouch1 = previousTouches.first(where: { $0.id == touch1.id }),
                   let prevTouch2 = previousTouches.first(where: { $0.id == touch2.id }) {
                    
                    let previousDistance = hypot(prevTouch1.position.x - prevTouch2.position.x,
                                                prevTouch1.position.y - prevTouch2.position.y)
                    
                    // Calculate rotation
                    let currentAngle = atan2(touch2.position.y - touch1.position.y,
                                            touch2.position.x - touch1.position.x)
                    let previousAngle = atan2(prevTouch2.position.y - prevTouch1.position.y,
                                             prevTouch2.position.x - prevTouch1.position.x)
                    let rotation = currentAngle - previousAngle
                    
                    // Lower thresholds for better gesture detection
                    let distanceDelta = abs(currentDistance - previousDistance)
                    let rotationDelta = abs(rotation)
                    
                    // Check for pinch with reduced threshold
                    if distanceDelta > 0.005 && distanceDelta > rotationDelta * 0.3 {
                        // This is primarily a pinch gesture
                        let isPinchIn = currentDistance < previousDistance
                        let magnitude = min(1.0, distanceDelta * 15) // Increased multiplier for better visibility
                        
                        gestureType = .pinch
                        
                        // Create and publish pinch gesture
                        let gesture = TrackpadGesture(
                            type: gestureType,
                            touches: touches,
                            magnitude: magnitude,
                            rotation: nil,
                            isMomentumScroll: false
                        )
                        
                        publishGestureEvent(gesture)
                        Logger.debug("Detected pinch gesture: \(isPinchIn ? "in" : "out"), magnitude: \(magnitude)", log: Logger.trackpad)
                        
                    // Check for rotation with reduced threshold
                    } else if rotationDelta > 0.03 && rotationDelta > distanceDelta * 1.5 {
                        // This is primarily a rotation gesture
                        let magnitude = min(1.0, rotationDelta * 1.5) // Increased multiplier
                        
                        gestureType = .rotate
                        
                        // Create and publish rotation gesture
                        let gesture = TrackpadGesture(
                            type: gestureType,
                            touches: touches,
                            magnitude: magnitude,
                            rotation: rotation,
                            isMomentumScroll: false
                        )
                        
                        publishGestureEvent(gesture)
                        Logger.debug("Detected rotation gesture: \(rotation), magnitude: \(magnitude)", log: Logger.trackpad)
                        
                    // Reduced threshold for swipe detection
                    } else if totalDistance > adjustedThreshold {
                        // This is a two-finger swipe
                        detectSwipeGesture(deltaX: avgDeltaX, deltaY: avgDeltaY, touches: touches)
                    }
                }
            } else if touches.count >= 3 {
                // Multi-finger swipe with reduced threshold
                detectSwipeGesture(deltaX: avgDeltaX, deltaY: avgDeltaY, touches: touches)
            }
        }
        
        // Update previous touches for next comparison
        previousTouches = touches
    }
    
    private func detectSwipeGesture(deltaX: CGFloat, deltaY: CGFloat, touches: [FingerTouch]) {
        // Determine primary direction
        var swipeDirection: TrackpadGesture.GestureType.SwipeDirection
        if abs(deltaX) > abs(deltaY) {
            swipeDirection = deltaX > 0 ? .right : .left
        } else {
            swipeDirection = deltaY > 0 ? .up : .down
        }
        
        // Calculate magnitude based on total movement
        let totalMovement = hypot(deltaX, deltaY)
        let magnitude = min(1.0, totalMovement * 1.5) // Increase multiplier for better visualization
        
        // Create gesture type with direction
        let gestureType = TrackpadGesture.GestureType.swipe(direction: swipeDirection)
        
        // Create and publish gesture event
        let gesture = TrackpadGesture(
            type: gestureType,
            touches: touches,
            magnitude: magnitude,
            rotation: nil,
            isMomentumScroll: false
        )
        
        publishGestureEvent(gesture)
        
        // Log the direction for debugging
        Logger.debug("Swipe direction: \(swipeDirection), magnitude: \(magnitude)", log: Logger.trackpad)
    }
    
    private func cleanupStaleTouches() {
        let now = Date()
        let staleThreshold: TimeInterval = 1.0 // 1 second
        
        // Remove touches that haven't been updated in a while
        var staleTouchIdentities: [String] = []
        
        for (identity, touch) in touchIdentityMap {
            if let timestamp = touch.timestamp, now.timeIntervalSince(timestamp) > staleThreshold {
                staleTouchIdentities.append(identity)
            }
        }
        
        if !staleTouchIdentities.isEmpty {
            for identity in staleTouchIdentities {
                touchIdentityMap.removeValue(forKey: identity)
            }
            
            // Update raw touches
            DispatchQueue.main.async {
                self.rawTouches = self.rawTouches.filter { touch in
                    !staleTouchIdentities.contains(touch.identity.description)
                }
            }
            
            Logger.debug("Cleaned up \(staleTouchIdentities.count) stale touches", log: Logger.trackpad)
        }
    }
    
    private func publishGestureEvent(_ gesture: TrackpadGesture) {
        delegate?.trackpadMonitorDidDetectGesture(gesture)
        
        let gestureEvent = InputEvent.trackpadGestureEvent(gesture: gesture)
        
        DispatchQueue.main.async {
            // Replace any existing gesture of the same type
            var events = self.currentEvents
            
            // Filter out old gestures of the same type
            if case .swipe = gesture.type {
                events = events.filter { event in
                    if let eventGesture = event.trackpadGesture {
                        if case .swipe = eventGesture.type {
                            return false
                        }
                    }
                    return true
                }
            } else if case .pinch = gesture.type {
                events = events.filter { event in
                    if let eventGesture = event.trackpadGesture {
                        if case .pinch = eventGesture.type {
                            return false
                        }
                    }
                    return true
                }
            } else if case .rotate = gesture.type {
                events = events.filter { event in
                    if let eventGesture = event.trackpadGesture {
                        if case .rotate = eventGesture.type {
                            return false
                        }
                    }
                    return true
                }
            } else if case .tap = gesture.type {
                events = events.filter { event in
                    if let eventGesture = event.trackpadGesture {
                        if case .tap = eventGesture.type {
                            return false
                        }
                    }
                    return true
                }
            } else if case .scroll = gesture.type {
                events = events.filter { event in
                    if let eventGesture = event.trackpadGesture {
                        if case .scroll = eventGesture.type {
                            return false
                        }
                    }
                    return true
                }
            }
            
            // Add the new gesture event
            events.append(gestureEvent)
            self.currentEvents = events
        }
    }
    
    private func convertNSTouchPhaseToEventPhase(nsTouchPhase: NSTouch.Phase) -> EventPhase {
        switch nsTouchPhase {
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
        case .touching:
            return .moved
        default:
            return .unknown
        }
    }
    
    private func nextTouchID() -> Int {
        let id = touchIDCounter
        touchIDCounter += 1
        return id
    }
    
    // MARK: - Scroll Wheel Event Processing
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        processScrollWheelEvent(event: event)
    }
    
    private func processScrollWheelEvent(event: NSEvent) {
        // Detect momentum scrolling
        if event.momentumPhase != [] {
            // This is a momentum scroll event
            inMomentumScrolling = true
            momentumStartTime = Date()
            
            // Create momentum scroll event
            processMomentumScrollEvent(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
            return
        }
        
        // Check if we need to end momentum scrolling
        if inMomentumScrolling && (event.phase == .began || event.phase == .changed) {
            inMomentumScrolling = false
            momentumStartTime = nil
        }
        
        // Process regular scroll events
        processTrackpadScrollEvent(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            phase: event.phase,
            event: event
        )
    }
    
    private func processTrackpadScrollEvent(deltaX: CGFloat, deltaY: CGFloat, phase: NSEvent.Phase, event: NSEvent) {
        // Get deltas and phase information
        let momentumPhase = event.momentumPhase
        
        // Check if this is momentum scrolling
        let isMomentum = phase.isEmpty && !momentumPhase.isEmpty
        
        // Only process if there's actual movement
        if abs(deltaX) > 0.01 || abs(deltaY) > 0.01 {
            // Determine direction
            var swipeDirection: TrackpadGesture.GestureType.SwipeDirection
            if abs(deltaX) > abs(deltaY) {
                swipeDirection = deltaX > 0 ? .right : .left
            } else {
                swipeDirection = deltaY > 0 ? .up : .down
            }
            
            // Log the direction for debugging
            Logger.debug("Swipe direction: \(swipeDirection)", log: Logger.trackpad)
            
            // Create finger touch array with center position
            let centerPosition = CGPoint(x: 0.5, y: 0.5)
            let fingerTouch = FingerTouch(
                id: -1, // Special ID for scroll event
                position: centerPosition,
                pressure: 1.0,
                majorRadius: 10.0,
                minorRadius: 10.0,
                fingerType: .unknown,
                timestamp: Date()
            )
            
            // Use two finger touches for 2-finger scroll representation
            let touches = [fingerTouch]
            
            // Create gesture
            let gesture = TrackpadGesture(
                type: .scroll(fingerCount: 2, deltaX: deltaX, deltaY: deltaY),
                touches: touches,
                magnitude: min(1.0, sqrt(deltaX*deltaX + deltaY*deltaY) * 0.1),
                rotation: nil,
                isMomentumScroll: isMomentum
            )
            
            // Publish gesture event
            publishGestureEvent(gesture)
        }
    }
    
    // Specialized method to handle momentum scrolling
    private func processMomentumScrollEvent(deltaX: CGFloat, deltaY: CGFloat) {
        // Create touch points at scroll position
        let centerX = trackpadBounds.width / 2.0
        let centerY = trackpadBounds.height / 2.0
        
        // Create simulated touches for visualization
        let touchCount = 2 // Simulate two finger scroll
        var simulatedTouches: [FingerTouch] = []
        
        // Calculate direction
        let isHorizontal = abs(deltaX) > abs(deltaY)
        let spacing: CGFloat = 0.04
        
        for i in 0..<touchCount {
            let offset = spacing * CGFloat(i - (touchCount - 1) / 2)
            
            let x = isHorizontal ? centerX : centerX + offset
            let y = isHorizontal ? centerY + offset : centerY
            
            let touch = FingerTouch(
                id: -1000 - i, // Use negative IDs to avoid conflicts
                position: CGPoint(x: x, y: y),
                pressure: 0.4,
                majorRadius: 5.0,
                minorRadius: 5.0,
                fingerType: .index,
                timestamp: Date()
            )
            simulatedTouches.append(touch)
        }
        
        // Calculate magnitude based on total movement
        let totalMovement = hypot(deltaX, deltaY)
        let magnitude = min(1.0, totalMovement * 2.0) // Higher multiplier for momentum
        
        // Determine direction
        var scrollDirection: TrackpadGesture.GestureType.SwipeDirection
        if abs(deltaX) > abs(deltaY) {
            scrollDirection = deltaX > 0 ? .right : .left
        } else {
            scrollDirection = deltaY > 0 ? .up : .down
        }
        
        // Create and publish gesture
        let gesture = TrackpadGesture(
            type: .scroll(fingerCount: 2, deltaX: deltaX, deltaY: deltaY),
            touches: simulatedTouches,
            magnitude: magnitude,
            rotation: nil,
            isMomentumScroll: true
        )
        
        publishGestureEvent(gesture)
    }
    
    // MARK: - Trackpad Setup
    
    private func setupTrackpad() {
        // Configure for trackpad events
    }
    
    func startMonitoring() {
        guard !isMonitoring else {
            Logger.debug("Trackpad monitoring already active", log: Logger.trackpad)
            return
        }
        
        // Clear any existing state
        touchIdentityMap.removeAll()
        previousTouches.removeAll()
        currentEvents.removeAll()
        rawTouches.removeAll()
        
        // Capture the trackpad bounds
        detectTrackpadBounds()
        
        // Ensure we're in the responder chain
        setupResponderChain()
        
        isMonitoring = true
        Logger.info("Trackpad monitoring started", log: Logger.trackpad)
    }
    
    func stopMonitoring() {
        isMonitoring = false
        Logger.info("Trackpad monitoring stopped", log: Logger.trackpad)
        
        // Clear state
        DispatchQueue.main.async {
            self.touchIdentityMap.removeAll()
            self.previousTouches.removeAll()
            self.currentEvents.removeAll()
            self.rawTouches.removeAll()
        }
    }
    
    private func detectTrackpadBounds() {
        // Use default trackpad size for now
        trackpadBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
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

// Add the extension for NSEvent to get all touches
extension NSEvent {
    func allTouches() -> Set<NSTouch>? {
        return self.touches(matching: .touching, in: nil)
    }
}