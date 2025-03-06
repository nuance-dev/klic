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
            return keyEvent.modifiers != 0 || keyEvent.isModifierKey
        }
        
        let hasRegularKey = filteredEvents.contains { event in
            guard let keyEvent = event.keyboardEvent else { return false }
            // Regular keys are ones that aren't modifiers themselves and are down
            return !keyEvent.isModifierKey && keyEvent.isKeyDown
        }
        
        // Only consider as shortcut if we have both parts
        return hasModifier && hasRegularKey
    }
    
    // Modified shortcut detection to also display standalone modifier keys
    private var shouldDisplayAsShortcut: Bool {
        // If we have the standard shortcut scenario (modifier+key), return true
        if isShortcut {
            return true
        }
        
        // If we have only modifier keys but no regular keys, we should still display them
        let onlyModifiers = filteredEvents.allSatisfy { event in
            guard let keyEvent = event.keyboardEvent else { return true }
            return keyEvent.isModifierKey
        }
        
        return !filteredEvents.isEmpty && onlyModifiers
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
            if shouldDisplayAsShortcut {
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shouldDisplayAsShortcut)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
    
    // Minimal keyboard visualization
    private var minimalKeyboardView: some View {
        HStack(spacing: 2) {
            if shouldDisplayAsShortcut {
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
        let char = keyEvent.keyChar
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
    }
    
    // Helper to get shortcut text
    private func getShortcutText() -> String {
        var text = ""
        
        // First collect all currently active modifiers
        var activeModifiers: Set<KeyModifier> = []
        
        // Find active modifier keys that are currently DOWN
        for event in filteredEvents {
            if let keyEvent = event.keyboardEvent, keyEvent.isKeyDown {
                // Add explicit modifiers
                if keyEvent.modifiers != 0 {
                    // Instead of formUnion, we'll just set activeModifiers directly
                    // We need to convert modifiers from UInt to a Set of modifier keys
                    if (keyEvent.modifiers & NSEvent.ModifierFlags.command.rawValue) != 0 {
                        activeModifiers.insert(.command)
                    }
                    if (keyEvent.modifiers & NSEvent.ModifierFlags.shift.rawValue) != 0 {
                        activeModifiers.insert(.shift)
                    }
                    if (keyEvent.modifiers & NSEvent.ModifierFlags.option.rawValue) != 0 {
                        activeModifiers.insert(.option)
                    }
                    if (keyEvent.modifiers & NSEvent.ModifierFlags.control.rawValue) != 0 {
                        activeModifiers.insert(.control)
                    }
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
               keyEvent.isKeyDown {
                // Only update if we don't have one yet or this one is more recent
                if latestKeyEvent == nil || event.timestamp > latestKeyEvent!.event.timestamp {
                    latestKeyEvent = (event, keyEvent)
                }
            }
        }
        
        // If we found a non-modifier key, add it
        if let (_, keyEvent) = latestKeyEvent {
            // Special key representation
            let keyCharValue = keyEvent.keyChar
            if !keyCharValue.isEmpty {
                switch keyCharValue {
                case "\r": text += "↩" // return
                case "\t": text += "⇥" // tab
                case " ": text += "Space"
                case "\u{1b}": text += "Esc"
                case "\u{7f}": text += "⌫" // delete/backspace
                default:
                    // For single character keys, use uppercase
                    if keyCharValue.count == 1 {
                        text += keyCharValue.uppercased()
                    } else {
                        text += keyCharValue
                    }
                }
            } else {
                // Fallback for keys with no character representation
                text += "Key \(keyEvent.keyCode)"
            }
        }
        
        return text
    }
    
    // Helper to check if a key event is part of a shortcut
    private func isShortcut(_ keyEvent: KeyboardEvent) -> Bool {
        return keyEvent.modifiers != 0
    }
    
    private func getModifierEvent() -> KeyboardEvent {
        for event in filteredEvents {
            if let keyEvent = event.keyboardEvent, keyEvent.isModifierKey {
                return keyEvent
            }
        }
        // Return a default KeyboardEvent instead of nil
        return KeyboardEvent(id: UUID(), timestamp: Date(), keyCode: 0, keyChar: "", isKeyDown: false, isRepeat: false, modifiers: 0)
    }

    private func getRegularKeyEvent() -> KeyboardEvent {
        for event in filteredEvents {
            if let keyEvent = event.keyboardEvent, !keyEvent.isModifierKey, keyEvent.isKeyDown {
                return keyEvent
            }
        }
        // Return a default KeyboardEvent instead of nil
        return KeyboardEvent(id: UUID(), timestamp: Date(), keyCode: 0, keyChar: "", isKeyDown: false, isRepeat: false, modifiers: 0)
    }
    
    private func getAllModifiers() -> Set<KeyModifier> {
        var allModifiers = Set<KeyModifier>()
        
        for event in filteredEvents {
            if let keyEvent = event.keyboardEvent {
                // Convert UInt modifiers to Set<KeyModifier>
                if (keyEvent.modifiers & NSEvent.ModifierFlags.command.rawValue) != 0 {
                    allModifiers.insert(.command)
                }
                if (keyEvent.modifiers & NSEvent.ModifierFlags.shift.rawValue) != 0 {
                    allModifiers.insert(.shift)
                }
                if (keyEvent.modifiers & NSEvent.ModifierFlags.option.rawValue) != 0 {
                    allModifiers.insert(.option)
                }
                if (keyEvent.modifiers & NSEvent.ModifierFlags.control.rawValue) != 0 {
                    allModifiers.insert(.control)
                }
            }
        }
        
        return allModifiers
    }
    
    private func formatShortcutText() -> String {
        var text = ""
        let modifiers = getAllModifiers()
        
        // Add modifier symbols
        if modifiers.contains(.command) {
            text += "⌘"
        }
        if modifiers.contains(.shift) {
            text += "⇧"
        }
        if modifiers.contains(.option) {
            text += "⌥"
        }
        if modifiers.contains(.control) {
            text += "⌃"
        }
        
        // Add the regular key
        let regularKey = getRegularKeyEvent()
        if regularKey.keyChar.count == 1 {
            text += regularKey.keyChar.uppercased()
        } else {
            text += regularKey.keyChar
        }
        
        return text
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
            if keyEvent.modifiers != 0 || keyEvent.isModifierKey {
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
            if !keyEvent.isModifierKey && keyEvent.isKeyDown {
                return keyEvent
            }
            return nil
        }
    }
    
    private var shortcutText: String {
        var text = ""
        
        // Add modifiers - collect all modifiers into a single set
        var allModifiers: Set<KeyModifier> = []
        
        // First add modifiers from modifier keys themselves
        for keyEvent in modifierKeys where keyEvent.isModifierKey {
            if let mod = KeyModifier.allCases.first(where: { $0.keyCode == keyEvent.keyCode }) {
                allModifiers.insert(mod)
            }
        }
        
        // Then add modifiers from the modifier flags
        for keyEvent in modifierKeys {
            // Convert UInt modifiers to Set<KeyModifier>
            if (keyEvent.modifiers & NSEvent.ModifierFlags.command.rawValue) != 0 {
                allModifiers.insert(.command)
            }
            if (keyEvent.modifiers & NSEvent.ModifierFlags.shift.rawValue) != 0 {
                allModifiers.insert(.shift)
            }
            if (keyEvent.modifiers & NSEvent.ModifierFlags.option.rawValue) != 0 {
                allModifiers.insert(.option)
            }
            if (keyEvent.modifiers & NSEvent.ModifierFlags.control.rawValue) != 0 {
                allModifiers.insert(.control)
            }
        }
        
        // Sort modifiers in the standard order: Ctrl, Option, Shift, Command
        let sortedModifiers = allModifiers.sorted { (a, b) -> Bool in
            let order: [KeyModifier] = [.control, .option, .shift, .command]
            guard let aIndex = order.firstIndex(of: a),
                  let bIndex = order.firstIndex(of: b) else {
                // Handle non-standard modifiers
                return a.rawValue < b.rawValue
            }
            return aIndex < bIndex
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
        
        // Only add regular keys if we have any
        if let regularKey = regularKeys.first {
            if regularKey.keyChar.count == 1 {
                text += regularKey.keyChar.uppercased()
            } else {
                text += regularKey.keyChar
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
        let char = keyEvent.keyChar
        switch char {
        case "\r": return "return"
        case "\t": return "tab"
        case " ": return "space"
        case "\u{1b}": return "escape"
        case "\u{7f}": return "delete"
        case "⌘": return "command"
        case "⇧": return "shift"
        case "⌥": return "option"
        case "⌃": return "control"
        case "fn": return "function"
        case "⇪": return "caps lock"
        default: return char
        }
    }
    
    private var keySymbol: String {
        let char = keyEvent.keyChar
        switch char {
        case "\r": return "↩"
        case "\t": return "⇥"
        case " ": return "␣"
        case "\u{1b}": return "⎋"
        case "\u{7f}": return "⌫"
        case "⌘": return "⌘"
        case "⇧": return "⇧"
        case "⌥": return "⌥"
        case "⌃": return "⌃"
        case "fn": return "fn"
        case "⇪": return "⇪"
        default: 
            if char.count == 1 {
                return char.uppercased()
            } else {
                return char
            }
        }
    }
    
    private var isSpecialKey: Bool {
        let char = keyEvent.keyChar
        return char == "\r" || char == "\t" || char == " " || char == "\u{1b}" || char == "\u{7f}"
    }
    
    private var isModifierKey: Bool {
        return keyEvent.isModifierKey
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
        HStack(spacing: 4) {
            Text(keySymbol)
                .font(.system(size: isSpecialKey || isModifierKey ? 12 : 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, (isSpecialKey || isModifierKey) ? 8 : 10)
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
        id: UUID(),
        timestamp: Date(),
        keyCode: 55,
        keyChar: "⌘",
        isKeyDown: true,
        isRepeat: false,
        modifiers: 0
    )
    
    let rEvent = KeyboardEvent(
        id: UUID(),
        timestamp: Date(),
        keyCode: 15,
        keyChar: "R",
        isKeyDown: true,
        isRepeat: false,
        modifiers: 256 // Command modifier
    )
    
    let events = [
        InputEvent.keyboardEvent(event: commandEvent),
        InputEvent.keyboardEvent(event: rEvent)
    ]
    
    KeyboardVisualizer(events: events)
} 