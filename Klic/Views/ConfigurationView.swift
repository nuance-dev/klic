import SwiftUI

struct ConfigurationView: View {
    @Binding var opacity: Double
    @State private var animateSlider = false
    @Environment(\.presentationMode) var presentationMode
    
    // Constants for smooth animations
    private let sliderTrackHeight: CGFloat = 4
    private let sliderThumbSize: CGFloat = 18
    private let containerCornerRadius: CGFloat = 16
    
    var body: some View {
        VStack(spacing: 32) {
            // Header with modern minimal design
            HStack {
                Text("Klic")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("Display")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 24) {
                    // Opacity control with custom slider
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overlay Opacity")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            // Custom slider with modern design
                            CustomSlider(
                                value: $opacity,
                                range: 0.1...1.0,
                                trackHeight: sliderTrackHeight,
                                thumbSize: sliderThumbSize,
                                animate: animateSlider
                            )
                            .frame(height: sliderThumbSize)
                            
                            // Percentage display
                            Text("\(Int(opacity * 100))%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                    }
                    
                    // Additional settings could be added here
                    // VStack(alignment: .leading, spacing: 12) {
                    //    // Future settings
                    // }
                }
                .padding(.leading, 4)
            }
            
            Spacer()
            
            // Done button with modern style
            Button("Save Changes") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 350, height: 260)
        .background(
            ZStack {
                // Background blur with enhanced effect
                BlurEffectView(material: .popover, blendingMode: .behindWindow)
                
                // Subtle gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color(.windowBackgroundColor).opacity(0.2),
                        Color(.windowBackgroundColor).opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(containerCornerRadius)
        .onAppear {
            // Animate the slider when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    animateSlider = true
                }
            }
        }
    }
}

// Custom slider for a more premium feel
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let trackHeight: CGFloat
    let thumbSize: CGFloat
    let animate: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: trackHeight)
                
                // Filled portion of track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * normalizedValue)), height: trackHeight)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .offset(x: max(0, min(geometry.size.width - thumbSize / 2, geometry.size.width * normalizedValue - thumbSize / 2)))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let width = geometry.size.width
                                let offsetX = min(max(gesture.location.x, 0), width)
                                let percentage = offsetX / width
                                
                                let scaled = range.lowerBound + (range.upperBound - range.lowerBound) * percentage
                                value = scaled
                            }
                    )
                    .scaleEffect(animate ? 1.0 : 0.8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: animate)
            }
        }
    }
    
    // Calculate the normalized value (0-1) from the actual value
    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0),
                                    Color.accentColor.opacity(configuration.isPressed ? 0.7 : 0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Subtle highlight at the top
                    if !configuration.isPressed {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal, 1)
                            .padding(.top, 1)
                            .allowsHitTesting(false)
                    }
                }
            )
            .shadow(color: Color.accentColor.opacity(configuration.isPressed ? 0.1 : 0.3), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ConfigurationView(opacity: .constant(0.8))
} 