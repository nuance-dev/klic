import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var inputManager = InputManager.shared
    @State private var isMinimalMode: Bool = false
    @State private var showWelcomeAlert: Bool = false
    
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
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            // Start monitoring inputs
            inputManager.startMonitoring()
            
            // Load user preferences
            isMinimalMode = UserDefaults.standard.bool(forKey: "minimalMode")
            
            // Check if this is the first launch
            let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            if !hasLaunchedBefore {
                // Show welcome information
                showWelcomeAlert = true
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            }
        }
        .alert("Welcome to Klic!", isPresented: $showWelcomeAlert) {
            Button("OK") {
                showWelcomeAlert = false
            }
        } message: {
            Text("Klic is running in your menu bar. Click the keyboard icon to access settings and see a demo of the app.\n\nYou'll need to grant accessibility permissions for Klic to work properly.")
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 