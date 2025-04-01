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
    private let useStatusBar = true
    
    // Status bar item reference to keep it from being deallocated
    private var _statusItem: NSStatusItem?
    
    // Public accessor for statusItem
    var statusItem: NSStatusItem? {
        return _statusItem
    }
    
    // Flag to track if this is the first launch
    internal var isFirstLaunch = true
    
    // Notification observers
    private var becomeKeyObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var positionObserver: NSObjectProtocol?
    private var appFinishedLaunchingObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        
        // Register default values
        UserPreferences.registerDefaults()
        
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
            // Setup app to run in the background without dock icon
            NSApp.setActivationPolicy(.accessory)
            
            // Setup menu bar immediately
            self?.setupMenuBar()
            
            // And try again after short delays to ensure it's set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.setupMenuBar()
            }
            
            // And once more after a longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self?._statusItem == nil {
                    Logger.warning("Status bar not set up after initial attempts, trying again", log: Logger.app)
                    self?.setupMenuBar()
                }
                
                // Show welcome demo after a short delay to help users get started
                if self?.isFirstLaunch == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.showOverlayFromMenu()
                        self?.checkPermissions()
                        self?.isFirstLaunch = false
                    }
                }
            }
        }
        
        // Also try to set up the menu bar here, which might help in some cases
        DispatchQueue.main.async { [weak self] in
            self?.setupMenuBar()
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
        
        // Check if app is active - remove the NSApp.isRunning check as it might be unreliable
        guard NSApp.windows.count > 0 else {
            Logger.warning("NSApplication is not fully initialized, will retry later", log: Logger.app)
            // Schedule a retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.setupMenuBar()
            }
            return
        }
        
        // Already set up?
        if _statusItem != nil {
            Logger.debug("Menu bar already set up", log: Logger.app)
            return
        }
        
        Logger.debug("Setting up menu bar", log: Logger.app)
        
        // Create status item in the menu bar
        let newStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = newStatusItem.button {
            // Create a more visually appealing template image
            if let image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "Klic") {
                image.isTemplate = true // Make it a template image so it adapts to the menu bar
                button.image = image
                button.toolTip = "Klic Input Visualizer"
                
                // Force update the button's image
                button.needsDisplay = true
            } else {
                Logger.warning("Failed to create menu bar icon image", log: Logger.app)
                // Fallback to a text representation if image fails
                button.title = "⌨️"
            }
            
            // Create the menu
            let menu = NSMenu()
            
            // Add menu items
            menu.addItem(NSMenuItem(title: "Show Overlay", action: #selector(menuShowOverlay), keyEquivalent: "o"))
            menu.addItem(NSMenuItem(title: "Show Demo", action: #selector(menuShowOverlayDemo), keyEquivalent: "d"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(menuShowPreferences), keyEquivalent: ","))
            menu.addItem(NSMenuItem(title: "Check Permissions...", action: #selector(checkPermissions), keyEquivalent: "p"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "About Klic", action: #selector(showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Klic", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            // Assign the menu to the status item
            newStatusItem.menu = menu
            
            // Store the status item
            self._statusItem = newStatusItem
            
            Logger.info("Menu bar setup successful", log: Logger.app)
        } else {
            Logger.warning("Status item button is nil", log: Logger.app)
        }
    }
    
    @objc func menuShowOverlay() {
        showOverlayFromMenu()
    }
    
    @objc func menuShowOverlayDemo() {
        // Show a demo of various inputs to showcase the app
        NotificationCenter.default.post(name: NSNotification.Name("ShowOverlayDemo"), object: nil)
    }
    
    @objc func menuShowPreferences() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowPreferences"), object: nil)
    }
    
    @objc func showAbout() {
        // Create an about panel with app info
        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = "About Klic"
        
        // Create about content
        let hostingController = NSHostingController(rootView: AboutView())
        aboutWindow.contentView = hostingController.view
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func checkPermissions() {
        // Check if we can monitor keyboard events - this will prompt for accessibility permissions if needed
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            // Show a dialog with instructions
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Klic needs accessibility permissions to monitor keyboard and mouse inputs. Please go to System Preferences > Security & Privacy > Privacy > Accessibility and add Klic to the list of allowed apps."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Preferences to the Accessibility section
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        } else {
            // Show success message
            let alert = NSAlert()
            alert.messageText = "Permissions Granted"
            alert.informativeText = "Klic has the necessary permissions to monitor keyboard and mouse inputs."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func toggleKeyboardInput() {
        // Toggle keyboard input visibility
        let current = UserDefaults.standard.bool(forKey: "showKeyboardInput")
        UserDefaults.standard.set(!current, forKey: "showKeyboardInput")
        
        // Update the menu item state
        if let menu = statusItem?.menu {
            if let inputTypesItem = menu.items.first(where: { $0.title == "Input Types" }),
               let submenu = inputTypesItem.submenu,
               let keyboardItem = submenu.items.first(where: { $0.title == "Keyboard" }) {
                keyboardItem.state = !current ? .on : .off
            }
        }
        
        // Notify of input type change
        NotificationCenter.default.post(name: NSNotification.Name("InputTypesChanged"), object: nil)
    }
    
    @objc func toggleMouseInput() {
        // Toggle mouse input visibility
        let current = UserDefaults.standard.bool(forKey: "showMouseInput")
        UserDefaults.standard.set(!current, forKey: "showMouseInput")
        
        // Update the menu item state
        if let menu = statusItem?.menu {
            if let inputTypesItem = menu.items.first(where: { $0.title == "Input Types" }),
               let submenu = inputTypesItem.submenu,
               let mouseItem = submenu.items.first(where: { $0.title == "Mouse" }) {
                mouseItem.state = !current ? .on : .off
            }
        }
        
        // Notify of input type change
        NotificationCenter.default.post(name: NSNotification.Name("InputTypesChanged"), object: nil)
    }
    
    func configureWindowAppearance() {
        if let window = NSApplication.shared.windows.first {
            // Make window float above other windows
            window.level = .floating
            
            // Make window transparent but not completely invisible initially
            window.isOpaque = false
            window.backgroundColor = NSColor.clear.withAlphaComponent(0)
            window.hasShadow = false
            
            // Initially allow mouse events to be received for a better user experience
            // We'll make it pass-through after showing the first overlay
            window.ignoresMouseEvents = false
            
            // Position at bottom center (fixed position)
            if let screen = NSScreen.main {
                let defaultWindowSize = CGSize(width: 650, height: 350)
                
                // Calculate bottom center position
                let origin = CGPoint(
                    x: screen.frame.midX - defaultWindowSize.width / 2,
                    y: screen.frame.minY + 120 // Fixed position from bottom
                )
                
                // Set window frame
                window.setFrame(CGRect(origin: origin, size: defaultWindowSize), display: true)
                
                // Reset corner radius
                if let contentView = window.contentView?.superview {
                    contentView.layer?.cornerRadius = 0
                }
            }
            
            // Make window visible
            window.orderFront(nil)
            
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
            
            Logger.debug("Window configured for transparent overlay at bottom center", log: Logger.app)
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
                
                // Now that user has interacted with menu, make window ignore mouse events
                window.ignoresMouseEvents = true
                
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

// Extension to check if the app is running
extension NSApplication {
    var isRunning: Bool {
        // The old implementation was causing crashes:
        // return NSApp.windows.count > 0 && NSApp.isActive
        
        // New safer implementation:
        // Only check if the app exists and is active, which is safer
        let windowCount = NSApp.windows.count
        return windowCount > 0 && NSApplication.shared.isActive
    }
}

@main
struct KlicApp: App {
    @StateObject private var inputManager = InputManager.shared
    @State private var isShowingPreferences = false
    @AppStorage("overlayOpacity") private var overlayOpacity: Double = 0.85
    
    // Hold a reference to our AppDelegate to prevent it from being deallocated
    @State private var appDelegate: AppDelegate? = nil
    
    init() {
        // Safely initialize the AppDelegate
        if NSApplication.shared.isRunning {
            self.appDelegate = AppDelegate.shared
        } else {
            // If NSApp isn't ready yet, we'll initialize it in onAppear
            Logger.info("NSApp not ready during init, will initialize AppDelegate later", log: Logger.app)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inputManager)
                .background(Color.clear)
                .onAppear {
                    // Initialize AppDelegate if needed and setup the app
                    if appDelegate == nil {
                        self.appDelegate = AppDelegate.shared
                    }
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
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowOverlayDemo"))) { _ in
                    // Show demo inputs when requested from menu
                    inputManager.showDemoInputs()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appDelegate?.configureWindowAppearance()
            
            // Try to setup menu bar again if needed
            appDelegate?.setupMenuBar()
            
            // Show overlay and check permissions on first launch
            if appDelegate?.isFirstLaunch == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    appDelegate?.showOverlayFromMenu()
                    appDelegate?.checkPermissions()
                    appDelegate?.isFirstLaunch = false
                }
            }
        }
        
        // Make another attempt after a longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if appDelegate?.statusItem == nil {
                Logger.warning("Menu bar still not set up after initial delay, making additional attempt", log: Logger.app)
                // Force the status bar setup
                appDelegate?.setupMenuBar()
                
                // Make sure window is properly configured
                appDelegate?.configureWindowAppearance()
            }
        }
    }
    
    private func showOverlayFromMenu() {
        appDelegate?.showOverlayFromMenu()
    }
}
