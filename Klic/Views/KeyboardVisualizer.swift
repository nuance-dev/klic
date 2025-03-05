import SwiftUI

struct KeyboardVisualizer: View {
    let events: [InputEvent]
    
    // Animation states
    @State private var isAnimating = false
    
    // Constants for design consistency
    private let keyPadding: CGFloat = 4
    private let keyCornerRadius: CGFloat = 6
    private let maxKeyCount = 6
    
    // Filtered events to limit display
    private var filteredEvents: [InputEvent] {
        Array(events.prefix(maxKeyCount))
    }
    
    // Keyboard shortcut detection
    private var isShortcut: Bool {
        let hasModifier = filteredEvents.contains { event in
            guard let keyEvent = event.keyboardEvent else { return false }
            return !keyEvent.modifiers.isEmpty
        }
        
        let hasRegularKey = filteredEvents.contains { event in
            guard let keyEvent = event.keyboardEvent else { return false }
            return keyEvent.modifiers.isEmpty && keyEvent.characters?.count == 1
        }
        
        return hasModifier && hasRegularKey
    }
    
    var body: some View {
        HStack(spacing: keyPadding) {
            if isShortcut {
                // Display as shortcut
                ShortcutVisualizer(events: filteredEvents)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // Display individual keys
                ForEach(filteredEvents) { event in
                    if let keyEvent = event.keyboardEvent {
                        KeyCapsuleView(keyEvent: keyEvent)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filteredEvents.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShortcut)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

struct ShortcutVisualizer: View {
    let events: [InputEvent]
    
    private var modifierKeys: [KeyboardEvent] {
        events.compactMap { event in
            guard let keyEvent = event.keyboardEvent, !keyEvent.modifiers.isEmpty else {
                return nil
            }
            return keyEvent
        }
    }
    
    private var regularKeys: [KeyboardEvent] {
        events.compactMap { event in
            guard let keyEvent = event.keyboardEvent, 
                  keyEvent.modifiers.isEmpty, 
                  keyEvent.characters?.count == 1 else {
                return nil
            }
            return keyEvent
        }
    }
    
    private var shortcutText: String {
        var text = ""
        
        // Add modifiers - collect all modifiers into a single set
        var allModifiers = KeyboardEvent.ModifierKeys()
        for keyEvent in modifierKeys {
            allModifiers.formUnion(keyEvent.modifiers)
        }
        
        if allModifiers.contains(.command) { text += "⌘" }
        if allModifiers.contains(.shift) { text += "⇧" }
        if allModifiers.contains(.option) { text += "⌥" }
        if allModifiers.contains(.control) { text += "⌃" }
        
        // Add regular keys
        if let regularKey = regularKeys.first?.characters {
            text += regularKey.uppercased()
        }
        
        return text
    }
    
    var body: some View {
        Text(shortcutText)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    // Background with subtle gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.sRGB, red: 0.2, green: 0.2, blue: 0.25, opacity: 0.9),
                                    Color(.sRGB, red: 0.15, green: 0.15, blue: 0.2, opacity: 0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Subtle highlight at the top
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 1)
                        .offset(y: -7)
                        .blendMode(.plusLighter)
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 2)
    }
}

struct KeyCapsuleView: View {
    let keyEvent: KeyboardEvent
    
    @State private var isPressed = false
    
    private var keyText: String {
        if let char = keyEvent.characters {
            switch char {
            case "\r": return "return"
            case "\t": return "tab"
            case " ": return "space"
            case "\u{1b}": return "esc"
            case "\u{7f}": return "delete"
            default:
                if char.count == 1 {
                    return char.uppercased()
                } else {
                    return char
                }
            }
        } else {
            return "key"
        }
    }
    
    private var isSpecialKey: Bool {
        guard let char = keyEvent.characters else { return false }
        return char == "\r" || char == "\t" || char == " " || char == "\u{1b}" || char == "\u{7f}"
    }
    
    private var isModifierKey: Bool {
        return !keyEvent.modifiers.isEmpty
    }
    
    private var keyColor: Color {
        if isModifierKey {
            return Color(.sRGB, red: 0.3, green: 0.3, blue: 0.35, opacity: 0.9)
        } else if isSpecialKey {
            return Color(.sRGB, red: 0.25, green: 0.25, blue: 0.3, opacity: 0.9)
        } else {
            return Color(.sRGB, red: 0.2, green: 0.2, blue: 0.25, opacity: 0.9)
        }
    }
    
    var body: some View {
        Text(keyText)
            .font(.system(size: isSpecialKey ? 10 : 14, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, isSpecialKey ? 8 : (keyText.count > 1 ? 8 : 10))
            .background(
                ZStack {
                    // Background
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    keyColor,
                                    keyColor.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Subtle highlight at the top
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                        .padding(.horizontal, 1)
                        .offset(y: -6)
                        .blendMode(.plusLighter)
                    
                    // Border
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .onAppear {
                // Animate key press when appearing
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = true
                }
                
                // And then release
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
            }
    }
}

#Preview {
    // Create a few key events for previewing
    let events = [
        InputEvent.keyEvent(
            type: .keyDown,
            keyCode: 55,
            characters: nil,
            modifiers: .command,
            isRepeat: false
        ),
        InputEvent.keyEvent(
            type: .keyDown,
            keyCode: 15,
            characters: "r",
            modifiers: [],
            isRepeat: false
        )
    ]
    
    return ZStack {
        Color.black.opacity(0.5)
        KeyboardVisualizer(events: events)
            .padding()
    }
    .frame(width: 400, height: 200)
} 