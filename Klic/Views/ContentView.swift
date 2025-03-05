import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var inputManager = InputManager.shared
    @State private var isMinimalMode: Bool = false
    @State private var showSettings: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            Color.clear
                .ignoresSafeArea()
            
            // Input visualizers
            VStack(spacing: 12) {
                // Keyboard visualizer
                if !inputManager.keyboardEvents.isEmpty {
                    KeyboardVisualizer(events: inputManager.keyboardEvents)
                        .padding(.horizontal, isMinimalMode ? 8 : 16)
                }
                
                // Mouse visualizer
                if !inputManager.mouseEvents.isEmpty {
                    MouseVisualizer(events: inputManager.mouseEvents)
                        .padding(.horizontal, isMinimalMode ? 8 : 16)
                }
                
                // Trackpad visualizer
                if !inputManager.trackpadEvents.isEmpty {
                    TrackpadVisualizer(events: inputManager.trackpadEvents)
                        .padding(.horizontal, isMinimalMode ? 8 : 16)
                }
            }
            .padding(.vertical, 16)
            
            // Settings button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(8)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(16)
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isMinimalMode: $isMinimalMode)
                .frame(width: 400, height: 300)
        }
        .onAppear {
            // Start monitoring inputs
            inputManager.startAllMonitors()
            
            // Load user preferences
            isMinimalMode = UserDefaults.standard.bool(forKey: "minimalMode")
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Binding var isMinimalMode: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding(.top, 20)
            
            Form {
                Section(header: Text("Display Options")) {
                    Toggle("Minimal Mode", isOn: $isMinimalMode)
                        .onChange(of: isMinimalMode) { oldValue, newValue in
                            UserDefaults.standard.set(newValue, forKey: "minimalMode")
                        }
                }
                
                Section(header: Text("Input Monitoring")) {
                    Button("Restart Input Monitoring") {
                        InputManager.shared.startAllMonitors()
                    }
                }
            }
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 