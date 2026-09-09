import os

public enum LidLog {
    public static let subsystem = "app.lid"

    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    public static let sensor = Logger(subsystem: subsystem, category: "sensor")
    public static let rules = Logger(subsystem: subsystem, category: "rules")
    public static let actions = Logger(subsystem: subsystem, category: "actions")
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let diagnostics = Logger(subsystem: subsystem, category: "diagnostics")
}
