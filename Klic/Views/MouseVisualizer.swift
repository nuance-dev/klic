import SwiftUI

struct MouseVisualizer: View {
    let events: [InputEvent]
    
    // Animation states
    @State private var isAnimating = false
    @State private var pulseOpacity: Double = 0
    
    // Get the latest mouse events of each type
    private var clickEvents: [InputEvent] {
        events.filter { $0.type == .mouseDown }
    }
    
    private var moveEvents: [InputEvent] {
        events.filter { $0.type == .mouseMove }
    }
    
    private var scrollEvents: [InputEvent] {
        events.filter { $0.type == .mouseScroll }
    }
    
    private var latestClickEvent: InputEvent? {
        clickEvents.first
    }
    
    private var latestScrollEvent: InputEvent? {
        scrollEvents.first
    }
    
    private var mouseActionType: MouseActionType {
        if let clickEvent = latestClickEvent, let mouseEvent = clickEvent.mouseEvent {
            return .click(button: mouseEvent.button ?? .left)
        } else if let scrollEvent = latestScrollEvent, let mouseEvent = scrollEvent.mouseEvent, let delta = mouseEvent.scrollDelta {
            // Determine primary scroll direction
            if abs(delta.y) > abs(delta.x) {
                return delta.y > 0 ? .scroll(direction: .down) : .scroll(direction: .up)
            } else {
                return delta.x > 0 ? .scroll(direction: .right) : .scroll(direction: .left)
            }
        } else if !moveEvents.isEmpty {
            return .move
        }
        
        return .none
    }
    
    // Enum to track mouse action types
    enum MouseActionType: Equatable {
        case click(button: MouseEvent.MouseButton)
        case scroll(direction: ScrollDirection)
        case move
        case none
        
        enum ScrollDirection: Equatable {
            case up
            case down
            case left
            case right
        }
    }
    
    var body: some View {
        ZStack {
            // Only show content when there are events
            if !events.isEmpty {
                // Dynamic content based on mouse action
                Group {
                    switch mouseActionType {
                    case .click(let button):
                        MouseClickView(button: button, isAnimating: isAnimating)
                            
                    case .scroll(let direction):
                        MouseScrollView(direction: direction, isAnimating: isAnimating)
                            
                    case .move:
                        MouseMoveView(isAnimating: isAnimating)
                            
                    case .none:
                        // Nothing to display
                        EmptyView()
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mouseActionType)
                
                // Action label at the bottom
                VStack {
                    Spacer()
                    
                    if mouseActionType != .none {
                        Text(actionDescription)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                            )
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
            }
            
            // Start pulse animation cycle
            animatePulse()
        }
    }
    
    private func animatePulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.7
        }
    }
    
    // Generate a description of the mouse action
    private var actionDescription: String {
        switch mouseActionType {
        case .click(let button):
            switch button {
            case .left: return "Left Click"
            case .right: return "Right Click"
            case .middle: return "Middle Click"
            case .extra1: return "Button 4"
            case .extra2: return "Button 5"
            }
            
        case .scroll(let direction):
            switch direction {
            case .up: return "Scroll Up"
            case .down: return "Scroll Down"
            case .left: return "Scroll Left"
            case .right: return "Scroll Right"
            }
            
        case .move:
            return "Mouse Move"
            
        case .none:
            return ""
        }
    }
}

// MARK: - Mouse Action Views

struct MouseClickView: View {
    let button: MouseEvent.MouseButton
    let isAnimating: Bool
    
    @State private var clickAnimation = false
    
    private var buttonColor: Color {
        switch button {
        case .left: return Color.white.opacity(0.9)
        case .right: return Color.blue.opacity(0.9)
        case .middle: return Color.green.opacity(0.8)
        case .extra1, .extra2: return Color.orange.opacity(0.8)
        }
    }
    
    var body: some View {
        ZStack {
            // Pulse effect
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        buttonColor.opacity(0.3 - (Double(i) * 0.1)),
                        lineWidth: 1.5 - (CGFloat(i) * 0.5)
                    )
                    .frame(width: clickAnimation ? 60 + CGFloat(i * 15) : 20, height: clickAnimation ? 60 + CGFloat(i * 15) : 20)
                    .opacity(clickAnimation ? 0 : 0.7)
            }
            
            // Mouse pointer
            ZStack {
                // Button indicator
                Circle()
                    .fill(buttonColor)
                    .frame(width: 12, height: 12)
                
                // Mouse shape
                MouseShape()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 24, height: 28)
                    .offset(x: -2, y: -2)
            }
            .scaleEffect(clickAnimation ? 0.9 : 1.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                clickAnimation = true
            }
        }
    }
}

struct MouseScrollView: View {
    let direction: MouseVisualizer.MouseActionType.ScrollDirection
    let isAnimating: Bool
    
    @State private var scrollAnimation = false
    
    var body: some View {
        ZStack {
            // Mouse shape
            MouseShape()
                .fill(Color.white.opacity(0.9))
                .frame(width: 24, height: 28)
                .offset(x: -2, y: -2)
            
            // Scroll wheel indicator
            ScrollWheelIndicator(direction: direction, isAnimating: scrollAnimation)
                .offset(y: -2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatCount(1, autoreverses: true)) {
                scrollAnimation = true
            }
        }
    }
}

struct ScrollWheelIndicator: View {
    let direction: MouseVisualizer.MouseActionType.ScrollDirection
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Wheel
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            
            // Direction indicator
            Group {
                switch direction {
                case .up:
                    Image(systemName: "chevron.up")
                        .offset(y: isAnimating ? -10 : 0)
                case .down:
                    Image(systemName: "chevron.down")
                        .offset(y: isAnimating ? 10 : 0)
                case .left:
                    Image(systemName: "chevron.left")
                        .offset(x: isAnimating ? -10 : 0)
                case .right:
                    Image(systemName: "chevron.right")
                        .offset(x: isAnimating ? 10 : 0)
                }
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct MouseMoveView: View {
    let isAnimating: Bool
    
    @State private var moveOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Mouse shape
            MouseShape()
                .fill(Color.white.opacity(0.9))
                .frame(width: 24, height: 28)
                .offset(x: -2, y: -2)
            
            // Motion trail
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white.opacity(0.8 - (Double(i) * 0.25)))
                        .frame(width: 4 - CGFloat(i), height: 4 - CGFloat(i))
                }
            }
            .offset(x: -20, y: 0)
            .opacity(moveOpacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                moveOpacity = 1.0
            }
            
            // Fade out motion trail
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    moveOpacity = 0.0
                }
            }
        }
    }
}

struct MouseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start at top left
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Move to bottom point
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.8))
        
        // Create the bottom curve
        path.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.6))
        
        // Add the right side and return to top
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // Close the path
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    // Create test mouse events
    let clickEvent = InputEvent.mouseEvent(
        type: .mouseDown,
        position: CGPoint(x: 0.5, y: 0.5),
        button: .left,
        scrollDelta: nil,
        speed: 0
    )
    
    return ZStack {
        Color.black
        MouseVisualizer(events: [clickEvent])
    }
    .frame(width: 200, height: 150)
} 