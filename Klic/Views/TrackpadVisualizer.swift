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
            
            // Debug - force some opacity on appearance to verify the view is working
            gestureOpacity = 0.8
            touchesOpacity = 0.8
            
            // Then fade it out after a moment (if no real events come in)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.currentGesture == nil && self.activeTouches.isEmpty {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.gestureOpacity = 0
                        self.touchesOpacity = 0
                    }
                }
            }
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
            
            // Log for debugging
            Logger.debug("TrackpadVisualizer: Received gesture: \(gesture.type)", log: Logger.trackpad)
        }
        
        // Find touch events
        if let touchEvent = events.first(where: { $0.trackpadTouches != nil }),
           let touches = touchEvent.trackpadTouches, !touches.isEmpty {
            handleNewTouches(touches)
            
            // Log for debugging
            Logger.debug("TrackpadVisualizer: Received \(touches.count) touches", log: Logger.trackpad)
        }
        
        // For debugging - log event count
        if !events.isEmpty {
            Logger.debug("TrackpadVisualizer: Processing \(events.count) total events", log: Logger.trackpad)
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
        case .tap(let count):
            multiFingerTapVisualization(fingerCount: gesture.touches.count, tapCount: count)
        case .swipe(let direction):
            swipeVisualization(direction: direction, fingerCount: gesture.touches.count)
        case .multiFingerSwipe(let direction, let fingerCount):
            multiFingerSwipeVisualization(direction: direction, fingerCount: fingerCount)
        case .pinch:
            pinchVisualization(gesture: gesture)
        case .rotate:
            rotateVisualization(gesture: gesture)
        case .scroll(_, let deltaX, let deltaY):
            scrollVisualization(deltaX: deltaX, deltaY: deltaY, fingerCount: gesture.touches.count)
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
    private func multiFingerSwipeVisualization(direction: TrackpadGesture.GestureType.SwipeDirection, fingerCount: Int) -> some View {
        ZStack {
            // Direction arrow
            directionArrow(for: direction)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true), value: isAnimating)
            
            // Finger count indicator
            Text("\(fingerCount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .offset(y: -40)
        }
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
    private func scrollVisualization(deltaX: CGFloat, deltaY: CGFloat, fingerCount: Int) -> some View {
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
        case .multiFingerSwipe(let direction, let fingerCount):
            return "\(fingerCount)-finger multi-finger swipe \(direction)"
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
        case .multiFingerSwipe(let direction, let fingerCount):
            return "\(fingerCount)F multi-finger swipe \(direction)"
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
        case .multiFingerSwipe(_, _):
            Image(systemName: "hand.draw")
        }
    }
    
    // MARK: - Event Handling
    
    private func handleNewGesture(_ gesture: TrackpadGesture) {
        // Set the current gesture
        currentGesture = gesture
        
        // Log what we received
        Logger.debug("Displaying trackpad gesture: \(gesture.type)", log: Logger.trackpad)
        
        // Fade in the gesture visualization
        withAnimation(.easeIn(duration: gestureFadeInDuration)) {
            gestureOpacity = 1.0
        }
        
        // Start the animation for the gesture
        isAnimating = true
        withAnimation(.easeInOut(duration: 0.5).repeatCount(2, autoreverses: true)) {
            animationProgress = 1.0
        }
        
        // Schedule the fade out after the gesture duration
        DispatchQueue.main.asyncAfter(deadline: .now() + gestureDuration) {
            // Only fade out if this is still the current gesture
            if self.currentGesture?.id == gesture.id {
                withAnimation(.easeOut(duration: self.gestureFadeOutDuration)) {
                    self.gestureOpacity = 0
                }
                
                // Clear the gesture after it's fully faded out
                DispatchQueue.main.asyncAfter(deadline: .now() + self.gestureFadeOutDuration + 0.1) {
                    if self.currentGesture?.id == gesture.id {
                        self.currentGesture = nil
                        self.isAnimating = false
                        self.animationProgress = 0
                    }
                }
            }
        }
    }
    
    private func handleNewTouches(_ touches: [FingerTouch]) {
        // Set the current touches
        activeTouches = touches
        
        // Log what we received
        Logger.debug("Displaying \(touches.count) trackpad touches", log: Logger.trackpad)
        
        // Fade in the touch visualization
        withAnimation(.easeIn(duration: touchFadeInDuration)) {
            touchesOpacity = 1.0
        }
        
        // Schedule the fade out after the touch duration
        DispatchQueue.main.asyncAfter(deadline: .now() + touchDuration) {
            // Only fade out if these are still the current touches
            withAnimation(.easeOut(duration: self.touchFadeOutDuration)) {
                self.touchesOpacity = 0
            }
            
            // Clear the touches after they've fully faded out
            DispatchQueue.main.asyncAfter(deadline: .now() + self.touchFadeOutDuration + 0.1) {
                self.activeTouches = []
            }
        }
    }
    
    // MARK: - Enhanced Gesture Visualization
    
    // Enhanced multi-finger tap visualization
    private func multiFingerTapVisualization(fingerCount: Int, tapCount: Int) -> some View {
        ZStack {
            // Background pulse for multi-finger gestures
            if fingerCount >= 3 {
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    .frame(width: 80 + CGFloat(fingerCount) * 10, height: 80 + CGFloat(fingerCount) * 10)
                    .scaleEffect(1.0 + animationProgress * 0.3)
                    .opacity(1.0 - animationProgress * 0.5)
            }
            
            // Finger dots arranged in a pattern based on finger count
            ForEach(0..<fingerCount, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .offset(fingerPositionForIndex(index: index, total: fingerCount, radius: 30))
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2).repeatCount(tapCount, autoreverses: true), value: isAnimating)
            }
            
            // Tap count indicator
            if tapCount > 1 {
                Text("\(tapCount)×")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    // Helper to position fingers in a circular pattern
    private func fingerPositionForIndex(index: Int, total: Int, radius: CGFloat) -> CGSize {
        if total == 1 {
            return CGSize.zero
        }
        
        let angle = (2.0 * .pi / CGFloat(total)) * CGFloat(index) - .pi / 2
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }
    
    // MARK: - Helper Methods for Gesture Visualization
    
    // Create a direction arrow path based on the swipe direction
    private func directionArrow(for direction: TrackpadGesture.GestureType.SwipeDirection) -> Path {
        Path { path in
            switch direction {
            case .up:
                // Up arrow
                path.move(to: CGPoint(x: 30, y: 45))
                path.addLine(to: CGPoint(x: 30, y: 15))
                path.move(to: CGPoint(x: 20, y: 25))
                path.addLine(to: CGPoint(x: 30, y: 15))
                path.addLine(to: CGPoint(x: 40, y: 25))
            case .down:
                // Down arrow
                path.move(to: CGPoint(x: 30, y: 15))
                path.addLine(to: CGPoint(x: 30, y: 45))
                path.move(to: CGPoint(x: 20, y: 35))
                path.addLine(to: CGPoint(x: 30, y: 45))
                path.addLine(to: CGPoint(x: 40, y: 35))
            case .left:
                // Left arrow
                path.move(to: CGPoint(x: 45, y: 30))
                path.addLine(to: CGPoint(x: 15, y: 30))
                path.move(to: CGPoint(x: 25, y: 20))
                path.addLine(to: CGPoint(x: 15, y: 30))
                path.addLine(to: CGPoint(x: 25, y: 40))
            case .right:
                // Right arrow
                path.move(to: CGPoint(x: 15, y: 30))
                path.addLine(to: CGPoint(x: 45, y: 30))
                path.move(to: CGPoint(x: 35, y: 20))
                path.addLine(to: CGPoint(x: 45, y: 30))
                path.addLine(to: CGPoint(x: 35, y: 40))
            }
        }
    }
    
    // Helper to create a pulsing animation effect
    private func pulsingAnimation(duration: Double = 1.0) -> Animation {
        Animation.easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
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

struct Arrow: View {
    enum Direction {
        case up, down, left, right
    }
    
    let direction: Direction
    let length: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, geometry.size.height) * 0.1
            let arrowHeadSize = width * 3
            
            ZStack {
                // Line
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(
                        width: direction == .left || direction == .right ? length : width,
                        height: direction == .up || direction == .down ? length : width
                    )
                
                // Arrow head
                Triangle()
                    .fill(Color.accentColor)
                    .frame(width: arrowHeadSize, height: arrowHeadSize)
                    .rotationEffect(
                        .degrees(
                            direction == .up ? 0 :
                            direction == .down ? 180 :
                            direction == .left ? 270 :
                            90
                        )
                    )
                    .offset(
                        x: direction == .right ? length / 2 :
                           direction == .left ? -length / 2 : 0,
                        y: direction == .down ? length / 2 :
                           direction == .up ? -length / 2 : 0
                    )
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
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