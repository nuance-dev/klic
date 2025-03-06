import Foundation
import SwiftUI
import Combine
import AppKit

// Model for trackpad gesture events
struct TrackpadEvent: Identifiable, Equatable {
    let id = UUID()
    var timestamp = Date()
    var gestureType: GestureType
    var value: CGFloat
    var fingerCount: Int // Add finger count tracking
    var state: GestureState
    
    enum GestureType {
        case magnify // Pinch in/out
        case rotate
        case swipe   // Standard swipe gesture
        case scroll  // Two-finger scroll
    }
    
    enum GestureState {
        case began
        case changed
        case ended
    }
    
    static func ==(lhs: TrackpadEvent, rhs: TrackpadEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

// TrackpadMonitor class for handling system-wide trackpad gesture recognition
class TrackpadMonitor: ObservableObject {
    @Published var currentEvents: [InputEvent] = []
    @Published var isMonitoring: Bool = false
    
    // Event monitors
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    
    // Track active gestures
    private var activeGestures: [TrackpadEvent.GestureType: TrackpadEvent] = [:]
    
    // Cumulative values for gesture tracking
    private var cumulativeMagnification: CGFloat = 0
    private var cumulativeRotation: CGFloat = 0
    
    init() {
        Logger.info("Initializing TrackpadMonitor", log: Logger.mouse)
    }
    
    func startMonitoring() {
        Logger.info("Starting trackpad monitoring", log: Logger.mouse)
        
        // Stop any existing monitoring
        if isMonitoring {
            stopMonitoring()
        }
        
        // Track these gestures
        let trackpadEventMask: NSEvent.EventTypeMask = [
            .magnify,           // Pinch gesture events
            .swipe,             // Swipe gesture events
            .gesture,           // General gestures (including rotation)
            .scrollWheel        // Scroll gesture events
        ]
        
        // Global monitor (doesn't receive events when app is in foreground)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: trackpadEventMask) { [weak self] event in
            self?.handleTrackpadEvent(event)
        }
        
        // Local monitor (receives events when app is in foreground)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: trackpadEventMask) { [weak self] event in
            self?.handleTrackpadEvent(event)
            return event
        }
        
        isMonitoring = true
        Logger.info("Trackpad monitoring started", log: Logger.mouse)
    }
    
    func stopMonitoring() {
        Logger.info("Stopping trackpad monitoring", log: Logger.mouse)
        
        // Remove global monitor
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        
        // Remove local monitor
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        
        // Clear active gestures
        activeGestures.removeAll()
        
        isMonitoring = false
        Logger.info("Trackpad monitoring stopped", log: Logger.mouse)
    }
    
    // Handle trackpad events received from NSEvent monitors
    private func handleTrackpadEvent(_ event: NSEvent) {
        // Don't process events if not monitoring
        guard isMonitoring else { return }
        
        // Add comprehensive logging for all trackpad events
        Logger.debug("Trackpad Event: type=\(event.type.rawValue), subtype=\(event.subtype.rawValue), phase=\(event.phase)", log: Logger.mouse)
        
        // Debug log additional properties if they exist
        if event.type == .gesture || event.type == .magnify || event.type == .rotate {
            Logger.debug("Gesture details - magnification: \(event.magnification), rotation: \(event.rotation), phase: \(event.phase)", log: Logger.mouse)
        }
        
        if event.type == .magnify {
            handleMagnifyEvent(event)
        } else if event.type == .rotate {
            handleRotationGesture(event)
        } else if event.type == .gesture && (event.subtype.rawValue == 23 || event.subtype.rawValue == 6) {
            // Log more details about the gesture event to understand what's happening
            Logger.debug("Detected potential rotation gesture: subtype=\(event.subtype.rawValue), data1=\(event.data1), data2=\(event.data2)", log: Logger.mouse)
            handleRotationGesture(event)
        } else {
            Logger.debug("Unhandled trackpad event type: \(event.type.rawValue)", log: Logger.mouse)
        }
    }
    
    // Process magnify (pinch) gesture
    private func handleMagnifyEvent(_ event: NSEvent) {
        // Determine the gesture state based on the event's phase
        let state: TrackpadEvent.GestureState
        
        switch event.phase {
        case .began:
            state = .began
            Logger.debug("Magnify gesture began with value: \(event.magnification)", log: Logger.mouse)
            // Reset cumulative magnification at the start of a new gesture
            cumulativeMagnification = 0
        case .changed:
            state = .changed
            // Accumulate magnification changes
            cumulativeMagnification += event.magnification
        case .ended:
            state = .ended
            Logger.debug("Magnify gesture ended with cumulative value: \(cumulativeMagnification)", log: Logger.mouse)
        case .cancelled:
            state = .ended // Map cancelled to ended since we don't have a cancelled state
            Logger.debug("Magnify gesture cancelled with cumulative value: \(cumulativeMagnification)", log: Logger.mouse)
        default:
            state = .changed
        }
        
        // Create a trackpad event for the magnify gesture
        let trackpadEvent = TrackpadEvent(
            gestureType: .magnify,
            value: cumulativeMagnification,
            fingerCount: 2, // Pinch gestures typically involve 2 fingers
            state: state
        )
        
        // Update the current events
        updateTrackpadEvent(trackpadEvent)
        
        // Clean up after the gesture ends or is cancelled
        if state == .ended {
            // Reset cumulative magnification after the gesture completes
            cumulativeMagnification = 0
        }
    }
    
    // Process rotation gesture
    private func handleRotationGesture(_ event: NSEvent) {
        // Get the actual rotation value from the event instead of using a hardcoded increment
        let rotationDelta = CGFloat(event.rotation)
        
        // Log the actual rotation value
        Logger.debug("Rotation event: delta=\(rotationDelta), phase=\(event.phase)", log: Logger.mouse)
        
        let state: TrackpadEvent.GestureState
        
        switch event.phase {
        case .began:
            state = .began
            // Reset cumulative rotation at the start of a new gesture
            cumulativeRotation = 0
            Logger.debug("Rotation gesture began, resetting cumulative rotation", log: Logger.mouse)
        case .changed:
            state = .changed
            // Use the actual rotation value from the event
            cumulativeRotation += rotationDelta
            Logger.debug("Rotation changed, cumulative rotation: \(cumulativeRotation)", log: Logger.mouse)
        case .ended:
            state = .ended
            // Final rotation value when the gesture ends
            cumulativeRotation += rotationDelta
            Logger.debug("Rotation ended, final cumulative rotation: \(cumulativeRotation)", log: Logger.mouse)
        case .cancelled:
            // Map cancelled to ended, as our enum doesn't have a cancelled state
            state = .ended
            Logger.debug("Rotation cancelled, final cumulative rotation: \(cumulativeRotation)", log: Logger.mouse)
        default:
            state = .changed
            Logger.debug("Unknown rotation phase: \(event.phase), treating as changed", log: Logger.mouse)
        }
        
        let trackpadEvent = TrackpadEvent(
            gestureType: .rotate,
            value: cumulativeRotation,
            fingerCount: 2, // Rotation gestures typically involve 2 fingers
            state: state
        )
        
        // Update the current events
        updateTrackpadEvent(trackpadEvent)
        
        // Clean up after the gesture ends or is cancelled
        if state == .ended {
            // Reset cumulative rotation after the gesture completes
            cumulativeRotation = 0
        }
    }
    
    // Process swipe gesture
    private func handleSwipeEvent(_ event: NSEvent) {
        // Create trackpad event
        let trackpadEvent = TrackpadEvent(
            gestureType: .swipe,
            value: max(abs(event.deltaX), abs(event.deltaY)), // Use the larger delta as value
            fingerCount: estimateFingerCount(for: event),
            state: .changed // Swipes are typically instant
        )
        
        // Update the event
        updateTrackpadEvent(trackpadEvent)
        
        // Since swipe is instant, remove after delay
        removeGestureAfterDelay(.swipe)
    }
    
    // Process scroll wheel event (typically a two-finger gesture on trackpads)
    private func handleScrollEvent(_ event: NSEvent) {
        // Only process scroll events that are likely from a trackpad (not a mouse wheel)
        // Trackpad scrolls often have phase information
        let hasPhaseInfo = !event.phase.isEmpty || !event.momentumPhase.isEmpty
        if !hasPhaseInfo {
            // Skip if it looks like a traditional mouse wheel
            if !event.hasPreciseScrollingDeltas {
                return
            }
        }
        
        // Determine gesture state
        let gestureState: TrackpadEvent.GestureState
        if event.phase.contains(.began) || event.momentumPhase.contains(.began) {
            gestureState = .began
        } else if event.phase.contains(.changed) || event.momentumPhase.contains(.changed) {
            gestureState = .changed
        } else if event.phase.contains(.ended) || event.momentumPhase.contains(.ended) || 
                  event.phase.contains(.cancelled) || event.momentumPhase.contains(.cancelled) {
            gestureState = .ended
        } else {
            gestureState = .changed // Default to changed if we can't determine
        }
        
        // Magnitude of scroll (combine both axes)
        let magnitude = sqrt(pow(event.scrollingDeltaX, 2) + pow(event.scrollingDeltaY, 2))
        
        // Create trackpad event
        let trackpadEvent = TrackpadEvent(
            gestureType: .scroll,
            value: magnitude,
            fingerCount: event.hasPreciseScrollingDeltas ? 2 : 1, // Assume 2 fingers for precise scrolling
            state: gestureState
        )
        
        // Update the event
        updateTrackpadEvent(trackpadEvent)
        
        // Clean up if ended
        if gestureState == .ended {
            removeGestureAfterDelay(.scroll)
        }
    }
    
    // Estimate the number of fingers used in a gesture
    private func estimateFingerCount(for event: NSEvent) -> Int {
        // Note: NSEvent doesn't directly expose finger count for most gestures
        // This is an estimation based on common patterns
        
        switch event.type {
        case .magnify:
            return 2 // Typically 2 fingers for pinch
        case .gesture:
            // Try to determine if this is a rotation gesture
            if event.subtype.rawValue == 5 { // Rotation events typically have subtype 5
                return 2 // Typically 2 fingers for rotation
            }
            return 2 // Default for other gestures
        case .swipe:
            // macOS swipes can be 3 or 4 fingers depending on user settings
            // Try to guess based on velocity/magnitude
            let magnitude = max(abs(event.deltaX), abs(event.deltaY))
            return magnitude > 1.0 ? 3 : 4 // Higher magnitude might indicate 3 fingers
        case .scrollWheel:
            // Most trackpad scrolling is 2 fingers
            return event.hasPreciseScrollingDeltas ? 2 : 1
        default:
            return 2 // Default fallback
        }
    }
    
    // Update event in the current events array
    private func updateTrackpadEvent(_ event: TrackpadEvent) {
        // Store the active gesture
        activeGestures[event.gestureType] = event
        
        // Create InputEvent from TrackpadEvent
        let inputEvent = InputEvent.trackpadEvent(event: event)
        
        DispatchQueue.main.async {
            // Find and replace existing event of same type if present
            let existingIndex = self.currentEvents.firstIndex { 
                if let trackpadEvent = $0.trackpadEvent, 
                   trackpadEvent.gestureType == event.gestureType {
                    return true
                }
                return false
            }
            
            if let index = existingIndex {
                self.currentEvents[index] = inputEvent
            } else {
                self.currentEvents.append(inputEvent)
            }
            
            // Limit the number of trackpad events shown at once
            if self.currentEvents.count > 3 {
                // Only keep the 3 most recent events
                self.currentEvents = Array(self.currentEvents.suffix(3))
            }
        }
    }
    
    // Remove gesture after a delay
    private func removeGestureAfterDelay(_ type: TrackpadEvent.GestureType) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Remove from active gestures
            self.activeGestures.removeValue(forKey: type)
            
            // Remove from current events
            self.currentEvents.removeAll { 
                if let trackpadEvent = $0.trackpadEvent, 
                   trackpadEvent.gestureType == type {
                    return true
                }
                return false
            }
        }
    }
    
    // Clear all events
    func clearAllEvents() {
        activeGestures.removeAll()
        currentEvents.removeAll()
    }
    
    // MARK: - Gesture Recognizers for SwiftUI
    
    // Magnification gesture recognizer for SwiftUI
    func magnifyGesture() -> MagnificationGesture {
        // Note: Actual trackpad events will come from NSEvent monitoring
        // This is just for SwiftUI gesture recognition in the overlay
        return MagnificationGesture()
    }
    
    // Rotation gesture recognizer for SwiftUI
    func rotateGesture() -> RotationGesture {
        // Note: Actual trackpad events will come from NSEvent monitoring
        // This is just for SwiftUI gesture recognition in the overlay
        return RotationGesture()
    }
    
    // MARK: - Event Processing
} 