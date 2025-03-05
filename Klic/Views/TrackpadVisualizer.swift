import SwiftUI

struct TrackpadVisualizer: View {
    let events: [InputEvent]
    let trackpadSize: CGSize
    
    // Access to raw touches from the monitor for more accurate finger position display
    @ObservedObject var trackpadMonitor: TrackpadMonitor = TrackpadMonitor()
    
    // Animation states
    @State private var isAnimating = false
    
    // Get the latest trackpad events of each type
    private var touchEvents: [InputEvent] {
        events.filter { $0.type == .trackpadTouch }
    }
    
    private var gestureEvents: [InputEvent] {
        events.filter { $0.type == .trackpadGesture }
    }
    
    private var latestTouchEvent: InputEvent? {
        touchEvents.first
    }
    
    private var latestGestureEvent: InputEvent? {
        gestureEvents.first
    }
    
    // Check gesture types
    private var gestureType: GestureDisplayType {
        if let gesture = latestGestureEvent?.trackpadGesture {
            // Check if this is a momentum scroll
            if gesture.isMomentumScroll {
                // Get direction from swipe type if available
                if case .swipe(let direction) = gesture.type {
                    return .momentumScroll(direction: direction)
                } else {
                    return .momentumScroll(direction: nil)
                }
            }
            
            switch gesture.type {
            case .swipe(let direction):
                return .swipe(direction: direction)
            case .pinch:
                return .pinch
            case .rotate:
                return .rotate
            case .tap(let count):
                return .tap(count: count)
            default:
                return .none
            }
        }
        
        // If touch events but no gesture
        if !touchEvents.isEmpty, let touches = latestTouchEvent?.trackpadTouches {
            return .touch(count: touches.count)
        }
        
        // Check if we have raw touches from monitor but no specific gesture
        if !trackpadMonitor.rawTouches.isEmpty {
            return .touch(count: trackpadMonitor.rawTouches.count)
        }
        
        return .none
    }
    
    // Enum to simplify gesture display logic
    private enum GestureDisplayType: Equatable {
        case swipe(direction: TrackpadGesture.GestureType.SwipeDirection)
        case pinch
        case rotate
        case tap(count: Int)
        case touch(count: Int)
        case momentumScroll(direction: TrackpadGesture.GestureType.SwipeDirection?)
        case none
    }
    
    var body: some View {
        ZStack {
            // Only show content when there are events
            if !events.isEmpty || !trackpadMonitor.rawTouches.isEmpty {
                // Dynamic content based on gesture type
                Group {
                    switch gestureType {
                    case .swipe(let direction):
                        SwipeGestureView(
                            direction: direction,
                            magnitude: latestGestureEvent?.trackpadGesture?.magnitude ?? 0.5
                        )
                        
                    case .pinch:
                        PinchGestureView(
                            magnitude: latestGestureEvent?.trackpadGesture?.magnitude ?? 0.5,
                            touches: trackpadMonitor.rawTouches
                        )
                        
                    case .rotate:
                        RotationGestureView(
                            rotation: latestGestureEvent?.trackpadGesture?.rotation ?? 0,
                            touches: trackpadMonitor.rawTouches
                        )
                        
                    case .tap(let count), .touch(let count):
                        if !trackpadMonitor.rawTouches.isEmpty {
                            RealTouchGestureView(
                                touches: trackpadMonitor.rawTouches,
                                fingerCount: count,
                                trackpadSize: trackpadSize
                            )
                        } else {
                            TapGestureView(fingerCount: count)
                        }
                        
                    case .momentumScroll(let direction):
                        MomentumScrollView(direction: direction)
                        
                    case .none:
                        // Nothing to display
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gestureType)
                
                // Gesture label
                VStack {
                    Spacer()
                    
                    if gestureType != .none {
                        Text(gestureDescription)
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
        .frame(width: trackpadSize.width, height: trackpadSize.height)
        .contentShape(Rectangle())
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isAnimating = true
        }
    }
    
    // Generate a clean description of the gesture
    private var gestureDescription: String {
        switch gestureType {
        case .pinch:
            return "Pinch"
        case .rotate:
            return "Rotate"
        case .swipe(let direction):
            switch direction {
            case .up: return "Swipe Up"
            case .down: return "Swipe Down"
            case .left: return "Swipe Left"
            case .right: return "Swipe Right"
            }
        case .tap(let count):
            return "\(count)-Finger Tap"
        case .touch(let count):
            return "\(count) Fingers"
        case .momentumScroll(let direction):
            var directionText = ""
            if let direction = direction {
                switch direction {
                case .up: directionText = "Up"
                case .down: directionText = "Down"
                case .left: directionText = "Left"
                case .right: directionText = "Right"
                }
            }
            return "Momentum \(directionText)"
        case .none:
            return ""
        }
    }
}

// MARK: - Gesture Visualizations

// New view to display actual touch positions using NSTouch data
struct RealTouchGestureView: View {
    let touches: [NSTouch]
    let fingerCount: Int
    let trackpadSize: CGSize
    
    @State private var isAnimating = false
    @State private var showRipples = false
    
    var body: some View {
        ZStack {
            // Show trackpad outline
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: trackpadSize.width - 12, height: trackpadSize.height - 12)
            
            // Draw each touch based on its normalized position
            ForEach(0..<touches.count, id: \.self) { index in
                let touch = touches[index]
                // Position within our container based on normalized position
                let position = CGPoint(
                    x: touch.normalizedPosition.x * (trackpadSize.width - 20),
                    y: (1 - touch.normalizedPosition.y) * (trackpadSize.height - 20) // Flip Y coordinate
                )
                
                TouchCircle(touch: touch, position: position, showRipples: showRipples, isAnimating: isAnimating)
            }
            
            // Number indicator for multi-finger touches
            if fingerCount > 1 {
                FingerCountIndicator(count: fingerCount, isAnimating: isAnimating, position: CGPoint(x: trackpadSize.width / 2, y: 14))
            }
        }
        .onAppear {
            // First show the fingers
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = true
            }
            
            // Then show ripple effect with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showRipples = true
                withAnimation(.easeOut(duration: 0.7)) {
                    isAnimating = true
                }
            }
        }
    }
}

// Helper view for touch circles
struct TouchCircle: View {
    let touch: NSTouch
    let position: CGPoint
    let showRipples: Bool
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Base circle
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 12, height: 12)
            
            // Pressure indicator (inner color)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.8),
                            Color.purple.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: 8 * 0.7, 
                    height: 8 * 0.7
                )
        }
        .position(position)
        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
        
        // Show touch ripple animation
        if showRipples {
            RippleEffect(position: position, isAnimating: isAnimating)
        }
    }
}

// Helper view for ripple effects
struct RippleEffect: View {
    let position: CGPoint
    let isAnimating: Bool
    
    var body: some View {
        ForEach(0..<2, id: \.self) { i in
            Circle()
                .stroke(Color.white.opacity(0.4 - (Double(i) * 0.15)), lineWidth: 1)
                .frame(width: 20 + CGFloat(i * 8), height: 20 + CGFloat(i * 8))
                .opacity(isAnimating ? 0 : 1)
                .position(position)
        }
    }
}

// Helper view for finger count indicator
struct FingerCountIndicator: View {
    let count: Int
    let isAnimating: Bool
    let position: CGPoint
    
    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color.white))
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            .opacity(isAnimating ? 1.0 : 0.0)
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .position(position)
    }
}

struct SwipeGestureView: View {
    let direction: TrackpadGesture.GestureType.SwipeDirection
    let magnitude: CGFloat
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Arrow trail visualization
            DirectionalArrow(
                direction: direction,
                magnitude: magnitude,
                isAnimating: isAnimating
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).repeatCount(1)) {
                isAnimating = true
            }
        }
    }
}

// New view for momentum scrolling visualization
struct MomentumScrollView: View {
    let direction: TrackpadGesture.GestureType.SwipeDirection?
    
    @State private var isAnimating = false
    @State private var animatingDots = false
    
    private var rotation: Angle {
        if let direction = direction {
            switch direction {
            case .up: return .degrees(-90)
            case .down: return .degrees(90)
            case .left: return .degrees(180)
            case .right: return .degrees(0)
            }
        }
        return .zero
    }
    
    var body: some View {
        ZStack {
            // Momentum indicator (fading dots showing continuation)
            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(Color.white.opacity(1.0 - (Double(i) * 0.2)))
                        .frame(width: 4, height: 4)
                        .offset(x: isAnimating ? CGFloat(i * 4) : 0)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.1),
                            value: isAnimating
                        )
                }
            }
            .rotationEffect(rotation)
            
            // Indicator for momentum
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 16)
                
                Text("M")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            .scaleEffect(animatingDots ? 1.1 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: animatingDots
            )
        }
        .onAppear {
            isAnimating = true
            animatingDots = true
        }
    }
}

struct DirectionalArrow: View {
    let direction: TrackpadGesture.GestureType.SwipeDirection
    let magnitude: CGFloat
    let isAnimating: Bool
    
    private var arrowLength: CGFloat {
        min(40, 20 + (magnitude * 20))
    }
    
    private var rotation: Angle {
        switch direction {
        case .up: return .degrees(-90)
        case .down: return .degrees(90)
        case .left: return .degrees(180)
        case .right: return .degrees(0)
        }
    }
    
    var body: some View {
        ZStack {
            // Arrow trail effect
            ForEach(0..<3) { i in
                ArrowShape()
                    .stroke(
                        Color.white.opacity(0.4 - (Double(i) * 0.1)),
                        lineWidth: 1.5 - (CGFloat(i) * 0.5)
                    )
                    .frame(width: arrowLength - CGFloat(i * 4), height: 16)
                    .offset(getOffset(for: i))
            }
            
            // Main arrow
            ArrowShape()
                .fill(Color.white.opacity(0.9))
                .frame(width: arrowLength, height: 16)
        }
        .rotationEffect(rotation)
        .offset(isAnimating ? getAnimationOffset() : .zero)
        .opacity(isAnimating ? 1.0 : 0.7)
        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
    }
    
    private func getOffset(for index: Int) -> CGSize {
        let baseOffset: CGFloat = CGFloat(index) * -3
        
        switch direction {
        case .up: return CGSize(width: 0, height: baseOffset)
        case .down: return CGSize(width: 0, height: baseOffset)
        case .left: return CGSize(width: baseOffset, height: 0)
        case .right: return CGSize(width: baseOffset, height: 0)
        }
    }
    
    private func getAnimationOffset() -> CGSize {
        let animationDistance: CGFloat = 8
        
        switch direction {
        case .up: return CGSize(width: 0, height: -animationDistance)
        case .down: return CGSize(width: 0, height: animationDistance)
        case .left: return CGSize(width: -animationDistance, height: 0)
        case .right: return CGSize(width: animationDistance, height: 0)
        }
    }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Shaft
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height / 2))
        
        // Arrow head
        path.move(to: CGPoint(x: rect.width * 0.7, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height))
        
        return path
    }
}

struct PinchGestureView: View {
    let magnitude: CGFloat
    let touches: [NSTouch]
    
    @State private var isAnimating = false
    @State private var isPinchingIn = false
    
    private var shouldUseRealTouches: Bool {
        return touches.count >= 2
    }
    
    var body: some View {
        ZStack {
            if shouldUseRealTouches {
                // Draw real touch positions with pinch indicator
                ForEach(0..<min(touches.count, 2), id: \.self) { i in
                    let position = getPositionFromNormalizedTouch(touches[i])
                    
                    ZStack {
                        // Touch circle
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 12, height: 12)
                        
                        // Center dot
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                    }
                    .position(position)
                }
                
                // Connecting line between touches
                if touches.count >= 2 {
                    let pos1 = getPositionFromNormalizedTouch(touches[0])
                    let pos2 = getPositionFromNormalizedTouch(touches[1])
                    
                    // Line connecting touch points
                    Line(from: pos1, to: pos2)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        .animation(.spring(response: 0.3), value: pos1)
                        .animation(.spring(response: 0.3), value: pos2)
                }
            } else {
                // Fallback to simulated visualization if no real touches
                // Expanding/contracting circles
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            Color.white.opacity(0.7 - (Double(i) * 0.15)),
                            lineWidth: 1.5 - (CGFloat(i) * 0.4)
                        )
                        .frame(
                            width: getCircleSize(for: i),
                            height: getCircleSize(for: i)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                // Finger indicators
                ForEach(0..<2) { i in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 6, height: 6)
                        .offset(getFingerOffset(for: i))
                        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatCount(1, autoreverses: true)) {
                isAnimating = true
                isPinchingIn = magnitude > 0.5
            }
        }
    }
    
    private func getPositionFromNormalizedTouch(_ touch: NSTouch) -> CGPoint {
        return CGPoint(
            x: touch.normalizedPosition.x * 100,
            y: (1 - touch.normalizedPosition.y) * 72 // Flip Y coordinate
        )
    }
    
    private func getCircleSize(for index: Int) -> CGFloat {
        let baseSize: CGFloat = 20 + (CGFloat(index) * 12)
        let animationFactor: CGFloat = isAnimating ? (isPinchingIn ? 0.7 : 1.3) : 1.0
        
        return baseSize * animationFactor
    }
    
    private func getFingerOffset(for index: Int) -> CGSize {
        let direction: CGFloat = index == 0 ? -1 : 1
        let distance: CGFloat = isAnimating ? (isPinchingIn ? 15 : 30) : 20
        
        return CGSize(width: direction * distance, height: direction * distance)
    }
}

// Simple line shape
struct Line: Shape {
    var from: CGPoint
    var to: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

struct RotationGestureView: View {
    let rotation: CGFloat
    let touches: [NSTouch]
    
    @State private var isAnimating = false
    
    private var shouldUseRealTouches: Bool {
        return touches.count >= 2
    }
    
    var body: some View {
        ZStack {
            if shouldUseRealTouches {
                // Draw real touch positions with rotation indicator
                ForEach(0..<min(touches.count, 2), id: \.self) { i in
                    let position = getPositionFromNormalizedTouch(touches[i])
                    
                    ZStack {
                        // Touch circle
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 12, height: 12)
                        
                        // Direction indicator
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                    }
                    .position(position)
                }
                
                // Rotation arc between touches
                if touches.count >= 2 {
                    let pos1 = getPositionFromNormalizedTouch(touches[0])
                    let pos2 = getPositionFromNormalizedTouch(touches[1])
                    let center = CGPoint(
                        x: (pos1.x + pos2.x) / 2,
                        y: (pos1.y + pos2.y) / 2
                    )
                    
                    // Rotation indicator
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            Color.white.opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .frame(width: 24, height: 24)
                        .position(center)
                        .rotationEffect(isAnimating ? .degrees(rotation > 0 ? 360 : -360) : .zero)
                        .animation(
                            .easeInOut(duration: 0.8).repeatCount(1, autoreverses: true),
                            value: isAnimating
                        )
                }
            } else {
                // Fallback to simulated visualization if no real touches
                // Rotation arc
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(
                        Color.white.opacity(0.8),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(isAnimating ? .degrees(rotation > 0 ? 360 : -360) : .zero)
                    .animation(
                        .easeInOut(duration: 0.8).repeatCount(1, autoreverses: true),
                        value: isAnimating
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                
                // Rotation indicator dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .offset(y: -20)
                    .rotationEffect(isAnimating ? .degrees(rotation > 0 ? 360 : -360) : .zero)
                    .animation(
                        .easeInOut(duration: 0.8).repeatCount(1, autoreverses: true),
                        value: isAnimating
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private func getPositionFromNormalizedTouch(_ touch: NSTouch) -> CGPoint {
        return CGPoint(
            x: touch.normalizedPosition.x * 100,
            y: (1 - touch.normalizedPosition.y) * 72 // Flip Y coordinate
        )
    }
}

struct TapGestureView: View {
    let fingerCount: Int
    
    @State private var isAnimating = false
    @State private var showRipples = false
    
    // Fix non-constant range warning
    private var displayFingerCount: Int {
        min(fingerCount, 5)
    }
    
    private var fingerIndices: [Int] {
        Array(0..<displayFingerCount)
    }
    
    var body: some View {
        ZStack {
            // Tap ripple effect
            if showRipples {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            Color.white.opacity(0.6 - (Double(i) * 0.15)),
                            lineWidth: 1.5 - (CGFloat(i) * 0.4)
                        )
                        .frame(
                            width: 20 + (isAnimating ? CGFloat(i * 15) : 0),
                            height: 20 + (isAnimating ? CGFloat(i * 15) : 0)
                        )
                        .opacity(isAnimating ? 0 : 1)
                }
            }
            
            // Finger indicators for multi-touch
            ZStack {
                // Create circle of fingers for multi-touch
                ForEach(fingerIndices, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 8, height: 8)
                        .offset(getFingerOffset(for: i, of: displayFingerCount))
                        .opacity(isAnimating ? 1.0 : 0.3)
                        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
            
            // Number indicator for multi-finger taps
            if fingerCount > 1 {
                Text("\(fingerCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
            }
        }
        .onAppear {
            // First show the fingers
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating = true
            }
            
            // Then show ripple effect with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showRipples = true
                withAnimation(.easeOut(duration: 0.7)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private func getFingerOffset(for index: Int, of total: Int) -> CGSize {
        // If single finger, just center it
        if total == 1 {
            return .zero
        }
        
        // For multi-finger, arrange in a circle pattern
        let radius: CGFloat = 14
        let angle = (2.0 * .pi / Double(total)) * Double(index)
        
        return CGSize(
            width: radius * cos(CGFloat(angle)),
            height: radius * sin(CGFloat(angle))
        )
    }
}

// Preview
#Preview {
    // Create test gesture events
    let trackpadGesture = TrackpadGesture(
        type: .swipe(direction: .up),
        touches: [
            FingerTouch(
                id: 1, 
                position: CGPoint(x: 0.5, y: 0.5),
                pressure: 0.7,
                majorRadius: 6,
                minorRadius: 6,
                fingerType: .index
            )
        ],
        magnitude: 0.8,
        rotation: nil
    )
    
    let event = InputEvent.trackpadGestureEvent(gesture: trackpadGesture)
    
    return ZStack {
        Color.black
        TrackpadVisualizer(
            events: [event],
            trackpadSize: CGSize(width: 150, height: 100)
        )
    }
    .frame(width: 200, height: 150)
} 