import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var inputManager = InputManager.shared
    @State private var isMinimalMode: Bool = false
    
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
        }
        .onAppear {
            // Start monitoring inputs
            inputManager.startAllMonitors()
            
            // Load user preferences
            isMinimalMode = UserDefaults.standard.bool(forKey: "minimalMode")
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 