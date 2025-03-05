import SwiftUI

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        VStack(spacing: 20) {
            // App logo
            Image(nsImage: NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "Klic")!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .foregroundStyle(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .symbolEffect(.pulse)
            
            // App name and version
            VStack(spacing: 8) {
                Text("Klic")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // App description
            Text("A next-gen input visualizer for streamers")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Credits
            VStack(spacing: 10) {
                Text("© 2023-2025 Klic Team")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Link("Website", destination: URL(string: "https://klic.app")!)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
        .padding(30)
        .frame(width: 400, height: 400)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    AboutView()
} 