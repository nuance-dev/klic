import SwiftUI
import AppKit

// Class for handling AppKit/Objective-C related tasks that can't be in a struct
final class AppDelegate: NSObject {
    static let shared: AppDelegate = {
        let instance = AppDelegate()
        Logger.info("AppDelegate singleton initialized", log: Logger.app)
        return instance
    }()
    
    // Use this flag to control whether to use status bar or not
    private let useStatusBar = false
    
    // Status bar item reference to keep it from being deallocated
    private var statusItem: NSStatusItem?
    
    // Notification observers
    private var becomeKeyObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var positionObserver: NSObjectProtocol?
    private var appFinishedLaunchingObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        
        // Register default values
        UserPreferences.registerDefaults()
        
        // DO NOT create status bar here - wait until the app has finished launching
        
        // Listen for when the window becomes key to reset its appearance if needed
        becomeKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureWindowAppearance()
        }
        
        // Listen for window resize to ensure proper appearance
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureWindowAppearance()
        }
        
        // Listen for position change notifications
        positionObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ReconfigureOverlayPosition"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reconfigure window appearance when position changes
            self?.configureWindowAppearance()
        }
        
        // Add observer for app finished launching
        appFinishedLaunchingObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay the setup of menu bar to ensure everything is initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.setupMenuBar()
            }
        }
        
        Logger.info("AppDelegate initialized successfully", log: Logger.app)
    }
    
    deinit {
        // Remove all observers
        [becomeKeyObserver, resizeObserver, positionObserver, appFinishedLaunchingObserver].forEach { observer in
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    func setupMenuBar() {
        // If we don't want to use status bar, just return
        if !useStatusBar {
            Logger.info("Status bar disabled, skipping setup", log: Logger.app)
            return
        }
        
        // Make sure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.setupMenuBar()
            }
            return
        }
        
        // Check if app is active and running
        guard NSApp.isRunning else {
            Logger.warning("Tried to setup menu bar before app is running", log: Logger.app)
            return
        }
        
        // Already set up?
        if statusItem != nil {
            Logger.debug("Menu bar already set up", log: Logger.app)
            return
        }
        
        do {
            Logger.debug("Setting up menu bar", log: Logger.app)
            
            // Use try-catch to handle any potential exceptions
            try autoreleasepool {
                // Create status item in the menu bar
                let newStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                self.statusItem = newStatusItem
                
                if let button = newStatusItem.button {
                    button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Klic")
                    button.toolTip = "Klic Input Visualizer"
                } else {
                    Logger.warning("Status item button is nil", log: Logger.app)
                }
                
                // Create menu
                let menu = NSMenu()
                
                // Add menu items
                menu.addItem(NSMenuItem(title: "Show Overlay", action: #selector(menuShowOverlay), keyEquivalent: "o"))
                menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(menuShowPreferences), keyEquivalent: ","))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Quit Klic", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
                
                newStatusItem.menu = menu
                
                Logger.info("Menu bar setup completed successfully", log: Logger.app)
            }
        } catch {
            Logger.exception(error, context: "Setting up menu bar", log: Logger.app)
        }
    }
    
    @objc func menuShowOverlay() {
        showOverlayFromMenu()
    }
    
    @objc func menuShowPreferences() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowPreferences"), object: nil)
    }
    
    func configureWindowAppearance() {
        if let window = NSApplication.shared.windows.first {
            // Make window float above other windows
            window.level = .floating
            
            // Make window transparent and non-interactive
            window.isOpaque = false
            window.backgroundColor = NSColor.clear.withAlphaComponent(0)
            window.hasShadow = false
            
            // Ensure mouse events pass through the window
            window.ignoresMouseEvents = true
            
            // Get the overlay position preference
            let positionPreference = UserDefaults.standard.string(forKey: "overlayPosition") ?? OverlayPosition.bottomCenter.rawValue
            let position = OverlayPosition.allCases.first { $0.rawValue == positionPreference } ?? .bottomCenter
            
            // Position based on preference
            if let screen = NSScreen.main {
                let defaultWindowSize = CGSize(width: 650, height: 350)
                
                // Adjust size based on position
                let sizeAdjustment = position.getSizeAdjustment()
                let adjustedWindowSize = CGSize(
                    width: defaultWindowSize.width * sizeAdjustment.width,
                    height: defaultWindowSize.height * sizeAdjustment.height
                )
                
                // Get position based on preference
                let origin = position.getPositionOrigin(for: screen, windowSize: adjustedWindowSize)
                
                // Set window frame
                window.setFrame(CGRect(origin: origin, size: adjustedWindowSize), display: true)
                
                // Special styling for expanded notch
                if position == .expandedNotch {
                    // Apply special corner radius for notch appearance
                    if let contentView = window.contentView?.superview {
                        contentView.wantsLayer = true
                        contentView.layer?.cornerRadius = 12
                        contentView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                } else {
                    // Reset corner radius for other positions
                    if let contentView = window.contentView?.superview {
                        contentView.layer?.cornerRadius = 0
                    }
                }
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
    
    func showOverlayFromMenu() {
        // Ensure window is visible and properly configured
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.orderFront(nil)
                self.configureWindowAppearance()
                
                // Ensure all input monitors are running
                if !InputManager.shared.checkMonitoringStatus() {
                    InputManager.shared.restartMonitoring()
                }
                
                // Make sure window is properly configured for overlay
                NSApp.activate(ignoringOtherApps: true)
                
                Logger.debug("Show overlay triggered from menu", log: Logger.app)
                
                // Clear any existing events before demo
                InputManager.shared.clearAllEvents()
                
                // Create test events for demonstration
                InputManager.shared.showDemoInputs()
            }
        }
    }
}

// Overlay position enum
enum OverlayPosition: String, CaseIterable, Identifiable {
    case bottomCenter = "Bottom Center"
    case topCenter = "Top Center"
    case expandedNotch = "Expanded Notch" // New option for notch MacBooks
    
    var id: String { self.rawValue }
    
    // Return CGPoint for positioning based on screen size
    func getPositionOrigin(for screen: NSScreen, windowSize: CGSize) -> CGPoint {
        let screenRect = screen.frame
        
        switch self {
        case .bottomCenter:
            return CGPoint(
                x: screenRect.midX - windowSize.width / 2,
                y: screenRect.minY + 120 // Slightly higher from bottom
            )
        case .topCenter:
            return CGPoint(
                x: screenRect.midX - windowSize.width / 2,
                y: screenRect.maxY - windowSize.height - 20 // Slightly below top
            )
        case .expandedNotch:
            // Calculate position to align with notch on MacBooks with notch
            // Notch is usually centered at the top
            let notchWidth: CGFloat = 200 // Approximate notch width
            let expandedWidth = notchWidth * 2 // Wider than notch for better aesthetic
            
            // Make it narrower for this special position
            let adjustedWindowSize = CGSize(width: min(windowSize.width, expandedWidth), height: windowSize.height * 0.7)
            
            return CGPoint(
                x: screenRect.midX - adjustedWindowSize.width / 2,
                y: screenRect.maxY - adjustedWindowSize.height - 5 // Very close to top
            )
        }
    }
    
    // Get window size adjustment factor for special positions
    func getSizeAdjustment() -> CGSize {
        switch self {
        case .expandedNotch:
            return CGSize(width: 0.4, height: 0.7) // 40% width, 70% height for notch
        default:
            return CGSize(width: 1.0, height: 1.0) // Default size
        }
    }
}

// Extension to check if the app is running
extension NSApplication {
    var isRunning: Bool {
        return NSApp.windows.count > 0 && NSApp.isActive
    }
}

@main
struct KlicApp: App {
    @StateObject private var inputManager = InputManager.shared
    @State private var isShowingPreferences = false
    @AppStorage("overlayOpacity") private var overlayOpacity: Double = 0.85
    
    // Hold a reference to our AppDelegate to prevent it from being deallocated
    @State private var appDelegate = AppDelegate.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inputManager)
                .background(Color.clear)
                .onAppear {
                    setupApp()
                }
                .sheet(isPresented: $isShowingPreferences) {
                    ConfigurationView(opacity: $overlayOpacity)
                        .onChange(of: overlayOpacity) { oldValue, newValue in
                            // Save the new opacity preference
                            inputManager.setOpacityPreference(newValue)
                        }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowPreferences"))) { _ in
                    isShowingPreferences = true
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Show Overlay") {
                    showOverlayFromMenu()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Preferences...") {
                    isShowingPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
    
    private func setupApp() {
        // Configure window appearance with a delay to ensure it's ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            appDelegate.configureWindowAppearance()
            
            // Try to setup menu bar again if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appDelegate.setupMenuBar()
            }
        }
    }
    
    private func showOverlayFromMenu() {
        appDelegate.showOverlayFromMenu()
    }
}

extension InputManager {
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
