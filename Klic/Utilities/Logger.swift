import Foundation
import os.log

class Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.minimal.Klic"
    
    static let keyboard = OSLog(subsystem: subsystem, category: "keyboard")
    static let mouse = OSLog(subsystem: subsystem, category: "mouse")
    static let trackpad = OSLog(subsystem: subsystem, category: "trackpad")
    static let app = OSLog(subsystem: subsystem, category: "app")
    
    static func debug(_ message: String, log: OSLog = app) {
        os_log("%{public}s", log: log, type: .debug, message)
    }
    
    static func info(_ message: String, log: OSLog = app) {
        os_log("%{public}s", log: log, type: .info, message)
    }
    
    static func warning(_ message: String, log: OSLog = app) {
        os_log("%{public}s", log: log, type: .default, message)
    }
    
    static func error(_ message: String, log: OSLog = app) {
        os_log("%{public}s", log: log, type: .error, message)
    }
    
    static func exception(_ error: Error, context: String? = nil, log: OSLog = app) {
        let contextMessage = context != nil ? " in context: \(context!)" : ""
        os_log("Exception%{public}s: %{public}s", log: log, type: .fault, contextMessage, error.localizedDescription)
    }
} 