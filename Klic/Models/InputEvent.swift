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
struct FingerTouch: Hashable {
    let id: Int
    let position: CGPoint
    let pressure: CGFloat
    let majorRadius: CGFloat
    let minorRadius: CGFloat
    let fingerType: FingerType
    
    enum FingerType {
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

/// Represents a mouse event
struct MouseEvent {
    let position: CGPoint
    let button: MouseButton?
    let scrollDelta: CGPoint?
    let speed: CGFloat
    
    enum MouseButton {
        case left
        case right
        case middle
        case extra1
        case extra2
    }
}

/// Represents a keyboard event
struct KeyboardEvent {
    let keyCode: Int
    let characters: String?
    let modifiers: ModifierKeys
    let isRepeat: Bool
    
    struct ModifierKeys: OptionSet {
        let rawValue: Int
        
        static let command = ModifierKeys(rawValue: 1 << 0)
        static let shift = ModifierKeys(rawValue: 1 << 1)
        static let option = ModifierKeys(rawValue: 1 << 2)
        static let control = ModifierKeys(rawValue: 1 << 3)
        static let function = ModifierKeys(rawValue: 1 << 4)
        static let capsLock = ModifierKeys(rawValue: 1 << 5)
    }
}

/// Represents a trackpad gesture
struct TrackpadGesture {
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
    
    enum GestureType {
        case pinch
        case rotate
        case swipe(direction: SwipeDirection)
        case tap(count: Int)
        case scroll(fingerCount: Int, deltaX: CGFloat, deltaY: CGFloat)
        
        enum SwipeDirection {
            case up
            case down
            case left
            case right
        }
    }
}

/// The main input event model that encapsulates all types of input events
struct InputEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: InputEventType
    let keyboardEvent: KeyboardEvent?
    let mouseEvent: MouseEvent?
    let trackpadTouches: [FingerTouch]?
    let trackpadGesture: TrackpadGesture?
    
    // Convenience initializers for different event types
    static func keyEvent(type: InputEventType, keyCode: Int, characters: String?, modifiers: KeyboardEvent.ModifierKeys, isRepeat: Bool) -> InputEvent {
        InputEvent(
            timestamp: Date(),
            type: type,
            keyboardEvent: KeyboardEvent(keyCode: keyCode, characters: characters, modifiers: modifiers, isRepeat: isRepeat),
            mouseEvent: nil,
            trackpadTouches: nil,
            trackpadGesture: nil
        )
    }
    
    static func mouseEvent(type: InputEventType, position: CGPoint, button: MouseEvent.MouseButton? = nil, scrollDelta: CGPoint? = nil, speed: CGFloat = 0) -> InputEvent {
        InputEvent(
            timestamp: Date(),
            type: type,
            keyboardEvent: nil,
            mouseEvent: MouseEvent(position: position, button: button, scrollDelta: scrollDelta, speed: speed),
            trackpadTouches: nil,
            trackpadGesture: nil
        )
    }
    
    static func trackpadTouchEvent(touches: [FingerTouch]) -> InputEvent {
        InputEvent(
            timestamp: Date(),
            type: .trackpadTouch,
            keyboardEvent: nil,
            mouseEvent: nil,
            trackpadTouches: touches,
            trackpadGesture: nil
        )
    }
    
    static func trackpadGestureEvent(gesture: TrackpadGesture) -> InputEvent {
        InputEvent(
            timestamp: Date(),
            type: .trackpadGesture,
            keyboardEvent: nil,
            mouseEvent: nil,
            trackpadTouches: gesture.touches,
            trackpadGesture: gesture
        )
    }
} 