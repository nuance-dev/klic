import SwiftUI
import AppKit

// Add this comment to indicate we're using the global OverlayPosition
// OverlayPosition is now defined in KlicApp.swift

struct ConfigurationView: View {
    @Binding var opacity: Double
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inputManager = InputManager.shared
    
    // Position settings
    @State private var selectedPosition: String
    @State private var showDemoOverlay: Bool = false
    
    // Theme settings
    @State private var selectedTheme: OverlayTheme = .dark
    
    // Input display options
    @State private var showKeyboardInputs: Bool
    @State private var showMouseInputs: Bool
    @State private var showTrackpadInputs: Bool
    
    // Behavior settings
    @State private var autoHideDelay: Double
    
    @State private var minimalDisplayMode: Bool = UserPreferences.getMinimalDisplayMode()
    
    enum OverlayTheme: String, CaseIterable, Identifiable {
        case dark = "Dark"
        case light = "Light"
        case vibrant = "Vibrant"
        
        var id: String { self.rawValue }
    }
    
    init(opacity: Binding<Double>) {
        self._opacity = opacity
        
        // Initialize state from UserDefaults
        let position = UserDefaults.standard.string(forKey: "overlayPosition") ?? OverlayPosition.bottomCenter.rawValue
        _selectedPosition = State(initialValue: position)
        
        // Default to true if the key doesn't exist
        let keyboardExists = UserDefaults.standard.object(forKey: "showKeyboardInputs") != nil
        let keyboard = UserDefaults.standard.bool(forKey: "showKeyboardInputs")
        _showKeyboardInputs = State(initialValue: keyboardExists ? keyboard : true)
        
        let mouseExists = UserDefaults.standard.object(forKey: "showMouseInputs") != nil
        let mouse = UserDefaults.standard.bool(forKey: "showMouseInputs")
        _showMouseInputs = State(initialValue: mouseExists ? mouse : true)
        
        let trackpadExists = UserDefaults.standard.object(forKey: "showTrackpadInputs") != nil
        let trackpad = UserDefaults.standard.bool(forKey: "showTrackpadInputs")
        _showTrackpadInputs = State(initialValue: trackpadExists ? trackpad : true)
        
        let delay = UserDefaults.standard.double(forKey: "autoHideDelay")
        _autoHideDelay = State(initialValue: delay == 0 ? 1.5 : delay)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                Text("Klic Settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Position section
                    SettingsSectionView(title: "Overlay Position") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(OverlayPosition.allCases) { position in
                                RadioButton(
                                    title: position.rawValue,
                                    subtitle: getPositionDescription(position),
                                    isSelected: selectedPosition == position.rawValue
                                ) {
                                    withAnimation {
                                        selectedPosition = position.rawValue
                                        UserDefaults.standard.set(position.rawValue, forKey: "overlayPosition")
                                        
                                        // Apply position immediately
                                        reconfigureOverlayPosition()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Appearance section
                    SettingsSectionView(title: "Appearance") {
                        VStack(spacing: 20) {
                            // Opacity slider
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Overlay Opacity")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Text("\(Int(opacity * 100))%")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $opacity, in: 0.3...1.0) { editing in
                                    if !editing {
                                        UserDefaults.standard.set(opacity, forKey: "overlayOpacity")
                                        inputManager.setOpacityPreference(opacity)
                                    }
                                }
                                .tint(Color.accentColor)
                            }
                            
                            Divider()
                            
                            // Theme selection (for future feature)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Theme")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Spacer()
                                }
                                
                                Picker("Theme", selection: $selectedTheme) {
                                    ForEach(OverlayTheme.allCases) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: selectedTheme) { old, new in
                                    UserDefaults.standard.set(new.rawValue, forKey: "overlayTheme")
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Show/Hide Section
                    SettingsSectionView(title: "Input Types") {
                        VStack(spacing: 12) {
                            Toggle("Keyboard Inputs", isOn: $showKeyboardInputs)
                                .onChange(of: showKeyboardInputs) { old, new in
                                    UserDefaults.standard.set(new, forKey: "showKeyboardInputs")
                                    updateInputVisibility()
                                }
                            
                            Divider()
                            
                            Toggle("Mouse Inputs", isOn: $showMouseInputs)
                                .onChange(of: showMouseInputs) { old, new in
                                    UserDefaults.standard.set(new, forKey: "showMouseInputs")
                                    updateInputVisibility()
                                }
                            
                            Divider()
                            
                            Toggle("Trackpad Inputs", isOn: $showTrackpadInputs)
                                .onChange(of: showTrackpadInputs) { old, new in
                                    UserDefaults.standard.set(new, forKey: "showTrackpadInputs")
                                    updateInputVisibility()
                                }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Behavior section
                    SettingsSectionView(title: "Behavior") {
                        VStack(spacing: 20) {
                            // Auto-hide delay slider
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Auto-hide Delay")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.1f sec", autoHideDelay))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $autoHideDelay, in: 0.5...5.0, step: 0.5) { editing in
                                    if !editing {
                                        UserDefaults.standard.set(autoHideDelay, forKey: "autoHideDelay")
                                        inputManager.setAutoHideDelay(autoHideDelay)
                                    }
                                }
                                .tint(Color.accentColor)
                            }
                            
                            Divider()
                            
                            // Show demo button
                            Button {
                                showDemoOverlay = true
                                inputManager.showDemoInputs()
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 12))
                                    
                                    Text("Show Demo")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Display Options
                    Section(header: Text("Display Options")) {
                        // Minimal Display Mode Toggle
                        Toggle("Mega Minimal Mode", isOn: $minimalDisplayMode)
                            .onChange(of: minimalDisplayMode) { oldValue, newValue in
                                UserPreferences.setMinimalDisplayMode(newValue)
                            }
                        
                        // ... existing display options ...
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 400, height: 580)
        .background(Material.regular)
        .cornerRadius(12)
        .onChange(of: showDemoOverlay) { oldValue, newValue in
            if !newValue {
                // Reset after demo
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    showDemoOverlay = false
                }
            }
        }
    }
    
    private func getPositionDescription(_ position: OverlayPosition) -> String {
        switch position {
        case .bottomCenter:
            return "Display at the bottom of the screen"
        case .topCenter:
            return "Display at the top of the screen"
        case .expandedNotch:
            return "Integrate with the notch on newer MacBooks"
        }
    }
    
    private func updateInputVisibility() {
        // Set visibility of different input types in the InputManager
        inputManager.setInputTypeVisibility(
            keyboard: showKeyboardInputs,
            mouse: showMouseInputs,
            trackpad: showTrackpadInputs
        )
    }
    
    private func reconfigureOverlayPosition() {
        // Notify that the position changed so window can be reconfigured
        NotificationCenter.default.post(
            name: NSNotification.Name("ReconfigureOverlayPosition"),
            object: nil
        )
    }
}

// Custom section view for consistent styling
struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 2)
            
            VStack {
                content
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(10)
        }
    }
}

// Custom radio button for position selection
struct RadioButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio circle indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// Add static shared instance for easy access from multiple views
extension InputManager {
    static let shared = InputManager()
}

#Preview {
    ConfigurationView(opacity: .constant(0.9))
} 