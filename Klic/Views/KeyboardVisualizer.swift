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
        // We need to have at least one modifier key AND one regular key
        let hasModifier = filteredEvents.contains { event in
            guard let keyEvent = event.keyboardEvent else { return false }
            // Count either explicit modifiers list or actual modifier keys
            return !keyEvent.modifiers.isEmpty || keyEvent.isModifierKey
        }
        
        let hasRegularKey = filteredEvents.contains { event in
            guard let keyEvent = event.keyboardEvent else { return false }
            // Regular keys are ones that aren't modifiers themselves and are down
            return !keyEvent.isModifierKey && keyEvent.isDown
        }
        
        // Only consider as shortcut if we have both parts
        return hasModifier && hasRegularKey
    }
    
    @State private var isMinimalMode: Bool = false
    
    var body: some View {
        // Check for minimal mode on appearance
        let _ = onAppear {
            isMinimalMode = UserPreferences.getMinimalDisplayMode()
            
            // Listen for minimal mode changes
            NotificationCenter.default.addObserver(
                forName: .MinimalDisplayModeChanged,
                object: nil,
                queue: .main
            ) { _ in
                isMinimalMode = UserPreferences.getMinimalDisplayMode()
            }
        }
        
        if events.isEmpty {
            EmptyView()
        } else {
            if isMinimalMode {
                minimalKeyboardView
            } else {
                standardKeyboardView
            }
        }
    }
    
    // Standard keyboard visualization
    private var standardKeyboardView: some View {
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
    
    // Minimal keyboard visualization
    private var minimalKeyboardView: some View {
        HStack(spacing: 2) {
            if isShortcut {
                // Display as minimal shortcut
                minimalShortcutView
            } else {
                // Display individual keys (max 3 in minimal mode)
                ForEach(filteredEvents.prefix(3)) { event in
                    if let keyEvent = event.keyboardEvent {
                        minimalKeyView(keyEvent: keyEvent)
                    }
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.5))
        .cornerRadius(4)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: filteredEvents.count)
    }
    
    // Minimal key view
    private func minimalKeyView(keyEvent: KeyboardEvent) -> some View {
        let keyText = getKeyText(keyEvent)
        
        return Text(keyText)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.sRGB, red: 0.2, green: 0.2, blue: 0.25, opacity: 0.9))
            )
    }
    
    // Minimal shortcut view
    private var minimalShortcutView: some View {
        let shortcutText = getShortcutText()
        
        return Text(shortcutText)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.sRGB, red: 0.2, green: 0.2, blue: 0.25, opacity: 0.9))
            )
    }
    
    // Helper to get key text
    private func getKeyText(_ keyEvent: KeyboardEvent) -> String {
        if let char = keyEvent.characters {
            switch char {
            case "\r": return "↩"
            case "\t": return "⇥"
            case " ": return "␣"
            case "\u{1b}": return "⎋"
            case "\u{7f}": return "⌫"
            default:
                if char.count == 1 {
                    return char.uppercased()
                } else {
                    return char
                }
            }
        } else {
            return "•"
        }
    }
    
    // Helper to get shortcut text
    private func getShortcutText() -> String {
        var text = ""
        
        // First collect all currently active modifiers
        var activeModifiers: Set<KeyModifier> = []
        
        // Find active modifier keys that are currently DOWN
        for event in filteredEvents {
            if let keyEvent = event.keyboardEvent, keyEvent.isDown {
                // Add explicit modifiers
                if !keyEvent.modifiers.isEmpty {
                    activeModifiers.formUnion(keyEvent.modifiers)
                }
                
                // Add the key itself if it's a modifier key
                if keyEvent.isModifierKey {
                    if let mod = KeyModifier.allCases.first(where: { $0.keyCode == keyEvent.keyCode }) {
                        activeModifiers.insert(mod)
                    }
                }
            }
        }
        
        // Process modifiers in standard order
        let orderedModifiers: [KeyModifier] = [.control, .option, .shift, .command]
        for modifier in orderedModifiers {
            if activeModifiers.contains(modifier) {
                switch modifier {
                case .command: text += "⌘"
                case .shift: text += "⇧" 
                case .option: text += "⌥"
                case .control: text += "⌃"
                case .function: text += "fn"
                case .capsLock: text += "⇪"
                }
            }
        }
        
        // Find the most recent non-modifier key that is DOWN
        // Important: Use timestamp to ensure we get the latest key
        var latestKeyEvent: (event: InputEvent, keyEvent: KeyboardEvent)? = nil
        
        for event in filteredEvents {
            if let keyEvent = event.keyboardEvent,
               !keyEvent.isModifierKey,
               keyEvent.isDown {
                // Only update if we don't have one yet or this one is more recent
                if latestKeyEvent == nil || event.timestamp > latestKeyEvent!.event.timestamp {
                    latestKeyEvent = (event, keyEvent)
                }
            }
        }
        
        // If we found a non-modifier key, add it
        if let (_, keyEvent) = latestKeyEvent {
            // Special key representation
            if let key = keyEvent.characters {
                switch key {
                case "\r": text += "↩" // return
                case "\t": text += "⇥" // tab
                case " ": text += "Space"
                case "\u{1b}": text += "Esc"
                case "\u{7f}": text += "⌫" // delete/backspace
                default:
                    // For single character keys, use uppercase
                    if key.count == 1 {
                        text += key.uppercased()
                    } else {
                        text += key
                    }
                }
            } else {
                // Fallback for keys with no character representation
                text += keyEvent.key
            }
        }
        
        return text
    }
    
    // Helper to check if a key event is part of a shortcut
    private func isShortcut(_ keyEvent: KeyboardEvent) -> Bool {
        return !keyEvent.modifiers.isEmpty
    }
}

struct ShortcutVisualizer: View {
    let events: [InputEvent]
    
    private var modifierKeys: [KeyboardEvent] {
        events.compactMap { event in
            guard let keyEvent = event.keyboardEvent else {
                return nil
            }
            // Consider a key as a modifier if it has modifiers OR it's a modifier key itself
            if !keyEvent.modifiers.isEmpty || keyEvent.isModifierKey {
                return keyEvent
            }
            return nil
        }
    }
    
    private var regularKeys: [KeyboardEvent] {
        events.compactMap { event in
            guard let keyEvent = event.keyboardEvent else {
                return nil
            }
            // A regular key is one that is not a modifier key itself and is being pressed
            if !keyEvent.isModifierKey && keyEvent.isDown {
                return keyEvent
            }
            return nil
        }
    }
    
    private var shortcutText: String {
        var text = ""
        
        // Add modifiers - collect all modifiers into a single set
        var allModifiers: Set<KeyModifier> = []
        
        // First add modifiers from modifier keys
        for keyEvent in modifierKeys {
            allModifiers.formUnion(keyEvent.modifiers)
            
            // Also check if the key itself is a modifier key (e.g., Command, Shift)
            if keyEvent.isModifierKey {
                // Map key code to modifier
                for modifier in KeyModifier.allCases {
                    if modifier.keyCode == keyEvent.keyCode {
                        allModifiers.insert(modifier)
                    }
                }
            }
        }
        
        // Sort modifiers in the standard order: Ctrl, Option, Shift, Command
        let sortedModifiers = allModifiers.sorted { (a, b) -> Bool in
            let order: [KeyModifier] = [.control, .option, .shift, .command]
            return order.firstIndex(of: a) ?? 0 < order.firstIndex(of: b) ?? 0
        }
        
        // Add the modifiers in sorted order
        for modifier in sortedModifiers {
            switch modifier {
            case .command: text += "⌘"
            case .shift: text += "⇧"
            case .option: text += "⌥"
            case .control: text += "⌃"
            case .function: text += "fn"
            case .capsLock: text += "⇪"
            }
        }
        
        // Add regular keys
        if let regularKey = regularKeys.first {
            if regularKey.key.count == 1 {
                text += regularKey.key.uppercased()
            } else {
                text += regularKey.key
            }
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
    let commandEvent = KeyboardEvent(
        key: "⌘",
        keyCode: 55,
        isDown: true,
        modifiers: [.command],
        characters: nil,
        isRepeat: false
    )
    
    let rEvent = KeyboardEvent(
        key: "R",
        keyCode: 15,
        isDown: true,
        modifiers: [.command],
        characters: "r",
        isRepeat: false
    )
    
    let events = [
        InputEvent.keyboardEvent(event: commandEvent),
        InputEvent.keyboardEvent(event: rEvent)
    ]
    
    return KeyboardVisualizer(events: events)
        .frame(width: 500, height: 300)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
} 