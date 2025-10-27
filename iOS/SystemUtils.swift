import Foundation

func byteString(_ value: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: value)
}

func getDiskSpace() -> Int64 {
    if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
       let size = attrs[.systemSize] as? NSNumber {
        return size.int64Value
    }
    return 0
}

func getFreeDiskSpace() -> Int64 {
    if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
       let free = attrs[.systemFreeSize] as? NSNumber {
        return free.int64Value
    }
    return 0
}

func getUptime() -> String {
    let uptime = ProcessInfo.processInfo.systemUptime
    let hours = Int(uptime) / 3600
    let minutes = (Int(uptime) % 3600) / 60
    return "\(hours)h \(minutes)m"
}

func getCurrentDate() -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: Date())
}

func modelName() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
}

func cpuName() -> String {
    let model = modelName()
    if model.contains("iPhone16") {
        return "A17 Pro"
    } else if model.contains("iPhone15") {
        return "A16 Bionic"
    } else if model.contains("iPhone14") {
        return "A15 Bionic"
    }
    return "Inconnu"
}