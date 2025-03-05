import SwiftUI

struct InputOverlayView: View {
    @ObservedObject var inputManager: InputManager
    @EnvironmentObject var trackpadMonitor: TrackpadMonitor
    
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
    
    private var shouldShowTrackpad: Bool {
        inputManager.activeInputTypes.contains(.trackpad) && 
        (!inputManager.trackpadEvents.isEmpty || !trackpadMonitor.rawTouches.isEmpty)
    }
    
    private var shouldShowMouse: Bool {
        inputManager.activeInputTypes.contains(.mouse) && !inputManager.mouseEvents.isEmpty
    }
    
    // Filter to limit keyboard events for better display
    private var filteredKeyboardEvents: [InputEvent] {
        Array(inputManager.keyboardEvents.prefix(maximumVisibleKeyboardEvents))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Only show container when there are active inputs to display
            if shouldShowKeyboard || shouldShowTrackpad || shouldShowMouse {
                HStack(spacing: overlaySpacing) {
                    // Individual visualizers will only show up when needed
                    
                    // Keyboard visualizer with elegant transitions
                    if shouldShowKeyboard {
                        KeyboardVisualizer(events: filteredKeyboardEvents)
                            .frame(height: 65)
                            .transition(createInsertionTransition())
                            .id("keyboard-\(inputManager.keyboardEvents.count)")
                    }
                    
                    // Trackpad visualizer with improved look
                    if shouldShowTrackpad {
                        TrackpadVisualizer(
                            events: inputManager.trackpadEvents,
                            trackpadSize: CGSize(width: 100, height: 72),
                            trackpadMonitor: trackpadMonitor
                        )
                        .frame(width: 100, height: 72)
                        .transition(createInsertionTransition())
                        .id("trackpad-\(inputManager.trackpadEvents.count + trackpadMonitor.rawTouches.count)")
                    }
                    
                    // Mouse visualizer
                    if shouldShowMouse {
                        MouseVisualizer(events: inputManager.mouseEvents)
                            .frame(width: 100, height: 72)
                            .transition(createInsertionTransition())
                            .id("mouse-\(inputManager.mouseEvents.count)")
                    }
                }
                .padding(containerPadding)
                .background(
                    ZStack {
                        // Modern glass blur effect - use .hudWindow material for better macOS 15.2 support
                        BlurEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .cornerRadius(containerRadius)
                        
                        // Premium dark background with subtle gradient
                        RoundedRectangle(cornerRadius: containerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(.sRGB, red: 0.11, green: 0.11, blue: 0.13, opacity: 0.70),
                                        Color(.sRGB, red: 0.07, green: 0.07, blue: 0.09, opacity: 0.70)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Subtle inner glow at the top
                        RoundedRectangle(cornerRadius: containerRadius)
                            .trim(from: 0, to: 0.5)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .padding(0.5)
                            .blendMode(.plusLighter)
                        
                        // Subtle border
                        RoundedRectangle(cornerRadius: containerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.07),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                )
                .compositingGroup()
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 15,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isAppearing ? 1.0 : 0.95)
                .opacity(isAppearing ? inputManager.overlayOpacity : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: inputManager.activeInputTypes)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAppearing)
                .padding(.bottom, 24)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom)),
                    removal: .opacity.animation(.easeOut(duration: 0.2))
                ))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: shouldShowKeyboard)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: shouldShowTrackpad)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: shouldShowMouse)
        .onAppear {
            // Trigger appearance animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAppearing = true
            }
        }
        .onDisappear {
            isAppearing = false
        }
    }
    
    // Helper function to create consistent insertion transitions
    private func createInsertionTransition() -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .center))
                .animation(.spring(response: 0.3, dampingFraction: 0.7)),
            removal: .opacity.animation(.easeOut(duration: 0.2))
        )
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
    inputManager.activeInputTypes = [.keyboard, .trackpad]
    return InputOverlayView(inputManager: inputManager)
        .environmentObject(inputManager)
} 