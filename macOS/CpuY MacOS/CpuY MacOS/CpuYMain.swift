import SwiftUI
import AppKit
import IOKit
import IOKit.usb
import Darwin

// -----------------------------
// Mach constants for CPU / Memory
// -----------------------------
let HOST_VM_INFO64_COUNT = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
let HOST_CPU_LOAD_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

// -----------------------------
// Models
// -----------------------------
struct DisplayInfo: Identifiable {
    let id = UUID()
    let name: String
    let resolution: String
    let scale: CGFloat
    let isMain: Bool
}

struct USBDeviceInfo: Identifiable {
    let id = UUID()
    let name: String?
    let vendorID: Int?
    let productID: Int?
}

struct DiskPartitionInfo: Identifiable {
    let id = UUID()
    let name: String
    let mountPoint: String?
    let deviceIdentifier: String?
    let fsType: String?
    let sizeBytes: UInt64?
    let freeSpaceBytes: UInt64?
}

struct DiskInfo: Identifiable {
    let id = UUID()
    let name: String
    let model: String?
    let sizeBytes: UInt64?
    let deviceIdentifier: String?
    let partitions: [DiskPartitionInfo]
}

// -----------------------------
// ViewModel
// -----------------------------
final class SysInfoViewModel: ObservableObject {
    // Overview
    @Published var osVersion: String = "Loading..."
    @Published var kernelVersion: String = "Loading..."
    @Published var hostname: String = "Loading..."
    @Published var uptime: String = "Loading..."
    @Published var serialNumber: String = "Loading..."
    
    // CPU & Memory
    @Published var cpuBrand: String = "Loading..."
    @Published var cpuCores: Int = 0
    @Published var cpuUsagePercent: Double = 0.0
    @Published var ramTotalGB: Double = 0.0
    @Published var ramUsedGB: Double = 0.0
    
    // Displays & GPU
    @Published var displays: [DisplayInfo] = []
    @Published var gpuNames: [String] = []
    
    // Storage
    @Published var disks: [DiskInfo] = []
    @Published var mountedVolumes: [DiskPartitionInfo] = []
    private var isStorageLoaded = false
    
    // USB
    @Published var usbDevices: [USBDeviceInfo] = []
    
    // internals
    private var cpuPrevTicks: [UInt32] = []
    private var timer: Timer?
    
    private var usbAddedIterator: io_iterator_t = 0
    private var usbRemovedIterator: io_iterator_t = 0
    
    init() {
        fetchQuickOverview()
        fetchCPUStatic()
        updateLiveStats()
        setupLiveUpdates()
        setupUSBNotifications()
        
        // async heavy info
        DispatchQueue.global(qos: .utility).async {
            self.fetchFullOverviewAndStorage()
            self.fetchDisplaysAndGPU()
        }
    }
    
    // MARK: - Quick Overview
    private func fetchQuickOverview() {
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        var unameInfo = utsname()
        uname(&unameInfo)
        let release = withUnsafePointer(to: &unameInfo.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        kernelVersion = release
        hostname = Host.current().localizedName ?? "Unknown"
        
        let uptimeSeconds = ProcessInfo.processInfo.systemUptime
        let days = Int(uptimeSeconds) / 86400
        let hours = (Int(uptimeSeconds) % 86400) / 3600
        let minutes = (Int(uptimeSeconds) % 3600) / 60
        if days > 0 { uptime = "\(days)d \(hours)h \(minutes)m)" }
        else if hours > 0 { uptime = "\(hours)h \(minutes)m)" }
        else { uptime = "\(minutes)m" }
    }
    
    private func fetchCPUStatic() {
        if let brand = SystemInfo.getSysctlString(for: "machdep.cpu.brand_string") {
            cpuBrand = brand
        }
        if let cores = SystemInfo.getSysctlInt(for: "hw.physicalcpu") ?? SystemInfo.getSysctlInt(for: "hw.ncpu") {
            cpuCores = cores
        }
        ramTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0
    }
    
    // MARK: - Live CPU & RAM Updates
    private func setupLiveUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateLiveStats()
        }
    }
    
    private func updateLiveStats() {
        DispatchQueue.global(qos: .userInteractive).async {
            if let usage = SystemInfo.getCPUUsage(previousTicks: &self.cpuPrevTicks) {
                DispatchQueue.main.async { self.cpuUsagePercent = usage * 100 }
            }
            let (used, total) = SystemInfo.getMemoryUsageGB()
            DispatchQueue.main.async {
                self.ramUsedGB = used
                self.ramTotalGB = total
            }
        }
    }
    
    // MARK: - USB Live Notifications
    private func setupUSBNotifications() {
        let matching = IOServiceMatching(kIOUSBDeviceClassName)
        let notifyPort = IONotificationPortCreate(kIOMasterPortDefault)
        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        
        IOServiceAddMatchingNotification(notifyPort,
                                         kIOFirstMatchNotification,
                                         matching,
                                         { (refcon, iterator) in
                                             let vm = Unmanaged<SysInfoViewModel>.fromOpaque(refcon!).takeUnretainedValue()
                                             vm.updateUSB(iterator: iterator)
                                         },
                                         UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                                         &usbAddedIterator)
        updateUSB(iterator: usbAddedIterator)
        
        IOServiceAddMatchingNotification(notifyPort,
                                         kIOTerminatedNotification,
                                         matching,
                                         { (refcon, iterator) in
                                             let vm = Unmanaged<SysInfoViewModel>.fromOpaque(refcon!).takeUnretainedValue()
                                             vm.updateUSB(iterator: iterator)
                                         },
                                         UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                                         &usbRemovedIterator)
        updateUSB(iterator: usbRemovedIterator)
    }
    
    private func updateUSB(iterator: io_iterator_t) {
        var devices: [USBDeviceInfo] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let name = (IORegistryEntryCreateCFProperty(service, kUSBProductString as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String)
            let vendor = (IORegistryEntryCreateCFProperty(service, kUSBVendorID as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int32).map { Int($0) }
            let product = (IORegistryEntryCreateCFProperty(service, kUSBProductID as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int32).map { Int($0) }
            devices.append(USBDeviceInfo(name: name, vendorID: vendor, productID: product))
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        DispatchQueue.main.async { self.usbDevices = devices }
    }
    
    // MARK: - Heavy async fetches
    private func fetchFullOverviewAndStorage() {
        // Serial Number
        if let hw = try? SystemInfo.runSystemProfiler(types: ["SPHardwareDataType"]),
           let serial = SystemInfo.findFirstValue(for: "serial_number", in: hw) {
            DispatchQueue.main.async { self.serialNumber = serial }
        }
        fetchStorageIfNeeded()
    }
    
    func fetchStorageIfNeeded(force: Bool = false) {
        guard !isStorageLoaded || force else { return }
        isStorageLoaded = true
        fetchMountedVolumes()
        
        DispatchQueue.global(qos: .utility).async {
            if let json = try? SystemInfo.runSystemProfiler(types: ["SPStorageDataType"]) {
                var disksResult: [DiskInfo] = []
                if let spArr = SystemInfo.arrayForKey("SPStorageDataType", in: json) {
                    for case let diskEntry as [String: Any] in spArr {
                        let name = (diskEntry["_name"] as? String) ?? (diskEntry["name"] as? String) ?? "Disk"
                        let model = diskEntry["device_model"] as? String ?? diskEntry["bsd_name"] as? String
                        var sizeBytes: UInt64? = nil
                        if let sizeStr = diskEntry["size"] as? String,
                           let bytes = SystemInfo.extractBytes(from: sizeStr) { sizeBytes = bytes }
                        var deviceIdentifier: String? = diskEntry["device_identifier"] as? String
                        var parts: [DiskPartitionInfo] = []
                        if let sub = diskEntry["_items"] as? [[String: Any]] {
                            for part in sub {
                                let pname = (part["_name"] as? String) ?? (part["name"] as? String) ?? "Partition"
                                let mountPoint = part["mount_point"] as? String
                                let fsType = part["file_system"] as? String ?? part["filesystem"] as? String
                                var partSize: UInt64? = nil
                                if let psize = part["size"] as? String,
                                   let bytes = SystemInfo.extractBytes(from: psize) { partSize = bytes }
                                let bsd = part["device_identifier"] as? String
                                var freeBytes: UInt64? = nil
                                if let mount = mountPoint,
                                   let attrs = try? FileManager.default.attributesOfFileSystem(forPath: mount),
                                   let free = attrs[.systemFreeSize] as? NSNumber { freeBytes = free.uint64Value }
                                parts.append(DiskPartitionInfo(name: pname, mountPoint: mountPoint, deviceIdentifier: bsd, fsType: fsType, sizeBytes: partSize, freeSpaceBytes: freeBytes))
                            }
                        }
                        disksResult.append(DiskInfo(name: name, model: model, sizeBytes: sizeBytes, deviceIdentifier: deviceIdentifier, partitions: parts))
                    }
                }
                DispatchQueue.main.async { self.disks = disksResult }
            }
        }
    }
    
    private func fetchMountedVolumes() {
        var mounts: [DiskPartitionInfo] = []
        let fm = FileManager.default
        if let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey], options: []) {
            for url in urls {
                let name = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.lastPathComponent
                let mountPoint = url.path
                let attrs = try? FileManager.default.attributesOfFileSystem(forPath: mountPoint)
                let total = attrs?[.systemSize] as? UInt64
                let free = attrs?[.systemFreeSize] as? UInt64
                mounts.append(DiskPartitionInfo(name: name, mountPoint: mountPoint, deviceIdentifier: nil, fsType: nil, sizeBytes: total, freeSpaceBytes: free))
            }
        }
        DispatchQueue.main.async { self.mountedVolumes = mounts }
    }
    
    private func fetchDisplaysAndGPU() {
        var newDisplays: [DisplayInfo] = []
        DispatchQueue.main.sync {
            for screen in NSScreen.screens {
                let size = screen.frame.size
                let scale = screen.backingScaleFactor
                let res = String(format: "%.0fx%.0f", size.width * scale, size.height * scale)
                let name = (screen.deviceDescription[NSDeviceDescriptionKey("NSDeviceName")] as? String) ?? "Display"
                newDisplays.append(DisplayInfo(name: name, resolution: res, scale: scale, isMain: screen == NSScreen.main))
            }
        }
        DispatchQueue.main.async { self.displays = newDisplays }
        
        if let json = try? SystemInfo.runSystemProfiler(types: ["SPDisplaysDataType"]) {
            var gpuNames: [String] = []
            if let items = SystemInfo.arrayForKey("SPDisplaysDataType", in: json) {
                for case let item as [String: Any] in items {
                    if let name = item["_name"] as? String { gpuNames.append(name) }
                }
            }
            DispatchQueue.main.async { self.gpuNames = Set(gpuNames).sorted() }
        }
    }
    
    // -----------------------------
    // Helpers
    // -----------------------------
    func bytesToHuman(_ bytes: UInt64) -> String {
        let units = ["B","KB","MB","GB","TB"]
        var value = Double(bytes)
        var i = 0
        while value >= 1024.0 && i < units.count-1 {
            value /= 1024.0
            i += 1
        }
        return String(format: "%.2f %@", value, units[i])
    }
}

// -----------------------------
// SystemInfo helpers
// -----------------------------
enum SystemInfo {
    static func runSystemProfiler(types: [String]) throws -> [String: Any] {
        let args = ["system_profiler", "-json"] + types
        let output = try runCommandBinary(args: args)
        if let data = output.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = obj as? [String: Any] { return dict }
        return [:]
    }
    
    static func runCommandBinary(args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    static func arrayForKey(_ key: String, in dict: [String: Any]) -> [Any]? { dict[key] as? [Any] }
    
    static func findFirstValue(for keyLower: String, in dict: [String: Any]) -> String? {
        for (_, v) in dict {
            if let arr = v as? [[String: Any]] {
                for item in arr {
                    for (k, val) in item { if k.lowercased().contains(keyLower), let s = val as? String { return s } }
                }
            }
        }
        return nil
    }
    
    static func extractBytes(from sizeString: String) -> UInt64? {
        if let range = sizeString.range(of: #"(\d[\d,]*)\s*bytes"#, options: .regularExpression) {
            let match = String(sizeString[range])
            let digits = match.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
            return UInt64(digits)
        }
        return nil
    }
    
    static func getSysctlString(for name: String) -> String? {
        var size: Int = 0
        if sysctlbyname(name, nil, &size, nil, 0) != 0 { return nil }
        var buf = [CChar](repeating: 0, count: size)
        if sysctlbyname(name, &buf, &size, nil, 0) != 0 { return nil }
        return String(cString: buf)
    }
    
    static func getSysctlInt(for name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname(name, &value, &size, nil, 0) == 0 { return Int(value) }
        return nil
    }
    
    static func getMemoryUsageGB() -> (used: Double, total: Double) {
        var stats = vm_statistics64()
        var size = HOST_VM_INFO64_COUNT
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        if result != KERN_SUCCESS { return (0.0, Double(ProcessInfo.processInfo.physicalMemory)/1024/1024/1024) }
        let pageSize = Double(vm_kernel_page_size)
        let free = Double(stats.free_count) * pageSize
        let active = Double(stats.active_count) * pageSize
        let inactive = Double(stats.inactive_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let usedGB = (active + inactive + wired) / 1024 / 1024 / 1024
        let totalGB = (usedGB + free / 1024 / 1024 / 1024)
        return (usedGB, totalGB)
    }
    
    static func getCPUUsage(previousTicks: inout [UInt32]) -> Double? {
        var count = HOST_CPU_LOAD_INFO_COUNT
        var info = host_cpu_load_info()
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if kr != KERN_SUCCESS { return nil }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
        if previousTicks.isEmpty { previousTicks = ticks; return nil }
        let deltas = zip(ticks, previousTicks).map { Double($0 - $1) }
        previousTicks = ticks
        let total = deltas.reduce(0, +)
        return total > 0 ? (deltas[0]+deltas[1]+deltas[2])/total : 0.0
    }
}

// -----------------------------
// Views
// -----------------------------
struct OverviewView: View {
    @ObservedObject var vm: SysInfoViewModel
    var body: some View {
        List {
            HStack { Text("OS Version"); Spacer(); Text(vm.osVersion) }
            HStack { Text("Kernel"); Spacer(); Text(vm.kernelVersion) }
            HStack { Text("Hostname"); Spacer(); Text(vm.hostname) }
            HStack { Text("Uptime"); Spacer(); Text(vm.uptime) }
            HStack { Text("Serial Number"); Spacer(); Text(vm.serialNumber) }
        }.padding()
    }
}

struct CPUView: View {
    @ObservedObject var vm: SysInfoViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CPU & Memory").font(.title2).bold()
            Text("CPU: \(vm.cpuBrand) (\(vm.cpuCores) cores)")
            Text("CPU Usage: \(String(format: "%.1f", vm.cpuUsagePercent))%")
            Text("RAM Used: \(String(format: "%.2f", vm.ramUsedGB)) GB / \(String(format: "%.2f", vm.ramTotalGB)) GB")
            Spacer()
        }.padding()
    }
}

struct DisplayView: View {
    @ObservedObject var vm: SysInfoViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Displays & GPU").font(.title2).bold()
            ForEach(vm.displays) { d in
                Text("\(d.name): \(d.resolution) \(d.isMain ? "(Main)" : "")")
            }
            Text("GPU(s): \(vm.gpuNames.joined(separator: ", "))")
            Spacer()
        }.padding()
    }
}

struct StorageView: View {
    @ObservedObject var vm: SysInfoViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Storage").font(.title2).bold()
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("Disks").font(.headline)
                    List(vm.disks) { disk in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(disk.name).bold()
                                Spacer()
                                if let size = disk.sizeBytes { Text(vm.bytesToHuman(size)) }
                            }
                            if let model = disk.model { Text("Model: \(model)").font(.caption) }
                            if !disk.partitions.isEmpty {
                                Text("Partitions:").font(.caption).padding(.top, 6)
                                ForEach(disk.partitions) { p in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(p.name)
                                            if let fs = p.fsType { Text(fs).font(.caption2) }
                                            if let mount = p.mountPoint { Text("Mount: \(mount)").font(.caption2) }
                                        }
                                        Spacer()
                                        if let size = p.sizeBytes { Text(vm.bytesToHuman(size)).font(.caption2) }
                                        if let free = p.freeSpaceBytes { Text("Free: \(vm.bytesToHuman(free))").font(.caption2) }
                                    }.padding(.vertical, 2)
                                }
                            }
                        }.padding(.vertical, 6)
                    }
                    .frame(minWidth: 360, minHeight: 300)
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Mounted Volumes").font(.headline)
                    List(vm.mountedVolumes) { vol in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(vol.name).bold()
                                if let m = vol.mountPoint { Text(m).font(.caption2) }
                            }
                            Spacer()
                            if let size = vol.sizeBytes { Text(vm.bytesToHuman(size)).font(.caption2) }
                            if let free = vol.freeSpaceBytes { Text("Free: \(vm.bytesToHuman(free))").font(.caption2) }
                        }
                    }.frame(minWidth: 320, minHeight: 300)
                }
            }
            Spacer()
        }
        .padding()
        .onAppear { vm.fetchStorageIfNeeded() }
    }
}

struct USBView: View {
    @ObservedObject var vm: SysInfoViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("USB Devices").font(.title2).bold()
            List(vm.usbDevices) { dev in
                HStack {
                    Text(dev.name ?? "Unknown")
                    Spacer()
                    Text("VID: \(dev.vendorID ?? 0) PID: \(dev.productID ?? 0)")
                }
            }
            Spacer()
        }.padding()
    }
}

// -----------------------------
// Main App
// -----------------------------
@main
struct CpuYApp: App {
    @StateObject var vm = SysInfoViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                OverviewView(vm: vm)
                    .tabItem { Text("Overview") }
                CPUView(vm: vm)
                    .tabItem { Text("CPU & Memory") }
                DisplayView(vm: vm)
                    .tabItem { Text("Display & GPU") }
                StorageView(vm: vm)
                    .tabItem { Text("Storage") }
                USBView(vm: vm)
                    .tabItem { Text("USB & Devices") }
            }
            .frame(minWidth: 800, minHeight: 600)
        }
    }
}
