import SwiftUI

// MARK: - Supporting Types

enum MouseActionType: Equatable {
    case click(button: MouseButton, isDoubleClick: Bool)
    case scroll(direction: ScrollDirection)
    case momentumScroll(direction: ScrollDirection)
    case move(isFast: Bool)
    case none
}

enum ScrollDirection: Equatable {
    case up
    case down
    case left
    case right
}

struct MouseVisualizer: View {
    let events: [InputEvent]
    
    // Animation states
    @State private var isAnimating = false
    @State private var pulseOpacity: Double = 0
    
    @State private var isMinimalMode: Bool = false
    
    // Get the latest mouse events of each type
    private var clickEvents: [InputEvent] {
        events.filter { $0.type == .mouse && $0.mouseEvent?.button != nil && $0.mouseEvent?.isDown == true }
    }
    
    private var moveEvents: [InputEvent] {
        events.filter { $0.type == .mouse && $0.mouseEvent?.button == nil && $0.mouseEvent?.scrollDelta == nil }
    }
    
    private var scrollEvents: [InputEvent] {
        events.filter { $0.type == .mouse && $0.mouseEvent?.scrollDelta != nil }
    }
    
    private var latestClickEvent: InputEvent? {
        clickEvents.first
    }
    
    private var latestScrollEvent: InputEvent? {
        scrollEvents.first
    }
    
    private var latestMoveEvent: InputEvent? {
        moveEvents.first
    }
    
    private var mouseActionType: MouseActionType {
        // First check for clicks as they should have priority
        if let clickEvent = latestClickEvent, let mouseEvent = clickEvent.mouseEvent {
            let button = mouseEvent.button ?? .left
            let isDoubleClick = mouseEvent.isDoubleClick
            
            return .click(button: button, isDoubleClick: isDoubleClick)
        } 
        // Then check for scroll events
        else if let scrollEvent = latestScrollEvent, let mouseEvent = scrollEvent.mouseEvent, let delta = mouseEvent.scrollDelta {
            // Determine primary scroll direction
            let direction: ScrollDirection
            if abs(delta.y) > abs(delta.x) {
                direction = delta.y > 0 ? .down : .up
            } else {
                direction = delta.x > 0 ? .right : .left
            }
            
            // Check if this is momentum scrolling
            if mouseEvent.isMomentumScroll {
                return .momentumScroll(direction: direction)
            } else {
                return .scroll(direction: direction)
            }
        } 
        // Finally check for move events - only if we have them and they're the most recent
        else if let moveEvent = latestMoveEvent, let _ = moveEvent.mouseEvent {
            // For simplicity, all movements are considered "slow" as we no longer track speed
            return .move(isFast: false)
        }
        
        return .none
    }
    
    var body: some View {
        // Check for minimal mode on appearance
        let _ = onAppear {
            isMinimalMode = UserPreferences.getMinimalDisplayMode()
            
            // Listen for minimal mode changes
            NotificationCenter.default.addObserver(
                forName: .MinimalDisplayModeChanged,
                object: nil,
                queue: .main
            ) { _ in
                isMinimalMode = UserPreferences.getMinimalDisplayMode()
            }
        }
        
        if events.isEmpty {
            EmptyView()
        } else {
            if isMinimalMode {
                minimalMouseView
            } else {
                standardMouseView
            }
        }
    }
    
    // Standard mouse visualization
    private var standardMouseView: some View {
        ZStack {
            // Only show content when there are events
            if !events.isEmpty {
                // Dynamic content based on mouse action
                Group {
                    switch mouseActionType {
                    case .click(let button, let isDoubleClick):
                        MouseClickView(button: button, isDoubleClick: isDoubleClick, isAnimating: isAnimating)
                            
                    case .scroll(let direction):
                        MouseScrollView(direction: direction, isMomentum: false, isAnimating: isAnimating)
                            
                    case .momentumScroll(let direction):
                        MouseScrollView(direction: direction, isMomentum: true, isAnimating: isAnimating)
                            
                    case .move(let isFast):
                        MouseMoveView(isFast: isFast, isAnimating: isAnimating)
                            
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
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                    }
                }
                .padding(.bottom, 5)
            }
        }
        .frame(width: 100, height: 72)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
    
    // Minimal mouse visualization
    private var minimalMouseView: some View {
        HStack(spacing: 4) {
            // Mouse icon
            Image(systemName: mouseActionIcon)
                .font(.system(size: 10))
                .foregroundColor(.white)
            
            // Action text
            Text(minimalActionDescription)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    // Nice descriptive text for the current action
    private var actionDescription: String {
        switch mouseActionType {
        case .click(let button, let isDoubleClick):
            let clickType = isDoubleClick ? "Double Click" : "Click"
            
            switch button {
            case .left: return "Left \(clickType)"
            case .right: return "Right \(clickType)"
            case .middle: return "Middle \(clickType)"
            case .extra1: return "Back Button"
            case .extra2: return "Forward Button"
            case .other: return "Other Button \(clickType)"
            }
            
        case .scroll(let direction):
            switch direction {
            case .up: return "Scroll Up"
            case .down: return "Scroll Down"
            case .left: return "Scroll Left"
            case .right: return "Scroll Right"
            }
            
        case .momentumScroll(let direction):
            switch direction {
            case .up: return "Momentum Up"
            case .down: return "Momentum Down"
            case .left: return "Momentum Left"
            case .right: return "Momentum Right"
            }
            
        case .move(let isFast):
            return isFast ? "Fast Movement" : "Mouse Move"
            
        case .none:
            return ""
        }
    }
    
    // Minimal action description
    private var minimalActionDescription: String {
        switch mouseActionType {
        case .click(let button, let isDoubleClick):
            let doublePrefix = isDoubleClick ? "2×" : ""
            
            switch button {
            case .left: return "\(doublePrefix)Click"
            case .right: return "\(doublePrefix)Right"
            case .middle: return "\(doublePrefix)Middle"
            case .extra1: return "Back"
            case .extra2: return "Forward"
            case .other: return "Other Button"
            }
            
        case .scroll(let direction):
            switch direction {
            case .up: return "Scroll ↑"
            case .down: return "Scroll ↓"
            case .left: return "Scroll ←"
            case .right: return "Scroll →"
            }
            
        case .momentumScroll(let direction):
            switch direction {
            case .up: return "Mom ↑"
            case .down: return "Mom ↓"
            case .left: return "Mom ←"
            case .right: return "Mom →"
            }
            
        case .move(let isFast):
            return isFast ? "Fast" : "Move"
            
        case .none:
            return ""
        }
    }
    
    // Mouse icon for minimal mode
    private var mouseActionIcon: String {
        switch mouseActionType {
        case .click(let button, let isDoubleClick):
            let baseIcon: String
            
            switch button {
            case .left: baseIcon = "mouse.fill"
            case .right: baseIcon = "mouse.fill"
            case .middle: baseIcon = "mouse.fill"
            case .extra1: return "arrow.left.circle.fill"
            case .extra2: return "arrow.right.circle.fill"
            case .other: return "questionmark.circle.fill"
            }
            
            return isDoubleClick ? "2.circle" : baseIcon
            
        case .scroll(let direction):
            switch direction {
            case .up: return "chevron.up"
            case .down: return "chevron.down"
            case .left: return "chevron.left"
            case .right: return "chevron.right"
            }
            
        case .momentumScroll(let direction):
            switch direction {
            case .up: return "chevron.up.chevron.up"
            case .down: return "chevron.down.chevron.down"
            case .left: return "chevron.left.chevron.left"
            case .right: return "chevron.right.chevron.right"
            }
            
        case .move(let isFast):
            return isFast ? "hand.point.up.braille.fill" : "hand.point.up.fill"
            
        case .none:
            return ""
        }
    }
}

// MARK: - Subviews for different mouse actions

struct MouseClickView: View {
    let button: MouseButton
    let isDoubleClick: Bool
    let isAnimating: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Pulse effect for clicks
            Circle()
                .fill(clickColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .onAppear {
                    withAnimation(Animation.easeOut(duration: 0.5).repeatCount(isDoubleClick ? 2 : 1, autoreverses: true)) {
                        pulseScale = 1.3
                        pulseOpacity = 0.7
                    }
                }
            
            // Mouse icon
            ZStack {
                // Mouse body
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(.sRGB, white: 0.9, opacity: 1), Color(.sRGB, white: 0.8, opacity: 1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 24, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                
                // Button indicators
                VStack(spacing: 2) {
                    // Left button
                    RoundedRectangle(cornerRadius: 4)
                        .fill(button == .left ? clickColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                    
                    // Right button
                    RoundedRectangle(cornerRadius: 4)
                        .fill(button == .right ? clickColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                    
                    // Middle button/scroll wheel
                    if button == .middle {
                        Circle()
                            .fill(clickColor)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 6, height: 6)
                    }
                }
                .offset(y: -4)
                
                // Double-click indicator
                if isDoubleClick {
                    Text("2×")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Color.blue.opacity(0.7)))
                        .offset(x: 12, y: -12)
                }
                
                // Extra buttons indicator
                if button == .extra1 || button == .extra2 {
                    Image(systemName: button == .extra1 ? "arrow.left" : "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Color.orange.opacity(0.7)))
                        .offset(x: button == .extra1 ? -14 : 14, y: 0)
                }
            }
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
        }
    }
    
    private var clickColor: Color {
        switch button {
        case .left: return Color.blue
        case .right: return Color.orange
        case .middle: return Color.purple
        case .extra1, .extra2: return Color.green
        case .other: return Color.gray
        }
    }
}

struct MouseScrollView: View {
    let direction: ScrollDirection
    let isMomentum: Bool
    let isAnimating: Bool
    
    @State private var scrollAnimation = false
    
    var body: some View {
        ZStack {
            // Mouse with scroll wheel
            ZStack {
                // Mouse body
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(.sRGB, white: 0.9, opacity: 1), Color(.sRGB, white: 0.8, opacity: 1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 24, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                
                // Scroll wheel
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                    
                    // Scroll direction indicator
                    Group {
                        if direction == .up {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .offset(y: scrollAnimation ? -2 : 0)
                        } else if direction == .down {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .offset(y: scrollAnimation ? 2 : 0)
                        } else if direction == .left {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: scrollAnimation ? -2 : 0)
                        } else if direction == .right {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: scrollAnimation ? 2 : 0)
                        }
                    }
                }
                .offset(y: -4)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
            
            // Momentum indicator
            if isMomentum {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    // Momentum trail
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.blue.opacity(0.7 - Double(i) * 0.2))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .rotationEffect(directionAngle)
                    .offset(x: 12)
                }
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                scrollAnimation = true
            }
        }
    }
    
    private var directionAngle: Angle {
        switch direction {
        case .up: return .degrees(270)
        case .down: return .degrees(90)
        case .left: return .degrees(180)
        case .right: return .degrees(0)
        }
    }
}

struct MouseMoveView: View {
    let isFast: Bool
    let isAnimating: Bool
    
    @State private var moveAnimation = false
    
    var body: some View {
        ZStack {
            // Movement trail
            ZStack {
                // Mouse cursor
                Image(systemName: "cursorarrow.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 1)
                
                // Movement trail
                if isFast {
                    HStack(spacing: 2) {
                        ForEach(0..<4) { i in
                            Image(systemName: "cursorarrow.fill")
                                .font(.system(size: 16 - CGFloat(i) * 3))
                                .foregroundColor(.white.opacity(0.7 - Double(i) * 0.2))
                                .offset(x: -CGFloat(i) * 6, y: CGFloat(i) * 3)
                        }
                    }
                    .offset(x: moveAnimation ? 5 : 0, y: moveAnimation ? -3 : 0)
                }
            }
            .offset(x: moveAnimation ? 5 : -5, y: moveAnimation ? -5 : 5)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: isFast ? 0.3 : 0.7).repeatForever(autoreverses: true)) {
                moveAnimation = true
            }
        }
    }
}

#Preview {
    // Create test mouse events
    let mouseEvent = MouseEvent(
        position: CGPoint(x: 0.5, y: 0.5),
        button: .left,
        scrollDelta: nil,
        isDown: true,
        isDoubleClick: false,
        isMomentumScroll: false
    )
    let clickEvent = InputEvent.mouseEvent(event: mouseEvent)
    
    ZStack {
        Color.black
        MouseVisualizer(events: [clickEvent])
    }
    .frame(width: 200, height: 150)
} 