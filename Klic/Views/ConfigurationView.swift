import SwiftUI
import AppKit

// Add this comment to indicate we're using the global OverlayPosition
// OverlayPosition is now defined in KlicApp.swift

struct ConfigurationView: View {
    @Binding var opacity: Double
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inputManager = InputManager.shared
    
    // Theme settings
    @State private var selectedTheme: OverlayTheme = .dark
    
    // Input display options
    @State private var showKeyboardInputs: Bool
    @State private var showMouseInputs: Bool
    
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
        
        // Default to true if the key doesn't exist
        let keyboardExists = UserDefaults.standard.object(forKey: "showKeyboardInputs") != nil
        let keyboard = UserDefaults.standard.bool(forKey: "showKeyboardInputs")
        _showKeyboardInputs = State(initialValue: keyboardExists ? keyboard : true)
        
        let mouseExists = UserDefaults.standard.object(forKey: "showMouseInputs") != nil
        let mouse = UserDefaults.standard.bool(forKey: "showMouseInputs")
        _showMouseInputs = State(initialValue: mouseExists ? mouse : true)
        
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
                    // Appearance section
                    SettingsSectionView(title: "Appearance") {
                        VStack(spacing: 16) {
                            // Opacity slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Overlay Opacity")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Spacer()
                                    
                                    Text("\(Int(opacity * 100))%")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Slider(value: $opacity, in: 0.3...1.0) { editing in
                                        if !editing {
                                            // Save the opacity preference
                                            UserPreferences.setOverlayOpacity(opacity)
                                            
                                            // Update the input manager
                                            inputManager.updateOpacity(opacity)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            // Minimal display mode toggle
                            Toggle(isOn: $minimalDisplayMode) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Minimal Display Mode")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Text("Show only essential information")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                            .onChange(of: minimalDisplayMode) { oldValue, newValue in
                                UserPreferences.setMinimalDisplayMode(newValue)
                            }
                        }
                    }
                    
                    // Input Types section
                    SettingsSectionView(title: "Input Types") {
                        VStack(spacing: 12) {
                            // Keyboard toggle
                            Toggle(isOn: $showKeyboardInputs) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Keyboard")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Text("Show keyboard shortcuts and key presses")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                            .onChange(of: showKeyboardInputs) { oldValue, newValue in
                                UserPreferences.setShowKeyboardInput(newValue)
                                updateInputVisibility()
                            }
                            
                            Divider()
                            
                            // Mouse toggle
                            Toggle(isOn: $showMouseInputs) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Mouse")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Text("Show mouse clicks and movements")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                            .onChange(of: showMouseInputs) { oldValue, newValue in
                                UserPreferences.setShowMouseInput(newValue)
                                updateInputVisibility()
                            }
                        }
                    }
                    
                    // Behavior section
                    SettingsSectionView(title: "Behavior") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Auto-hide Delay")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Spacer()
                                
                                Text("\(String(format: "%.1f", autoHideDelay))s")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $autoHideDelay, in: 0.5...5.0, step: 0.5) { editing in
                                if !editing {
                                    // Save the auto-hide delay preference
                                    UserPreferences.setAutoHideDelay(autoHideDelay)
                                    
                                    // Update the input manager
                                    inputManager.setAutoHideDelay(autoHideDelay)
                                }
                            }
                        }
                    }
                    
                    // Demo section
                    SettingsSectionView(title: "Demo") {
                        Button {
                            // Show demo overlay
                            inputManager.showDemoMode()
                        } label: {
                            HStack {
                                Text("Show Demo Overlay")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16))
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private func updateInputVisibility() {
        // Set visibility of different input types in the InputManager
        inputManager.setInputTypeVisibility(
            keyboard: showKeyboardInputs,
            mouse: showMouseInputs
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