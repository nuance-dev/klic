import SwiftUI

// Add a transparent NSView layer that ignores mouse events
struct MouseEventPassthrough: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Make the view pass-through for mouse events
        view.alphaValue = 0.0
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Nothing to update
    }
}

struct InputOverlayView: View {
    @ObservedObject var inputManager: InputManager
    
    // Design constants
    private let containerRadius: CGFloat = 24 // Slightly larger for more premium feel
    private let maximumVisibleKeyboardEvents = 6
    private let overlaySpacing: CGFloat = 16
    private let containerPadding: CGFloat = 14
    
    // Animation states
    @State private var isAppearing = false
    
    // Computed properties to determine what should be shown
    private var shouldShowKeyboard: Bool {
        inputManager.activeInputTypes.contains(.keyboard) && !inputManager.keyboardEvents.isEmpty
    }
    
    private var shouldShowMouse: Bool {
        inputManager.activeInputTypes.contains(.mouse) && !inputManager.mouseEvents.isEmpty
    }
    
    // Filter to limit keyboard events for better display
    private var filteredKeyboardEvents: [InputEvent] {
        Array(inputManager.keyboardEvents.prefix(maximumVisibleKeyboardEvents))
    }
    
    var body: some View {
        ZStack {
            // Add transparent layer that ignores mouse events
            MouseEventPassthrough()
                .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Only show container when there are active inputs to display
                if shouldShowKeyboard || shouldShowMouse {
                    HStack(spacing: overlaySpacing) {
                        // Individual visualizers will only show up when needed
                        
                        // Keyboard visualizer with elegant transitions
                        if shouldShowKeyboard {
                            KeyboardVisualizer(events: filteredKeyboardEvents)
                                .frame(height: 65)
                                .transition(createInsertionTransition())
                                .id("keyboard-\(inputManager.keyboardEvents.count)")
                        }
                        
                        // Mouse visualizer
                        if shouldShowMouse {
                            MouseVisualizer(events: inputManager.mouseEvents)
                                .frame(width: 100, height: 65)
                                .transition(createInsertionTransition())
                                .id("mouse-\(inputManager.mouseEvents.count)")
                        }
                    }
                    .padding(containerPadding)
                    .background(
                        ZStack {
                            // Premium glass effect
                            RoundedRectangle(cornerRadius: containerRadius)
                                .fill(.ultraThinMaterial)
                                .opacity(0.9)
                            
                            // Subtle inner glow
                            RoundedRectangle(cornerRadius: containerRadius)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        }
                    )
                    .cornerRadius(containerRadius)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .opacity(inputManager.overlayOpacity)
                    .transition(.opacity)
                    .allowsHitTesting(false) // Disable hit testing for the container
                }
                
                Spacer().frame(height: 30)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Disable hit testing for the entire view
    }
    
    // Create a more elegant insertion transition
    private func createInsertionTransition() -> AnyTransition {
        let insertion = AnyTransition.scale(scale: 0.95)
            .combined(with: .opacity)
        return insertion
    }
}

// Custom view to create a true blur effect background
struct BlurEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        
        // Add subtle animation to the blur when it appears
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 0.3
        visualEffectView.layer?.add(animation, forKey: "fadeIn")
        
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

// The ConfigurationView is now moved to a separate file since it's accessed from the menu bar

#Preview {
    let inputManager = InputManager()
    inputManager.activeInputTypes = [.keyboard, .mouse]
    return InputOverlayView(inputManager: inputManager)
        .environmentObject(inputManager)
} 