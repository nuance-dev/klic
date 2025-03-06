import SwiftUI

struct TrackpadVisualizer: View {
    let events: [InputEvent]
    @State private var isMinimalMode = true
    
    var body: some View {
        VStack {
            if let trackpadEvent = events.first?.trackpadEvent {
                if trackpadEvent.gestureType == .magnify || trackpadEvent.gestureType == .rotate {
                    // Only show visualization for magnify and rotate gestures, not for scroll/pan
                    minimalTrackpadView
                        .onAppear {
                            // Always ensure minimal mode is enabled
                            isMinimalMode = true
                            
                            // Listen for minimal mode changes
                            NotificationCenter.default.addObserver(
                                forName: .MinimalDisplayModeChanged,
                                object: nil,
                                queue: .main
                            ) { _ in
                                isMinimalMode = UserPreferences.getMinimalDisplayMode()
                            }
                        }
                }
            }
        }
    }
    
    // Simple view showing just the essential gesture info
    private var minimalTrackpadView: some View {
        VStack(spacing: 8) {
            if let trackpadEvent = events.first?.trackpadEvent {
                if trackpadEvent.gestureType == .magnify {
                    MinimalMagnifyGestureVisualizer(value: Float(trackpadEvent.value), fingerCount: trackpadEvent.fingerCount)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if trackpadEvent.gestureType == .rotate {
                    MinimalRotateGestureVisualizer(value: Float(trackpadEvent.value), fingerCount: trackpadEvent.fingerCount)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .padding(10)
        .background(
            ZStack {
                // Modern, subtle glass effect background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Material.ultraThinMaterial)
                    )
            }
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
    }
}

// Modern minimal magnify gesture visualizer
struct MinimalMagnifyGestureVisualizer: View {
    let value: Float
    let fingerCount: Int
    
    @State private var animateScale = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Modern visualization using circles
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                
                // Dynamic circles showing zoom level
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: min(32 * CGFloat(value), 28), height: min(32 * CGFloat(value), 28))
                    .scaleEffect(animateScale ? 1.0 : 0.8)
            }
            .frame(width: 40, height: 40)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                    animateScale = true
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Pinch")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Text(String(format: "%.1f×", abs(value)))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Finger count indicator
            Text("\(fingerCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }
}

// Modern minimal rotate gesture visualizer
struct MinimalRotateGestureVisualizer: View {
    let value: Float
    let fingerCount: Int
    
    @State private var rotation = 0.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Modern rotation visualization
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                
                // Rotation indicator
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1.5, height: 12)
                    .offset(y: -8)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: 40, height: 40)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                    rotation = Double(value)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Rotate")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Text(String(format: "%.1f°", abs(value)))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Finger count indicator
            Text("\(fingerCount)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }
}

// MARK: Preview
struct TrackpadVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                TrackpadVisualizer(events: [InputEvent.trackpadEvent(event: TrackpadEvent(timestamp: Date(), gestureType: .magnify, value: 1.5, fingerCount: 2, state: .changed))])
                
                TrackpadVisualizer(events: [InputEvent.trackpadEvent(event: TrackpadEvent(timestamp: Date(), gestureType: .rotate, value: 45.0, fingerCount: 2, state: .changed))])
            }
        }
        .frame(width: 300, height: 300)
    }
} 