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

/// The main input event model that encapsulates all types of input events
struct InputEvent: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    
    // Event-specific data
    let keyboardEvent: KeyboardEvent?
    let mouseEvent: MouseEvent?
    
    enum EventType {
        case keyboard
        case mouse
    }
    
    // Factory method for keyboard events
    static func keyboardEvent(event: KeyboardEvent) -> InputEvent {
        return InputEvent(
            id: UUID(),
            timestamp: Date(),
            type: .keyboard,
            keyboardEvent: event,
            mouseEvent: nil
        )
    }
    
    // Factory method for mouse events
    static func mouseEvent(event: MouseEvent) -> InputEvent {
        return InputEvent(
            id: UUID(),
            timestamp: Date(),
            type: .mouse,
            keyboardEvent: nil,
            mouseEvent: event
        )
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