import Foundation
import os.log

// Custom logger with enhanced formatting and subsystem organization
enum Logger {
    // Define subsystems
    static let app = OSLog(subsystem: "com.klic.app", category: "Application")
    static let keyboard = OSLog(subsystem: "com.klic.app", category: "Keyboard")
    static let mouse = OSLog(subsystem: "com.klic.app", category: "Mouse")
    static let trackpad = OSLog(subsystem: "com.klic.app", category: "Trackpad")
    static let overlay = OSLog(subsystem: "com.klic.app", category: "Overlay")
    
    // Set log levels - set trackpad to .debug for verbose logging
    private static var logLevels: [OSLog: OSLogType] = [
        app: .info,
        keyboard: .info,
        mouse: .info,
        trackpad: .debug, // Set to .debug to see all trackpad events
        overlay: .info
    ]
    
    // MARK: - Logging Methods
    
    static func debug(_ message: String, log: OSLog) {
        guard logLevels[log] == .debug else { return }
        os_log("[DEBUG] %{public}@", log: log, type: .debug, message)
    }
    
    static func info(_ message: String, log: OSLog) {
        guard logLevels[log] == .debug || logLevels[log] == .info else { return }
        os_log("[INFO] %{public}@", log: log, type: .info, message)
    }
    
    static func warning(_ message: String, log: OSLog) {
        guard logLevels[log] != .error else { return }
        os_log("[WARNING] %{public}@", log: log, type: .default, message)
    }
    
    static func error(_ message: String, log: OSLog) {
        os_log("[ERROR] %{public}@", log: log, type: .error, message)
    }
    
    static func exception(_ message: String, error: Error, log: OSLog) {
        os_log("[EXCEPTION] %{public}@: %{public}@", log: log, type: .fault, message, error.localizedDescription)
    }
}

// Extension to make testing for log level easier
extension OSLogType: Equatable {
    public static func == (lhs: OSLogType, rhs: OSLogType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
} 