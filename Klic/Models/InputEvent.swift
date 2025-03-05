import Foundation
import SwiftUI

/// Represents the different types of input events that can be visualized
enum InputEventType {
    case keyDown
    case keyUp
    case mouseMove
    case mouseDown
    case mouseUp
    case mouseScroll
    case trackpadTouch
    case trackpadRelease
    case trackpadGesture
}

/// Represents a finger touch on the trackpad
struct FingerTouch: Hashable, Equatable {
    let id: Int
    var position: CGPoint
    var pressure: CGFloat
    var majorRadius: CGFloat
    var minorRadius: CGFloat
    var fingerType: FingerType
    var timestamp: Date?
    
    enum FingerType: String {
        case thumb
        case index
        case middle
        case ring
        case pinky
        case unknown
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FingerTouch, rhs: FingerTouch) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a mouse button
enum MouseButton: String, Equatable {
    case left
    case right
    case middle
    case extra1
    case extra2
    case other
}

/// Represents a mouse event
struct MouseEvent: Equatable {
    let position: CGPoint
    let button: MouseButton?
    let scrollDelta: CGPoint?
    let isDown: Bool
    let isDoubleClick: Bool
    let isMomentumScroll: Bool
    
    init(position: CGPoint, button: MouseButton? = nil, scrollDelta: CGPoint? = nil, isDown: Bool = false, isDoubleClick: Bool = false, isMomentumScroll: Bool = false) {
        self.position = position
        self.button = button
        self.scrollDelta = scrollDelta
        self.isDown = isDown
        self.isDoubleClick = isDoubleClick
        self.isMomentumScroll = isMomentumScroll
    }
}

/// Represents a keyboard event
struct KeyboardEvent: Equatable {
    let key: String
    let keyCode: Int
    let isDown: Bool
    let modifiers: [KeyModifier]
    let characters: String?
    let isRepeat: Bool
    
    var isModifierKey: Bool {
        return KeyModifier.allCases.contains { $0.keyCode == keyCode }
    }
}

/// Represents a trackpad gesture
struct TrackpadGesture: Equatable {
    let type: GestureType
    let touches: [FingerTouch]
    let magnitude: CGFloat
    let rotation: CGFloat?
    let isMomentumScroll: Bool
    
    init(type: GestureType, touches: [FingerTouch], magnitude: CGFloat, rotation: CGFloat?, isMomentumScroll: Bool = false) {
        self.type = type
        self.touches = touches
        self.magnitude = magnitude
        self.rotation = rotation
        self.isMomentumScroll = isMomentumScroll
    }
    
    enum GestureType: Equatable {
        case pinch
        case rotate
        case swipe(direction: SwipeDirection)
        case multiFingerSwipe(direction: SwipeDirection, fingerCount: Int)
        case tap(count: Int)
        case scroll(fingerCount: Int, deltaX: CGFloat, deltaY: CGFloat)
        
        enum SwipeDirection: String {
            case up
            case down
            case left
            case right
        }
    }
}

/// The main input event model that encapsulates all types of input events
struct InputEvent: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    
    // Event-specific data
    let keyboardEvent: KeyboardEvent?
    let mouseEvent: MouseEvent?
    let trackpadGesture: TrackpadGesture?
    let trackpadTouches: [FingerTouch]?
    
    // MARK: - Event Types
    
    enum EventType: String {
        case keyboard
        case mouse
        case trackpadGesture
        case trackpadTouch
    }
    
    // MARK: - Factory Methods
    
    static func keyboardEvent(key: String, keyCode: Int, isDown: Bool, modifiers: [KeyModifier], characters: String? = nil, isRepeat: Bool = false) -> InputEvent {
        let event = KeyboardEvent(key: key, keyCode: keyCode, isDown: isDown, modifiers: modifiers, characters: characters, isRepeat: isRepeat)
        return InputEvent(
            id: UUID(),
            timestamp: Date(),
            type: .keyboard,
            keyboardEvent: event,
            mouseEvent: nil,
            trackpadGesture: nil,
            trackpadTouches: nil
        )
    }
    
    static func mouseEvent(type: InputEventType, position: CGPoint, button: MouseButton? = nil, scrollDelta: CGPoint? = nil, isDown: Bool = false, isDoubleClick: Bool = false, isMomentumScroll: Bool = false) -> InputEvent {
        let event = MouseEvent(position: position, button: button, scrollDelta: scrollDelta, isDown: isDown, isDoubleClick: isDoubleClick, isMomentumScroll: isMomentumScroll)
        return InputEvent(
            id: UUID(),
            timestamp: Date(),
            type: .mouse,
            keyboardEvent: nil,
            mouseEvent: event,
            trackpadGesture: nil,
            trackpadTouches: nil
        )
    }
    
    static func trackpadGestureEvent(gesture: TrackpadGesture) -> InputEvent {
        return InputEvent(
            id: UUID(),
            timestamp: Date(),
            type: .trackpadGesture,
            keyboardEvent: nil,
            mouseEvent: nil,
            trackpadGesture: gesture,
            trackpadTouches: nil
        )
    }
    
    static func trackpadTouchEvent(touches: [FingerTouch]) -> InputEvent {
        return InputEvent(
            id: UUID(),
            timestamp: Date(),
            type: .trackpadTouch,
            keyboardEvent: nil,
            mouseEvent: nil,
            trackpadGesture: nil,
            trackpadTouches: touches
        )
    }
    
    // MARK: - Equatable
    
    static func == (lhs: InputEvent, rhs: InputEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Supporting Types

enum KeyModifier: String, CaseIterable {
    case shift
    case control
    case option
    case command
    case function
    case capsLock
    
    var keyCode: Int {
        switch self {
        case .shift: return 56
        case .control: return 59
        case .option: return 58
        case .command: return 55
        case .function: return 63
        case .capsLock: return 57
        }
    }
} 