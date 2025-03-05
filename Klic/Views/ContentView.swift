import SwiftUI

struct ContentView: View {
    @EnvironmentObject var inputManager: InputManager
    @State private var showDebugInfo: Bool = false
    
    var body: some View {
        ZStack {
            // Transparent background - ensure it fully clears the window
            Color.clear
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Input overlay - only show when there's active input
            if inputManager.isOverlayVisible {
                InputOverlayView(inputManager: inputManager)
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: inputManager.isOverlayVisible)
                    // Pass the trackpad monitor to the overlay view
                    .environmentObject(inputManager.sharedTrackpadMonitor)
            }
            
            // Debug view - only visible in development and only when activated via keyboard shortcut
            #if DEBUG
            VStack {
                if showDebugInfo {
                    StatusView(inputManager: inputManager)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.sRGB, red: 0.05, green: 0.05, blue: 0.06, opacity: 0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showDebugInfo)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding()
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Verify input monitoring is active when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkInputStatus()
            }
        }
        // Add keyboard shortcut to toggle debug info (Cmd+Opt+D)
        .keyboardShortcut("d", modifiers: [.command, .option])
        .onExitCommand {
            showDebugInfo.toggle()
        }
    }
    
    private func checkInputStatus() {
        if !inputManager.checkMonitoringStatus() {
            Logger.info("Input monitors not active, attempting to restart", log: Logger.app)
            inputManager.restartMonitoring()
        }
    }
}

/// Status view for showing monitoring status (debug only)
struct StatusView: View {
    @ObservedObject var inputManager: InputManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Klic Debug Status")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 3)
            
            Group {
                StatusRow(label: "Overlay Visible", value: inputManager.isOverlayVisible ? "Yes" : "No")
                StatusRow(label: "Opacity", value: String(format: "%.1f", inputManager.overlayOpacity))
                StatusRow(label: "Active Input Types", value: inputManager.activeInputTypes.map { $0.description }.joined(separator: ", "))
                StatusRow(label: "Active Events", value: "\(inputManager.allEvents.count)")
                StatusRow(label: "Keyboard Events", value: "\(inputManager.keyboardEvents.count)")
                StatusRow(label: "Mouse Events", value: "\(inputManager.mouseEvents.count)")
                StatusRow(label: "Trackpad Events", value: "\(inputManager.trackpadEvents.count)")
                StatusRow(label: "Raw Touches", value: "\(inputManager.sharedTrackpadMonitor.rawTouches.count)")
            }
        }
        .font(.system(size: 10))
        .frame(width: 200)
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
        }
        .padding(.vertical, 2)
    }
}

// Extension to make InputType description more readable
extension InputManager.InputType: CustomStringConvertible {
    var description: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .mouse: return "Mouse"
        case .trackpad: return "Trackpad"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(InputManager())
} 