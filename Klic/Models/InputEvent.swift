import Foundation
import SwiftUI
import Combine

/// Represents the different types of input events that can be visualized
enum InputEventType {
    case keyDown
    case keyUp
    case mouseMove
    case mouseDown
    case mouseUp
    case mouseScroll
    case trackpadGesture
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
struct MouseEvent: Identifiable, Equatable {
    let id: UUID
    var timestamp: Date
    var type: MouseEventType
    var position: CGPoint
    var button: MouseButton?
    var scrollDelta: CGPoint
    var isDown: Bool
    var isDoubleClick: Bool
    var isMomentumScroll: Bool
    
    init(id: UUID = UUID(), timestamp: Date = Date(), type: MouseEventType = .move, position: CGPoint, button: MouseButton? = nil, scrollDelta: CGPoint? = nil, isDown: Bool = false, isDoubleClick: Bool = false, isMomentumScroll: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.position = position
        self.button = button
        self.scrollDelta = scrollDelta ?? CGPoint.zero
        self.isDown = isDown
        self.isDoubleClick = isDoubleClick
        self.isMomentumScroll = isMomentumScroll
    }
    
    enum MouseEventType {
        case move
        case leftDown
        case leftUp
        case rightDown
        case rightUp
        case scroll
    }
    
    static func ==(lhs: MouseEvent, rhs: MouseEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a keyboard event
struct KeyboardEvent: Identifiable, Equatable {
    let id: UUID
    var timestamp: Date
    var keyCode: Int
    var keyChar: String
    var isKeyDown: Bool
    var isRepeat: Bool
    var modifiers: UInt
    
    var isModifierKey: Bool {
        return keyCode == 55 || // command
               keyCode == 56 || // shift
               keyCode == 58 || // option
               keyCode == 59 || // control
               keyCode == 63 || // function
               keyCode == 57    // caps lock
    }
    
    static func ==(lhs: KeyboardEvent, rhs: KeyboardEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

/// The main input event model that encapsulates all types of input events
struct InputEvent: Identifiable, Equatable {
    let id: UUID
    var timestamp: Date
    var type: EventType
    let keyboardEvent: KeyboardEvent?
    let mouseEvent: MouseEvent?
    let trackpadEvent: TrackpadEvent?
    
    enum EventType {
        case keyboard
        case mouse
        case trackpad
    }
    
    init(id: UUID = UUID(), timestamp: Date = Date(), type: EventType, keyboardEvent: KeyboardEvent? = nil, mouseEvent: MouseEvent? = nil, trackpadEvent: TrackpadEvent? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.keyboardEvent = keyboardEvent
        self.mouseEvent = mouseEvent
        self.trackpadEvent = trackpadEvent
    }
    
    static func ==(lhs: InputEvent, rhs: InputEvent) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func keyboardEvent(event: KeyboardEvent) -> InputEvent {
        return InputEvent(type: .keyboard, keyboardEvent: event)
    }
    
    static func mouseEvent(event: MouseEvent) -> InputEvent {
        return InputEvent(type: .mouse, mouseEvent: event)
    }
    
    static func trackpadEvent(event: TrackpadEvent) -> InputEvent {
        return InputEvent(type: .trackpad, trackpadEvent: event)
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