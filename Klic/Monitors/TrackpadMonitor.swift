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

// Add default implementations to make these methods optional
extension TrackpadMonitorDelegate {
    func trackpadMonitorDidDetectGesture(_ gesture: TrackpadGesture) {}
    func trackpadTouchesBegan(touches: [FingerTouch]) {}
    func trackpadTouchesEnded(touches: [FingerTouch]) {}
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
    
    // Multi-finger tracking improvements
    private var lastMultiTouchCount: Int = 0
    private var multiTouchStartTime: Date?
    private let multiTouchRecognitionDelay: TimeInterval = 0.01 // Even shorter delay for quicker recognition
    
    // Enhanced sensitivity for multi-finger gestures (reduce threshold for faster detection)
    private let multiFingerSwipeThreshold: CGFloat = 3.0 // Lower threshold for better sensitivity
    
    // Lower the movement threshold for better gesture detection
    private let movementThreshold: CGFloat = 0.5 // Further reduced for better sensitivity
    
    // Add more specific thresholds for different finger counts
    private func getThresholdForFingerCount(_ count: Int) -> CGFloat {
        switch count {
        case 3: return 2.0  // Very sensitive for 3-finger gestures
        case 4: return 1.5  // Even more sensitive for 4-finger gestures
        case 5: return 1.0  // Most sensitive for 5-finger gestures
        default: return multiFingerSwipeThreshold
        }
    }
    
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
    private let rightClickThreshold: TimeInterval = 0.20 // Lower threshold for faster right-click detection
    
    // Create property for storing previous positions
    private var previousPositions: [CGPoint]?
    
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
            window.acceptsTouchEvents = true
            window.contentView?.acceptsTouchEvents = true
            window.contentView?.allowedTouchTypes = [.direct, .indirect]
            window.contentView?.nextResponder = self
            
            // Log for debugging
            Logger.debug("Set up trackpad monitoring for window: \(window)", log: Logger.trackpad)
        }
        
        // Add notification observer for new windows
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow {
                window.acceptsTouchEvents = true
                window.contentView?.acceptsTouchEvents = true
                window.contentView?.allowedTouchTypes = [.direct, .indirect]
                window.contentView?.nextResponder = self
                
                // Log for debugging
                Logger.debug("Added trackpad monitoring to new window: \(window)", log: Logger.trackpad)
            }
        }
        
        // Ensure we're in the global responder chain too
        if let mainWindow = NSApp.mainWindow {
            // Create a fallback responder chain from the main app window
            mainWindow.nextResponder = self
            Logger.debug("Added trackpad monitor to main window responder chain", log: Logger.trackpad)
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
            
            // Call our enhanced gesture detection
            detectAndProcessGesture(touches: touches)
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
        
        // Track multi-finger touches - improved for better recognition
        let touchCount = touches.count
        lastMultiTouchCount = touchCount
        multiTouchStartTime = Date()
        
        // Log multi-finger gestures to help with debugging
        if touchCount >= 3 {
            Logger.debug("Multi-finger touch detected: \(touchCount) fingers", log: Logger.trackpad)
            
            // Immediate detection for multi-finger touches (3+)
            detectMultiFingerGesture(touches: touches)
        }
        
        // If we have exactly two touches that just began, start a timer for right-click detection
        if touchCount == 2 && newTouches.count == 2 {
            potentialRightClickTouches = Array(touches)
            rightClickDetectionTimer?.invalidate()
            rightClickDetectionTimer = Timer.scheduledTimer(withTimeInterval: rightClickThreshold, repeats: false) { [weak self] _ in
                self?.checkForRightClick()
            }
        } else {
            // Clear right-click detection for other gestures
            rightClickDetectionTimer?.invalidate()
            potentialRightClickTouches.removeAll()
            
            // For all touch counts, notify delegate
            let allFingerTouches = Array(touchIdentityMap.values) 
            self.delegate?.trackpadTouchesBegan(touches: allFingerTouches)
            
            // Create and publish events for all touch counts
            if touchCount > 0 {
                let touchEvent = InputEvent.trackpadTouchEvent(touches: allFingerTouches)
                
                DispatchQueue.main.async {
                    // Add the event without duplicates
                    if !self.currentEvents.contains(where: { $0.type == .trackpadTouch }) {
                        self.currentEvents.append(touchEvent)
                    }
                }
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
    
    // Add the missing convertTouchToFingerTouch function
    private func convertTouchToFingerTouch(_ touch: NSTouch) -> FingerTouch {
        // This is a simpler wrapper around createFingerTouchFromNSTouch for consistent naming
        return createFingerTouchFromNSTouch(nsTouch: touch)
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
        
        // Create gesture type with direction and finger count for better visualization
        let fingerCount = touches.count
        let gestureType: TrackpadGesture.GestureType
        
        // Classify based on finger count for better multi-finger detection
        if fingerCount >= 4 {
            // Special handling for 4+ finger gestures
            gestureType = .multiFingerSwipe(direction: swipeDirection, fingerCount: fingerCount)
            Logger.debug("Multi-finger swipe (\(fingerCount) fingers): \(swipeDirection)", log: Logger.trackpad)
        } else {
            gestureType = .swipe(direction: swipeDirection)
        }
        
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
        Logger.debug("Swipe direction: \(swipeDirection), magnitude: \(magnitude), fingers: \(fingerCount)", log: Logger.trackpad)
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
        
        // Log the event to debug what's happening with trackpad events
        Logger.debug("TrackpadMonitor received scrollWheel event: phase: \(event.phase), momentum: \(event.momentumPhase), precise: \(event.hasPreciseScrollingDeltas)", log: Logger.trackpad)
        
        processScrollWheelEvent(event: event)
    }
    
    private func processScrollWheelEvent(event: NSEvent) {
        // Force process all scroll events, regardless of source
        // This ensures that trackpad scrolls are captured even if they're being sent as mouse events
        
        // Detect momentum scrolling
        if event.momentumPhase != [] {
            // This is a momentum scroll event
            inMomentumScrolling = true
            momentumStartTime = Date()
            
            // Create momentum scroll event
            processMomentumScrollEvent(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
            
            // Log the momentum event for debugging
            Logger.debug("Processing momentum scroll with delta (\(event.scrollingDeltaX), \(event.scrollingDeltaY))", log: Logger.trackpad)
            return
        }
        
        // Check if we need to end momentum scrolling
        if inMomentumScrolling && (event.phase == .began || event.phase == .changed) {
            inMomentumScrolling = false
            momentumStartTime = nil
        }
        
        // Process regular scroll events with enhanced logging
        processTrackpadScrollEvent(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            phase: event.phase,
            event: event
        )
        
        // Log the event for debugging
        Logger.debug("Processed trackpad scroll with delta (\(event.scrollingDeltaX), \(event.scrollingDeltaY)), phase: \(event.phase)", log: Logger.trackpad)
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
        
        // Explicitly accept touch events
        NSApp.windows.forEach { $0.acceptsTouchEvents = true }
        
        // Direct event monitoring for trackpad gestures using NSEvent global monitors
        // This approach is more reliable for capturing trackpad events
        
        // Monitor for magnification gestures (pinch)
        NSEvent.addGlobalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self = self, self.isMonitoring else { return }
            
            // Create a synthetic pinch gesture
            let magnitude = event.magnification
            let centerPosition = CGPoint(x: 0.5, y: 0.5)
            
            let touch1 = FingerTouch(
                id: self.nextTouchID(),
                position: CGPoint(x: 0.4, y: 0.5),
                pressure: 0.8,
                majorRadius: 10,
                minorRadius: 10,
                fingerType: .index,
                timestamp: Date()
            )
            
            let touch2 = FingerTouch(
                id: self.nextTouchID(),
                position: CGPoint(x: 0.6, y: 0.5),
                pressure: 0.8,
                majorRadius: 10,
                minorRadius: 10,
                fingerType: .thumb,
                timestamp: Date()
            )
            
            let gesture = TrackpadGesture(
                type: .pinch,
                touches: [touch1, touch2],
                magnitude: magnitude,
                rotation: nil,
                isMomentumScroll: false
            )
            
            // Publish the gesture
            self.publishGestureEvent(gesture)
            Logger.debug("Detected magnification/pinch gesture: \(magnitude)", log: Logger.trackpad)
        }
        
        // Monitor for rotation gestures
        NSEvent.addGlobalMonitorForEvents(matching: .rotate) { [weak self] event in
            guard let self = self, self.isMonitoring else { return }
            
            // Create a synthetic rotation gesture
            let rotation = event.rotation
            let centerPosition = CGPoint(x: 0.5, y: 0.5)
            
            let touch1 = FingerTouch(
                id: self.nextTouchID(),
                position: CGPoint(x: 0.4, y: 0.6),
                pressure: 0.8,
                majorRadius: 10,
                minorRadius: 10,
                fingerType: .index,
                timestamp: Date()
            )
            
            let touch2 = FingerTouch(
                id: self.nextTouchID(),
                position: CGPoint(x: 0.6, y: 0.4),
                pressure: 0.8,
                majorRadius: 10,
                minorRadius: 10,
                fingerType: .thumb,
                timestamp: Date()
            )
            
            let gesture = TrackpadGesture(
                type: .rotate,
                touches: [touch1, touch2],
                magnitude: abs(rotation / 30),
                rotation: rotation,
                isMomentumScroll: false
            )
            
            // Publish the gesture
            self.publishGestureEvent(gesture)
            Logger.debug("Detected rotation gesture: \(rotation)", log: Logger.trackpad)
        }
        
        // Monitor for swipe gestures
        NSEvent.addGlobalMonitorForEvents(matching: .swipe) { [weak self] event in
            guard let self = self, self.isMonitoring else { return }
            
            // Determine swipe direction
            let deltaX = event.deltaX
            let deltaY = event.deltaY
            
            var direction: TrackpadGesture.GestureType.SwipeDirection
            if abs(deltaX) > abs(deltaY) {
                direction = deltaX > 0 ? .right : .left
            } else {
                direction = deltaY > 0 ? .up : .down
            }
            
            // Default to 3 fingers for swipe events from NSEvent
            let fingerCount = 3
            
            // Create finger touches in a swipe pattern
            var touches: [FingerTouch] = []
            for i in 0..<fingerCount {
                let offsetY = CGFloat(i - fingerCount/2) * 0.1
                
                let touch = FingerTouch(
                    id: self.nextTouchID(),
                    position: CGPoint(x: 0.5, y: 0.5 + offsetY),
                    pressure: 0.7,
                    majorRadius: 10,
                    minorRadius: 10,
                    fingerType: .unknown,
                    timestamp: Date()
                )
                touches.append(touch)
            }
            
            let gesture = TrackpadGesture(
                type: .multiFingerSwipe(direction: direction, fingerCount: fingerCount),
                touches: touches,
                magnitude: 1.0,
                rotation: nil,
                isMomentumScroll: false
            )
            
            // Publish the gesture
            self.publishGestureEvent(gesture)
            Logger.debug("Detected swipe gesture: \(direction) with delta (\(deltaX), \(deltaY))", log: Logger.trackpad)
        }
        
        // More reliable handler for trackpad scrolling
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self, self.isMonitoring else { return }
            
            // Only process if it's clearly a trackpad event
            if event.hasPreciseScrollingDeltas || event.phase != [] || event.momentumPhase != [] {
                // This is almost certainly a trackpad event
                self.processTrackpadScrollEvent(
                    deltaX: event.scrollingDeltaX,
                    deltaY: event.scrollingDeltaY,
                    phase: event.phase,
                    event: event
                )
                
                Logger.debug("Detected trackpad scroll: (\(event.scrollingDeltaX), \(event.scrollingDeltaY)), phase: \(event.phase)", log: Logger.trackpad)
            }
        }
        
        // Add the local monitors as well for good measure
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            self?.processLocalMagnify(event)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .rotate) { [weak self] event in
            self?.processLocalRotate(event)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .swipe) { [weak self] event in
            self?.processLocalSwipe(event)
            return event
        }
        
        // Register for scroll wheel notifications globally and locally
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self, self.isMonitoring else { return event }
            
            // Check if it's a trackpad scroll event
            if event.hasPreciseScrollingDeltas || event.phase != [] || event.momentumPhase != [] {
                self.processScrollWheelEvent(event: event)
            }
            
            return event
        }
        
        isMonitoring = true
        Logger.info("Trackpad monitoring started with low-level gesture detection", log: Logger.trackpad)
        
        // Output a debug gesture immediately to verify system
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.triggerDebugGesture()
        }
    }
    
    // Additional local event handling functions
    private func processLocalMagnify(_ event: NSEvent) -> Void {
        guard isMonitoring else { return }
        
        // Create and publish a magnify (pinch) gesture
        let magnitude = event.magnification
        let touch1 = FingerTouch(
            id: nextTouchID(),
            position: CGPoint(x: 0.4, y: 0.5),
            pressure: 0.8,
            majorRadius: 10,
            minorRadius: 10,
            fingerType: .index,
            timestamp: Date()
        )
        
        let touch2 = FingerTouch(
            id: nextTouchID(),
            position: CGPoint(x: 0.6, y: 0.5),
            pressure: 0.8,
            majorRadius: 10,
            minorRadius: 10,
            fingerType: .thumb,
            timestamp: Date()
        )
        
        let gesture = TrackpadGesture(
            type: .pinch,
            touches: [touch1, touch2],
            magnitude: magnitude,
            rotation: nil,
            isMomentumScroll: false
        )
        
        // Publish the gesture
        publishGestureEvent(gesture)
        Logger.debug("Local magnification/pinch gesture detected: \(magnitude)", log: Logger.trackpad)
    }
    
    private func processLocalRotate(_ event: NSEvent) -> Void {
        guard isMonitoring else { return }
        
        // Create and publish a rotation gesture
        let rotation = event.rotation
        let touch1 = FingerTouch(
            id: nextTouchID(),
            position: CGPoint(x: 0.4, y: 0.6),
            pressure: 0.8,
            majorRadius: 10,
            minorRadius: 10,
            fingerType: .index,
            timestamp: Date()
        )
        
        let touch2 = FingerTouch(
            id: nextTouchID(),
            position: CGPoint(x: 0.6, y: 0.4),
            pressure: 0.8,
            majorRadius: 10,
            minorRadius: 10,
            fingerType: .thumb,
            timestamp: Date()
        )
        
        let gesture = TrackpadGesture(
            type: .rotate,
            touches: [touch1, touch2],
            magnitude: abs(rotation / 30),
            rotation: rotation,
            isMomentumScroll: false
        )
        
        // Publish the gesture
        publishGestureEvent(gesture)
        Logger.debug("Local rotation gesture detected: \(rotation)", log: Logger.trackpad)
    }
    
    private func processLocalSwipe(_ event: NSEvent) -> Void {
        guard isMonitoring else { return }
        
        // Determine swipe direction
        let deltaX = event.deltaX
        let deltaY = event.deltaY
        
        var direction: TrackpadGesture.GestureType.SwipeDirection
        if abs(deltaX) > abs(deltaY) {
            direction = deltaX > 0 ? .right : .left
        } else {
            direction = deltaY > 0 ? .up : .down
        }
        
        // Default to 3 fingers for swipe events
        let fingerCount = 3
        
        // Create finger touches in a row
        var touches: [FingerTouch] = []
        for i in 0..<fingerCount {
            let offsetX = CGFloat(i - fingerCount/2) * 0.15
            
            let touch = FingerTouch(
                id: nextTouchID(),
                position: CGPoint(x: 0.5 + offsetX, y: 0.5),
                pressure: 0.7,
                majorRadius: 10,
                minorRadius: 10,
                fingerType: .unknown,
                timestamp: Date()
            )
            touches.append(touch)
        }
        
        let gesture = TrackpadGesture(
            type: .multiFingerSwipe(direction: direction, fingerCount: fingerCount),
            touches: touches,
            magnitude: 1.0,
            rotation: nil,
            isMomentumScroll: false
        )
        
        // Publish the gesture
        publishGestureEvent(gesture)
        Logger.debug("Local swipe gesture detected: \(direction)", log: Logger.trackpad)
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
        
        // Note: We can't remove global monitors once added, but they'll be inactive when isMonitoring is false
    }
    
    private func detectTrackpadBounds() {
        // Use default trackpad size for now
        trackpadBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    
    private func detectAndProcessGesture(touches: Set<NSTouch>) {
        // Count active touches
        let touchCount = touches.count
        
        // Enhanced multi-finger gesture detection
        // We'll be more sensitive to multi-finger gestures, especially 3 and 4 finger gestures
        if touchCount >= 2 {
            // Enhanced gesture detection logic for swipes, pinches, rotations
            if touchCount == 2 {
                detectTwoFingerGesture(touches: touches)
            } else if touchCount == 3 {
                detect3FingerGesture(touches: touches)
            } else if touchCount >= 4 {
                // Improved 4+ finger gesture detection (specifically requested by user)
                detect4PlusFingerGesture(touches: touches, fingerCount: touchCount)
            }
        } else if touchCount == 1 {
            // Single finger touch/tap detection
            detectSingleFingerGesture(touches: touches)
        }
    }
    
    private func detect4PlusFingerGesture(touches: Set<NSTouch>, fingerCount: Int) {
        // Convert touches to our internal format
        let fingerTouches = touches.map { convertTouchToFingerTouch($0) }
        
        // Calculate current centroid (average position) - breaking up complex expressions
        let positions = fingerTouches.map { $0.position }
        
        // Calculate sum of positions - breaking up for better type checking
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for position in positions {
            sumX += position.x
            sumY += position.y
        }
        
        // Calculate centroid from the sum
        let centroid = CGPoint(
            x: sumX / CGFloat(positions.count),
            y: sumY / CGFloat(positions.count)
        )
        
        // Log for debugging
        Logger.debug("4+ finger gesture detected with \(fingerCount) fingers", log: Logger.trackpad)
        
        // Get previous centroids if we have them stored
        if let prevPositions = previousPositions, prevPositions.count > 0 {
            // For better 4+ finger detection, we don't require exact finger count match
            // This allows for more reliable detection even if finger count changes slightly
            
            // Calculate previous centroid - breaking up for better type checking
            var prevSumX: CGFloat = 0
            var prevSumY: CGFloat = 0
            for position in prevPositions {
                prevSumX += position.x
                prevSumY += position.y
            }
            
            let avgPrevCentroid = CGPoint(
                x: prevSumX / CGFloat(prevPositions.count),
                y: prevSumY / CGFloat(prevPositions.count)
            )
            
            // Calculate the movement delta
            let deltaX = centroid.x - avgPrevCentroid.x
            let deltaY = centroid.y - avgPrevCentroid.y
            
            // Use lower threshold for 4+ finger gestures
            let swipeThreshold = getThresholdForFingerCount(fingerCount)
            
            // Detect swipe direction based on the delta
            if abs(deltaX) > swipeThreshold || abs(deltaY) > swipeThreshold {
                // Determine swipe direction
                let isHorizontal = abs(deltaX) > abs(deltaY)
                let isPositive = isHorizontal ? deltaX > 0 : deltaY > 0
                
                var direction: TrackpadGesture.GestureType.SwipeDirection
                
                if isHorizontal {
                    direction = isPositive ? .right : .left
                    Logger.debug("4+ finger horizontal swipe: \(direction)", log: Logger.trackpad)
                } else {
                    direction = isPositive ? .down : .up
                    Logger.debug("4+ finger vertical swipe: \(direction)", log: Logger.trackpad)
                }
                
                // Create and dispatch swipe gesture
                let swipeGesture = TrackpadGesture(
                    type: .swipe(direction: direction),
                    touches: fingerTouches,
                    magnitude: isHorizontal ? abs(deltaX) : abs(deltaY),
                    rotation: nil
                )
                
                // Dispatch event
                let event = InputEvent.trackpadGestureEvent(gesture: swipeGesture)
                DispatchQueue.main.async {
                    self.currentEvents = [event]
                    self.eventSubject.send(event)
                }
                
                // Notify delegate
                delegate?.trackpadMonitorDidDetectGesture(swipeGesture)
                
                // Update previous gesture
                previousGesture = swipeGesture
            }
        }
        
        // Store current positions for next comparison
        previousPositions = positions
    }
    
    private func detectSingleFingerGesture(touches: Set<NSTouch>) {
        guard let touch = touches.first else { return }
        
        // Convert to our format
        let fingerTouch = convertTouchToFingerTouch(touch)
        
        // For single finger, we primarily care about taps
        // Most movement tracking is handled elsewhere for single finger
        
        // Create a touch event
        let touchEvent = InputEvent.trackpadTouchEvent(touches: [fingerTouch])
        
        DispatchQueue.main.async {
            // Update current events
            self.currentEvents.removeAll { event in
                if event.type == .trackpadTouch && event.trackpadTouches?.count == 1 {
                    return true
                }
                return false
            }
            self.currentEvents.append(touchEvent)
        }
        
        // Notify delegate about touches
        delegate?.trackpadTouchesBegan(touches: [fingerTouch])
    }
    
    private func detectTwoFingerGesture(touches: Set<NSTouch>) {
        // Convert touches to our internal format
        let fingerTouches = touches.map { convertTouchToFingerTouch($0) }
        
        // Calculate current positions
        let positions = fingerTouches.map { $0.position }
        
        // Calculate distance between touch points for pinch detection
        if positions.count == 2 {
            let distance = hypot(positions[0].x - positions[1].x, positions[0].y - positions[1].y)
            
            // Get previous positions if available
            if let prevPositions = previousPositions, prevPositions.count == 2 {
                let prevDistance = hypot(prevPositions[0].x - prevPositions[1].x, prevPositions[0].y - prevPositions[1].y)
                
                // Calculate deltas
                let deltaDistance = distance - prevDistance
                
                // Calculate movement delta (for scroll detection) - breaking into simpler steps
                let currentCenterX = (positions[0].x + positions[1].x) / 2
                let currentCenterY = (positions[0].y + positions[1].y) / 2
                let prevCenterX = (prevPositions[0].x + prevPositions[1].x) / 2
                let prevCenterY = (prevPositions[0].y + prevPositions[1].y) / 2
                
                let deltaX = currentCenterX - prevCenterX
                let deltaY = currentCenterY - prevCenterY
                
                // Determine gesture type
                if abs(deltaDistance) > 0.01 {
                    // Pinch gesture
                    let gesture = TrackpadGesture(
                        type: .pinch,
                        touches: fingerTouches,
                        magnitude: abs(deltaDistance),
                        rotation: nil,
                        isMomentumScroll: false
                    )
                    
                    // Send pinch event
                    let inputEvent = InputEvent.trackpadGestureEvent(gesture: gesture)
                    DispatchQueue.main.async {
                        // Update current events - simplified conditional
                        self.currentEvents.removeAll { event in
                            if let gesture = event.trackpadGesture {
                                if case .pinch = gesture.type {
                                    return true
                                }
                            }
                            return false
                        }
                        self.currentEvents.append(inputEvent)
                    }
                    
                    // Notify delegate
                    delegate?.trackpadMonitorDidDetectGesture(gesture)
                    
                } else if abs(deltaX) > 0.01 || abs(deltaY) > 0.01 {
                    // Swipe - determine direction
                    var direction: TrackpadGesture.GestureType.SwipeDirection
                    
                    if abs(deltaX) > abs(deltaY) {
                        direction = deltaX > 0 ? .right : .left
                    } else {
                        direction = deltaY > 0 ? .down : .up
                    }
                    
                    // Create swipe gesture
                    let gesture = TrackpadGesture(
                        type: .swipe(direction: direction),
                        touches: fingerTouches,
                        magnitude: max(abs(deltaX), abs(deltaY)),
                        rotation: nil,
                        isMomentumScroll: false
                    )
                    
                    // Send swipe event
                    let inputEvent = InputEvent.trackpadGestureEvent(gesture: gesture)
                    DispatchQueue.main.async {
                        // Update current events - simplify the complex conditional
                        self.currentEvents.removeAll { event in
                            if let gesture = event.trackpadGesture {
                                if case .swipe = gesture.type {
                                    return true
                                }
                            }
                            return false
                        }
                        self.currentEvents.append(inputEvent)
                    }
                    
                    // Notify delegate
                    delegate?.trackpadMonitorDidDetectGesture(gesture)
                    
                }
            }
        }
        
        // Store current positions for next comparison
        previousPositions = positions
    }
    
    private func detect3FingerGesture(touches: Set<NSTouch>) {
        // Convert touches to our internal format
        let fingerTouches = touches.map { convertTouchToFingerTouch($0) }
        
        // Calculate current centroid (average position) - breaking up complex expressions
        let positions = fingerTouches.map { $0.position }
        
        // Calculate sum of positions - breaking up for better type checking
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for position in positions {
            sumX += position.x
            sumY += position.y
        }
        
        // Calculate centroid from the sum
        let centroid = CGPoint(
            x: sumX / CGFloat(positions.count),
            y: sumY / CGFloat(positions.count)
        )
        
        // Get previous centroids if we have them stored
        if let prevPositions = previousPositions, prevPositions.count == 3 {
            // Calculate previous centroid - breaking up for better type checking
            var prevSumX: CGFloat = 0
            var prevSumY: CGFloat = 0
            for position in prevPositions {
                prevSumX += position.x
                prevSumY += position.y
            }
            
            let avgPrevCentroid = CGPoint(
                x: prevSumX / CGFloat(prevPositions.count),
                y: prevSumY / CGFloat(prevPositions.count)
            )
            
            // Calculate the movement delta
            let deltaX = centroid.x - avgPrevCentroid.x
            let deltaY = centroid.y - avgPrevCentroid.y
            
            // For 3-finger gestures, we're primarily interested in swipes
            if abs(deltaX) > 0.01 || abs(deltaY) > 0.01 {
                var direction: TrackpadGesture.GestureType.SwipeDirection
                
                if abs(deltaX) > abs(deltaY) {
                    // Horizontal swipe
                    direction = deltaX > 0 ? .right : .left
                } else {
                    // Vertical swipe
                    direction = deltaY > 0 ? .down : .up
                }
                
                // Create a swipe gesture
                let gesture = TrackpadGesture(
                    type: .swipe(direction: direction),
                    touches: fingerTouches,
                    magnitude: max(abs(deltaX), abs(deltaY)),
                    rotation: nil,
                    isMomentumScroll: false
                )
                
                // Send the gesture event
                let inputEvent = InputEvent.trackpadGestureEvent(gesture: gesture)
                DispatchQueue.main.async {
                    // Remove any existing 3-finger swipe gestures - breaking up complex conditional
                    self.currentEvents.removeAll { event in
                        if let gesture = event.trackpadGesture {
                            if case .swipe = gesture.type {
                                if gesture.touches.count == 3 {
                                    return true
                                }
                            }
                        }
                        return false
                    }
                    self.currentEvents.append(inputEvent)
                }
                
                // Notify delegate about the gesture
                delegate?.trackpadMonitorDidDetectGesture(gesture)
                
                // Log the detection of a 3-finger swipe
                Logger.debug("3-finger swipe detected: \(direction), magnitude: \(max(abs(deltaX), abs(deltaY)))", log: Logger.trackpad)
            }
        }
        
        // Store current positions for next comparison
        previousPositions = positions
    }
    
    // MARK: - Enhanced Touch Processing
    
    private func detectMultiFingerGesture(touches: Set<NSTouch>) {
        // Get the finger count
        let fingerCount = touches.count
        
        // Early return if we don't have enough fingers
        if fingerCount < 3 {
            return
        }
        
        Logger.debug("Detecting multi-finger gesture with \(fingerCount) fingers", log: Logger.trackpad)
        
        // Convert NSTouch objects to FingerTouch objects
        let fingerTouches = touches.map { createFingerTouchFromNSTouch(nsTouch: $0) }
        
        // Create a multi-finger tap gesture
        let gestureType = TrackpadGesture.GestureType.tap(count: fingerCount)
        let gesture = TrackpadGesture(
            type: gestureType,
            touches: fingerTouches,
            magnitude: CGFloat(fingerCount) / 5.0, // Scale magnitude by finger count
            rotation: nil,
            isMomentumScroll: false
        )
        
        // Send the gesture to the delegate
        self.delegate?.trackpadMonitorDidDetectGesture(gesture)
        
        // Create and publish a trackpad event
        let trackpadEvent = InputEvent.trackpadGestureEvent(gesture: gesture)
        
        // Clear any existing multi-finger gestures to avoid duplicates
        DispatchQueue.main.async {
            // Remove existing multi-finger taps
            self.currentEvents.removeAll { event in
                if let gestureEvent = event.trackpadGesture?.type {
                    if case .tap = gestureEvent {
                        return true
                    }
                }
                return false
            }
            
            // Add the new event
            self.currentEvents.append(trackpadEvent)
            
            // Notify system that we've detected a gesture
            NotificationCenter.default.post(
                name: NSNotification.Name("TrackpadGestureDetected"),
                object: nil,
                userInfo: ["fingerCount": fingerCount]
            )
            
            // Log the detection
            Logger.info("Detected \(fingerCount)-finger tap gesture", log: Logger.trackpad)
        }
    }
    
    // Add a debug function to trigger a fake gesture to verify visualization is working
    private func triggerDebugGesture() {
        guard isMonitoring else { return }
        
        Logger.debug("Triggering debug trackpad gesture", log: Logger.trackpad)
        
        // Create two simulated touches
        let touch1 = FingerTouch(
            id: -1001,
            position: CGPoint(x: 0.3, y: 0.5),
            pressure: 0.8,
            majorRadius: 10,
            minorRadius: 10,
            fingerType: .index,
            timestamp: Date()
        )
        
        let touch2 = FingerTouch(
            id: -1002,
            position: CGPoint(x: 0.7, y: 0.5),
            pressure: 0.8,
            majorRadius: 10,
            minorRadius: 10,
            fingerType: .middle,
            timestamp: Date()
        )
        
        // Create a simulated pinch gesture
        let gesture = TrackpadGesture(
            type: .pinch,
            touches: [touch1, touch2],
            magnitude: 0.8,
            rotation: nil,
            isMomentumScroll: false
        )
        
        // Publish the debug gesture
        publishGestureEvent(gesture)
        
        // Also publish raw touch data
        let nsTouch1 = NSTouch()
        let nsTouch2 = NSTouch()
        rawTouches = [nsTouch1, nsTouch2]
        
        // Create and publish a touch event
        let touchEvent = InputEvent.trackpadTouchEvent(touches: [touch1, touch2])
        DispatchQueue.main.async {
            self.currentEvents.append(touchEvent)
        }
        
        // Log that we sent the debug gesture
        Logger.debug("Debug trackpad gesture and touches sent", log: Logger.trackpad)
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