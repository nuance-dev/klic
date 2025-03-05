import SwiftUI

@main
struct KlicApp: App {
    @StateObject private var inputManager = InputManager()
    @State private var isShowingPreferences = false
    @State private var overlayOpacity: Double = 0.9
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inputManager)
                .background(Color.clear)
                .ignoresSafeArea()
                .onAppear {
                    setupApp()
                }
                .sheet(isPresented: $isShowingPreferences) {
                    ConfigurationView(opacity: $overlayOpacity)
                        .onChange(of: overlayOpacity) { oldValue, newValue in
                            UserDefaults.standard.set(newValue, forKey: "overlayOpacity")
                            inputManager.setOpacityPreference(newValue)
                        }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // Add a menu bar extra for settings
        MenuBarExtra {
            Button("Show Overlay") {
                showOverlayFromMenu()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Preferences...") {
                isShowingPreferences = true
                // Ensure app is frontmost when opening preferences
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            VStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 18))
                Text("Klic")
                    .font(.system(size: 10))
            }
        }
    }
    
    private func setupApp() {
        // Get opacity preference if saved
        if let savedOpacity = UserDefaults.standard.object(forKey: "overlayOpacity") as? Double {
            overlayOpacity = savedOpacity
            inputManager.setOpacityPreference(savedOpacity)
        }
        
        // Add delay to ensure proper window configuration after app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.configureWindowAppearance()
        }
        
        // Listen for when the window becomes key to reset its appearance if needed
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.configureWindowAppearance()
        }
        
        // Listen for window resize to ensure proper appearance
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.configureWindowAppearance()
        }
    }
    
    private func configureWindowAppearance() {
        if let window = NSApplication.shared.windows.first {
            // Make window float above other windows
            window.level = .floating
            
            // Make window transparent and non-interactive
            window.isOpaque = false
            window.backgroundColor = NSColor.clear.withAlphaComponent(0)
            window.hasShadow = false
            
            // Ensure mouse events pass through the window
            window.ignoresMouseEvents = true
            
            // Position at the bottom center of the screen
            if let screen = NSScreen.main {
                let screenRect = screen.frame
                let windowSize = CGSize(width: 650, height: 350)
                let origin = CGPoint(
                    x: screenRect.midX - windowSize.width / 2,
                    y: screenRect.minY + 120 // Slightly higher position for better visibility
                )
                window.setFrame(CGRect(origin: origin, size: windowSize), display: true)
            }
            
            // Completely hide the title bar and window controls
            window.styleMask = [.borderless, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            // More aggressively hide window controls
            hideWindowControls(window)
            
            // Ensure window content is properly setup
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                window.titlebarSeparatorStyle = .none
            }
            
            // Ensure it stays above other windows and across spaces
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            
            // Additional settings to fully hide from app management
            window.isExcludedFromWindowsMenu = true
            window.animationBehavior = .none
            
            Logger.debug("Window configured for transparent overlay", log: Logger.app)
        } else {
            Logger.error("Could not find main window to configure", log: Logger.app)
        }
    }
    
    private func hideWindowControls(_ window: NSWindow) {
        // Hide standard window buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Hide the entire titlebar view and traffic light buttons
        if let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview {
            titlebarView.isHidden = true
            titlebarView.alphaValue = 0
        }
        
        // Additional step to hide the titlebar container
        if let titlebarContainerView = findTitlebarContainerView(in: window) {
            titlebarContainerView.isHidden = true
            titlebarContainerView.alphaValue = 0
        }
        
        // Hide any window toolbar if present
        window.toolbar?.isVisible = false
        
        // Ensure no title bar is shown by setting zero height
        window.setContentBorderThickness(0, for: .minY)
        window.setAutorecalculatesContentBorderThickness(false, for: .minY)
        
        // Apply additional steps for complete hiding
        if let contentView = window.contentView, 
           let superview = contentView.superview {
            // Find and hide all subviews that might be related to window controls
            for subview in superview.subviews {
                if String(describing: type(of: subview)).contains("NSTitlebar") || 
                   String(describing: type(of: subview)).contains("NSButton") {
                    subview.isHidden = true
                    subview.alphaValue = 0
                }
            }
        }
    }
    
    private func findTitlebarContainerView(in window: NSWindow) -> NSView? {
        // Find the title bar container view to completely hide it
        if let contentView = window.contentView {
            return findSubview(named: "NSTitlebarContainerView", in: contentView.superview)
        }
        return nil
    }
    
    private func findSubview(named className: String, in view: NSView?) -> NSView? {
        guard let view = view else { return nil }
        
        if String(describing: type(of: view)) == className {
            return view
        }
        
        for subview in view.subviews {
            if let found = findSubview(named: className, in: subview) {
                return found
            }
        }
        
        return nil
    }
    
    private func showOverlayFromMenu() {
        // Ensure window is visible and properly configured
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.orderFront(nil)
                self.configureWindowAppearance()
                
                // Ensure all input monitors are running
                if !self.inputManager.checkMonitoringStatus() {
                    self.inputManager.restartMonitoring()
                }
                
                // Make sure window is properly configured for overlay
                NSApp.activate(ignoringOtherApps: true)
                
                Logger.debug("Show overlay triggered from menu", log: Logger.app)
                
                // Clear any existing events before demo
                self.inputManager.clearAllEvents()
                
                // Create test events for demonstration
                self.showDemoInputs()
            }
        }
    }
    
    private func showDemoInputs() {
        // First clear any existing events
        inputManager.clearAllEvents()
        
        // First show a keyboard shortcut
        let commandKey = InputEvent.keyEvent(
            type: .keyDown,
            keyCode: 55, // Command key
            characters: "⌘",
            modifiers: .command,
            isRepeat: false
        )
        
        let shiftKey = InputEvent.keyEvent(
            type: .keyDown,
            keyCode: 56, // Shift key
            characters: "⇧",
            modifiers: .shift,
            isRepeat: false
        )
        
        let letterKey = InputEvent.keyEvent(
            type: .keyDown,
            keyCode: 15, // R key
            characters: "R",
            modifiers: [.command, .shift],
            isRepeat: false
        )
        
        // Show keyboard shortcut
        self.inputManager.temporarilyAddEvents(events: [commandKey, shiftKey, letterKey], ofType: .keyboard)
        
        // After a short delay, show a trackpad gesture
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Create a trackpad gesture (2-finger swipe)
            let touchA = FingerTouch(
                id: 1,
                position: CGPoint(x: 0.45, y: 0.5),
                pressure: 0.7,
                majorRadius: 6,
                minorRadius: 6,
                fingerType: .index
            )
            
            let touchB = FingerTouch(
                id: 2,
                position: CGPoint(x: 0.55, y: 0.5),
                pressure: 0.7,
                majorRadius: 6,
                minorRadius: 6,
                fingerType: .middle
            )
            
            let trackpadGesture = TrackpadGesture(
                type: .swipe(direction: .up),
                touches: [touchA, touchB],
                magnitude: 0.8,
                rotation: nil
            )
            
            let trackpadEvent = InputEvent.trackpadGestureEvent(gesture: trackpadGesture)
            self.inputManager.temporarilyAddEvents(events: [trackpadEvent], ofType: .trackpad)
            
            // Finally, show a mouse click after another short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let mouseEvent = InputEvent.mouseEvent(
                    type: .mouseDown,
                    position: CGPoint(x: 0.5, y: 0.5),
                    button: .left,
                    scrollDelta: nil,
                    speed: 0
                )
                
                self.inputManager.temporarilyAddEvents(events: [mouseEvent], ofType: .mouse)
            }
        }
    }
}

extension InputManager {
    // Clear all events before showing test events
    func clearAllEvents() {
        keyboardEvents = []
        trackpadEvents = []
        mouseEvents = []
        activeInputTypes = []
        updateAllEvents()
    }
    
    // Add events of specific type temporarily and show overlay
    func temporarilyAddEvents(events: [InputEvent], ofType type: InputType) {
        DispatchQueue.main.async {
            // Add events based on type
            switch type {
            case .keyboard:
                self.keyboardEvents = events
                self.activeInputTypes.insert(.keyboard)
            case .trackpad:
                self.trackpadEvents = events
                self.activeInputTypes.insert(.trackpad)
            case .mouse:
                self.mouseEvents = events
                self.activeInputTypes.insert(.mouse)
            }
            
            // Update all events
            self.updateAllEvents()
            
            // Show the overlay with animation
            withAnimation {
                self.isOverlayVisible = true
                
                // Get the saved opacity preference or use default
                let savedOpacity = UserDefaults.standard.double(forKey: "overlayOpacity")
                self.overlayOpacity = savedOpacity > 0 ? savedOpacity : 0.9
            }
            
            // Set up hide timer after a delay for menu-triggered displays
            let hideDelay: TimeInterval = 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) { [weak self] in
                guard let self = self else { return }
                
                // Only hide this specific input type
                switch type {
                case .keyboard:
                    self.keyboardEvents = []
                case .trackpad:
                    self.trackpadEvents = []
                case .mouse:
                    self.mouseEvents = []
                }
                
                // Remove type from active types
                self.activeInputTypes.remove(type)
                self.updateAllEvents()
                
                // If no active types remain, hide overlay
                if self.activeInputTypes.isEmpty {
                    self.hideOverlay()
                }
            }
        }
    }
}
