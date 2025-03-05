import SwiftUI
import Combine
import os.log
import Foundation

struct TrackpadVisualizer: View {
    // MARK: - Properties
    
    let events: [InputEvent]
    var trackpadSize: CGSize?
    var trackpadMonitor: TrackpadMonitor?
    
    @State private var currentGesture: TrackpadGesture?
    @State private var activeTouches: [FingerTouch] = []
    @State private var gestureOpacity: Double = 0
    @State private var touchesOpacity: Double = 0
    @State private var isMinimalMode: Bool = false
    
    // Animation states
    @State private var isAnimating: Bool = false
    @State private var animationProgress: CGFloat = 0
    
    // Gesture display timing
    private let gestureFadeInDuration: Double = 0.2
    private let gestureDuration: Double = 1.5
    private let gestureFadeOutDuration: Double = 0.3
    
    // Touch display timing
    private let touchFadeInDuration: Double = 0.15
    private let touchDuration: Double = 0.8
    private let touchFadeOutDuration: Double = 0.2
    
    // Trackpad dimensions
    private let trackpadAspectRatio: CGFloat = 1.6 // Width:Height ratio
    
    // MARK: - Initialization
    
    init(events: [InputEvent], trackpadSize: CGSize? = nil, trackpadMonitor: TrackpadMonitor? = nil) {
        self.events = events
        self.trackpadSize = trackpadSize
        self.trackpadMonitor = trackpadMonitor
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if isMinimalMode {
                minimalTrackpadView
            } else {
                standardTrackpadView
            }
        }
        .onAppear {
            // Check for minimal mode on appearance
            isMinimalMode = UserDefaults.standard.bool(forKey: "minimalMode")
            
            // Process events
            processEvents()
        }
        .onChange(of: events) { oldValue, newValue in
            processEvents()
        }
    }
    
    // Process the incoming events
    private func processEvents() {
        // Find gesture events
        if let gestureEvent = events.first(where: { $0.trackpadGesture != nil }),
           let gesture = gestureEvent.trackpadGesture {
            handleNewGesture(gesture)
        }
        
        // Find touch events
        if let touchEvent = events.first(where: { $0.trackpadTouches != nil }),
           let touches = touchEvent.trackpadTouches, !touches.isEmpty {
            handleNewTouches(touches)
        }
    }
    
    // MARK: - Views
    
    private var standardTrackpadView: some View {
        VStack(spacing: 8) {
            // Gesture visualization
            ZStack {
                // Trackpad outline
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .aspectRatio(trackpadAspectRatio, contentMode: .fit)
                    .frame(maxWidth: 240)
                
                // Touch points
                ForEach(activeTouches, id: \.id) { touch in
                    Circle()
                        .foregroundColor(Color.white.opacity(0.7))
                        .frame(width: 16, height: 16)
                        .position(
                            x: touch.position.x * 240,
                            y: touch.position.y * (240 / trackpadAspectRatio)
                        )
                        .opacity(touchesOpacity)
                }
                
                // Gesture visualization
                if let gesture = currentGesture {
                    gestureVisualization(for: gesture)
                        .opacity(gestureOpacity)
                }
            }
            .frame(maxWidth: 240, maxHeight: 240 / trackpadAspectRatio)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            
            // Gesture description
            if let gesture = currentGesture {
                Text(gestureDescription(for: gesture))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .opacity(gestureOpacity)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
    
    private var minimalTrackpadView: some View {
        HStack(spacing: 8) {
            // Gesture icon
            if let gesture = currentGesture {
                gestureIcon(for: gesture)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
            }
            
            // Gesture description
            if let gesture = currentGesture {
                Text(minimalGestureDescription(for: gesture))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .opacity(gestureOpacity)
    }
    
    // MARK: - Gesture Visualization
    
    @ViewBuilder
    private func gestureVisualization(for gesture: TrackpadGesture) -> some View {
        switch gesture.type {
        case .swipe(let direction):
            swipeVisualization(direction: direction, fingerCount: gesture.touches.count)
        case .pinch:
            pinchVisualization(gesture: gesture)
        case .rotate:
            rotateVisualization(gesture: gesture)
        case .tap(let count):
            tapVisualization(count: count, fingerCount: gesture.touches.count)
        case .scroll(let fingerCount, let deltaX, let deltaY):
            scrollVisualization(fingerCount: fingerCount, deltaX: deltaX, deltaY: deltaY, isMomentum: gesture.isMomentumScroll)
        }
    }
    
    @ViewBuilder
    private func swipeVisualization(direction: TrackpadGesture.GestureType.SwipeDirection, fingerCount: Int) -> some View {
        let arrowLength: CGFloat = 80
        
        ZStack {
            // Direction arrow
            Path { path in
                // Start at center
                path.move(to: CGPoint(x: 120, y: 120 / trackpadAspectRatio))
                
                // Draw line in direction
                switch direction {
                case .up:
                    path.addLine(to: CGPoint(x: 120, y: (120 / trackpadAspectRatio) - arrowLength))
                case .down:
                    path.addLine(to: CGPoint(x: 120, y: (120 / trackpadAspectRatio) + arrowLength))
                case .left:
                    path.addLine(to: CGPoint(x: 120 - arrowLength, y: 120 / trackpadAspectRatio))
                case .right:
                    path.addLine(to: CGPoint(x: 120 + arrowLength, y: 120 / trackpadAspectRatio))
                }
            }
            .stroke(Color.white, lineWidth: 2)
            
            // Arrow head
            arrowHead(for: direction)
                .foregroundColor(Color.white)
                .frame(width: 12, height: 12)
                .position(arrowHeadPosition(for: direction, arrowLength: arrowLength))
            
            // Finger count indicator
            Text("\(fingerCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.white)
                .clipShape(Circle())
                .position(x: 120, y: 120 / trackpadAspectRatio)
        }
        .opacity(animationProgress)
    }
    
    @ViewBuilder
    private func pinchVisualization(gesture: TrackpadGesture) -> some View {
        let isPinchIn = gesture.magnitude < 0
        
        ZStack {
            // Pinch arrows
            ForEach(0..<4) { i in
                let angle = Double(i) * Double.pi / 2
                
                Path { path in
                    let startDistance: CGFloat = isPinchIn ? 60 : 30
                    let endDistance: CGFloat = isPinchIn ? 30 : 60
                    
                    let startX = 120 + cos(angle) * startDistance
                    let startY = (120 / trackpadAspectRatio) + sin(angle) * startDistance
                    let endX = 120 + cos(angle) * endDistance
                    let endY = (120 / trackpadAspectRatio) + sin(angle) * endDistance
                    
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(Color.white, lineWidth: 2)
                
                // Arrow heads
                arrowHead(angle: angle + (isPinchIn ? Double.pi : 0))
                    .foregroundColor(Color.white)
                    .frame(width: 10, height: 10)
                    .position(
                        x: 120 + cos(angle) * (isPinchIn ? 30 : 60),
                        y: (120 / trackpadAspectRatio) + sin(angle) * (isPinchIn ? 30 : 60)
                    )
            }
            
            // Finger count indicator
            Text("\(gesture.touches.count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.white)
                .clipShape(Circle())
                .position(x: 120, y: 120 / trackpadAspectRatio)
        }
        .opacity(animationProgress)
    }
    
    @ViewBuilder
    private func rotateVisualization(gesture: TrackpadGesture) -> some View {
        let isClockwise = gesture.rotation ?? 0 > 0
        
        ZStack {
            // Rotation circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 100, height: 100)
                .position(x: 120, y: 120 / trackpadAspectRatio)
            
            // Rotation arrow
            Path { path in
                let radius: CGFloat = 50
                let startAngle: CGFloat = isClockwise ? Double.pi / 4 : Double.pi * 7 / 4
                let endAngle: CGFloat = isClockwise ? Double.pi * 7 / 4 : Double.pi / 4
                
                path.addArc(
                    center: CGPoint(x: 120, y: 120 / trackpadAspectRatio),
                    radius: radius,
                    startAngle: Angle(radians: Double(startAngle)),
                    endAngle: Angle(radians: Double(endAngle)),
                    clockwise: !isClockwise
                )
            }
            .stroke(Color.white, lineWidth: 2)
            
            // Arrow head
            let arrowAngle = isClockwise ? Double.pi * 7 / 4 : Double.pi / 4
            arrowHead(angle: arrowAngle + (isClockwise ? Double.pi / 2 : -Double.pi / 2))
                .foregroundColor(Color.white)
                .frame(width: 10, height: 10)
                .position(
                    x: 120 + cos(arrowAngle) * 50,
                    y: (120 / trackpadAspectRatio) + sin(arrowAngle) * 50
                )
            
            // Finger count indicator
            Text("\(gesture.touches.count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.white)
                .clipShape(Circle())
                .position(x: 120, y: 120 / trackpadAspectRatio)
        }
        .opacity(animationProgress)
    }
    
    @ViewBuilder
    private func tapVisualization(count: Int, fingerCount: Int) -> some View {
        ZStack {
            // Tap circles
            ForEach(0..<min(fingerCount, 5), id: \.self) { i in
                let offset: CGFloat = fingerCount <= 1 ? 0 : CGFloat(i - (fingerCount - 1) / 2) * 30
                
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .position(x: 120 + offset, y: 120 / trackpadAspectRatio)
                
                // Tap count for first circle
                if i == 0 && count > 1 {
                    Text("\(count)×")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .position(x: 120 + offset, y: (120 / trackpadAspectRatio) - 25)
                }
            }
        }
        .opacity(animationProgress)
    }
    
    @ViewBuilder
    private func scrollVisualization(fingerCount: Int, deltaX: CGFloat, deltaY: CGFloat, isMomentum: Bool) -> some View {
        let direction: TrackpadGesture.GestureType.SwipeDirection = {
            if abs(deltaX) > abs(deltaY) {
                return deltaX > 0 ? .right : .left
            } else {
                return deltaY > 0 ? .up : .down
            }
        }()
        
        ZStack {
            // Scroll arrows
            VStack(spacing: 20) {
                if direction == .up || direction == .down {
                    ForEach(0..<3) { i in
                        Path { path in
                            let yOffset = CGFloat(i - 1) * 20
                            path.move(to: CGPoint(x: 100, y: (120 / trackpadAspectRatio) + yOffset))
                            path.addLine(to: CGPoint(x: 140, y: (120 / trackpadAspectRatio) + yOffset))
                        }
                        .stroke(Color.white, lineWidth: 2)
                    }
                } else {
                    ForEach(0..<3) { i in
                        Path { path in
                            let xOffset = CGFloat(i - 1) * 20
                            path.move(to: CGPoint(x: 120 + xOffset, y: (120 / trackpadAspectRatio) - 20))
                            path.addLine(to: CGPoint(x: 120 + xOffset, y: (120 / trackpadAspectRatio) + 20))
                        }
                        .stroke(Color.white, lineWidth: 2)
                    }
                }
            }
            
            // Direction arrow
            Path { path in
                // Start at center
                path.move(to: CGPoint(x: 120, y: 120 / trackpadAspectRatio))
                
                // Draw line in direction
                let arrowLength: CGFloat = 40
                switch direction {
                case .up:
                    path.addLine(to: CGPoint(x: 120, y: (120 / trackpadAspectRatio) - arrowLength))
                case .down:
                    path.addLine(to: CGPoint(x: 120, y: (120 / trackpadAspectRatio) + arrowLength))
                case .left:
                    path.addLine(to: CGPoint(x: 120 - arrowLength, y: 120 / trackpadAspectRatio))
                case .right:
                    path.addLine(to: CGPoint(x: 120 + arrowLength, y: 120 / trackpadAspectRatio))
                }
            }
            .stroke(Color.white, lineWidth: 2)
            
            // Arrow head
            let arrowLength: CGFloat = 40
            arrowHead(for: direction)
                .foregroundColor(Color.white)
                .frame(width: 12, height: 12)
                .position(arrowHeadPosition(for: direction, arrowLength: arrowLength))
            
            // Momentum indicator
            if isMomentum {
                Text("momentum")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(4)
                    .position(x: 120, y: (120 / trackpadAspectRatio) + 50)
            }
            
            // Finger count indicator
            Text("\(fingerCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(Color.white)
                .clipShape(Circle())
                .position(x: 120, y: 120 / trackpadAspectRatio)
        }
        .opacity(animationProgress)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func arrowHead(for direction: TrackpadGesture.GestureType.SwipeDirection) -> some View {
        switch direction {
        case .up:
            Triangle()
                .rotation(Angle(degrees: 0))
        case .down:
            Triangle()
                .rotation(Angle(degrees: 180))
        case .left:
            Triangle()
                .rotation(Angle(degrees: -90))
        case .right:
            Triangle()
                .rotation(Angle(degrees: 90))
        }
    }
    
    private func arrowHead(angle: CGFloat) -> some View {
        Triangle()
            .rotation(Angle(radians: Double(angle)))
    }
    
    private func arrowHeadPosition(for direction: TrackpadGesture.GestureType.SwipeDirection, arrowLength: CGFloat) -> CGPoint {
        switch direction {
        case .up:
            return CGPoint(x: 120, y: (120 / trackpadAspectRatio) - arrowLength)
        case .down:
            return CGPoint(x: 120, y: (120 / trackpadAspectRatio) + arrowLength)
        case .left:
            return CGPoint(x: 120 - arrowLength, y: 120 / trackpadAspectRatio)
        case .right:
            return CGPoint(x: 120 + arrowLength, y: 120 / trackpadAspectRatio)
        }
    }
    
    // MARK: - Gesture Descriptions
    
    private func gestureDescription(for gesture: TrackpadGesture) -> String {
        switch gesture.type {
        case .swipe(let direction):
            return "\(gesture.touches.count)-finger swipe \(direction)"
        case .pinch:
            let direction = gesture.magnitude < 0 ? "in" : "out"
            return "Pinch \(direction)"
        case .rotate:
            let direction = (gesture.rotation ?? 0) > 0 ? "clockwise" : "counter-clockwise"
            return "Rotate \(direction)"
        case .tap(let count):
            let tapText = count > 1 ? "\(count)-tap" : "tap"
            return "\(gesture.touches.count)-finger \(tapText)"
        case .scroll(let fingerCount, _, _):
            let momentumText = gesture.isMomentumScroll ? " (momentum)" : ""
            return "\(fingerCount)-finger scroll\(momentumText)"
        }
    }
    
    private func minimalGestureDescription(for gesture: TrackpadGesture) -> String {
        switch gesture.type {
        case .swipe(let direction):
            return "\(gesture.touches.count)F swipe \(direction)"
        case .pinch:
            let direction = gesture.magnitude < 0 ? "in" : "out"
            return "Pinch \(direction)"
        case .rotate:
            let direction = (gesture.rotation ?? 0) > 0 ? "CW" : "CCW"
            return "Rotate \(direction)"
        case .tap(let count):
            let tapText = count > 1 ? "\(count)×" : ""
            return "\(gesture.touches.count)F \(tapText)tap"
        case .scroll(let fingerCount, _, _):
            let momentumText = gesture.isMomentumScroll ? " (m)" : ""
            return "\(fingerCount)F scroll\(momentumText)"
        }
    }
    
    @ViewBuilder
    private func gestureIcon(for gesture: TrackpadGesture) -> some View {
        switch gesture.type {
        case .swipe(let direction):
            switch direction {
            case .up:
                Image(systemName: "arrow.up")
            case .down:
                Image(systemName: "arrow.down")
            case .left:
                Image(systemName: "arrow.left")
            case .right:
                Image(systemName: "arrow.right")
            }
        case .pinch:
            gesture.magnitude < 0 
                ? Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                : Image(systemName: "arrow.up.backward.and.arrow.down.forward")
        case .rotate:
            (gesture.rotation ?? 0) > 0
                ? Image(systemName: "arrow.clockwise")
                : Image(systemName: "arrow.counterclockwise")
        case .tap:
            Image(systemName: "hand.tap")
        case .scroll:
            gesture.isMomentumScroll
                ? Image(systemName: "scroll")
                : Image(systemName: "hand.draw")
        }
    }
    
    // MARK: - Event Handling
    
    private func handleNewGesture(_ gesture: TrackpadGesture) {
        // Update current gesture
        withAnimation(.easeOut(duration: gestureFadeInDuration)) {
            currentGesture = gesture
            gestureOpacity = 1.0
            
            // Start animation
            isAnimating = true
            animationProgress = 1.0
        }
        
        // Schedule fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + gestureDuration) {
            withAnimation(.easeIn(duration: gestureFadeOutDuration)) {
                gestureOpacity = 0
                isAnimating = false
                animationProgress = 0
            }
        }
    }
    
    private func handleNewTouches(_ touches: [FingerTouch]) {
        // Update active touches
        withAnimation(.easeOut(duration: touchFadeInDuration)) {
            activeTouches = touches
            touchesOpacity = 1.0
        }
        
        // Schedule fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + touchDuration) {
            withAnimation(.easeIn(duration: touchFadeOutDuration)) {
                touchesOpacity = 0
            }
        }
    }
}

// MARK: - Helper Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview

struct TrackpadVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 20) {
                TrackpadVisualizer(events: [])
                TrackpadVisualizer(events: [])
            }
        }
    }
} 