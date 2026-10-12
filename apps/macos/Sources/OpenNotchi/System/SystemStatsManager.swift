import Darwin
import Foundation
import SwiftUI

final class SystemStatsManager: ObservableObject {
    static let shared = SystemStatsManager()

    @Published private(set) var downloadSpeed: Double = 0.0
    @Published private(set) var uploadSpeed: Double = 0.0
    @Published private(set) var formattedDown: String = "0 KB/s"
    @Published private(set) var formattedUp: String = "0 KB/s"
    @Published private(set) var cpuUsage: Double = 0.0
    @Published private(set) var formattedCPU: String = "0%"
    @Published private(set) var ramUsage: Double = 0.0
    @Published private(set) var formattedRAM: String = "0%"
    @Published private(set) var ramUsedGB: Double = 0.0
    @Published private(set) var ramTotalGB: Double = 0.0
    @Published private(set) var isNetworkActive: Bool = false

    private var timer: Timer?
    private var prevInBytes: UInt64 = 0
    private var prevOutBytes: UInt64 = 0
    private var prevTime: Date = Date()
    private var prevCpuInfo: host_cpu_load_info?

    init() {
        start()
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil else { return }
        _ = getNetworkBytes()
        _ = getCPULoad()
        updateStats()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func updateStats() {
        // 1. Network Speed
        let (inBytes, outBytes) = getNetworkBytes()
        let now = Date()
        let elapsed = max(now.timeIntervalSince(prevTime), 0.1)
        prevTime = now

        if prevInBytes > 0 || prevOutBytes > 0 {
            let deltaIn = inBytes >= prevInBytes ? inBytes - prevInBytes : 0
            let deltaOut = outBytes >= prevOutBytes ? outBytes - prevOutBytes : 0

            let down = Double(deltaIn) / elapsed
            let up = Double(deltaOut) / elapsed

            downloadSpeed = down
            uploadSpeed = up
            formattedDown = formatSpeed(down)
            formattedUp = formatSpeed(up)
            // Active if downloading > 25 KB/s or uploading > 15 KB/s
            isNetworkActive = down > 25_000 || up > 15_000
        }

        prevInBytes = inBytes
        prevOutBytes = outBytes

        // 2. CPU Usage
        let cpu = getCPULoad()
        cpuUsage = cpu
        formattedCPU = String(format: "%.0f%%", min(max(cpu * 100, 0), 100))

        // 3. RAM Usage
        let (used, total, percent) = getRAM()
        ramUsedGB = used
        ramTotalGB = total
        ramUsage = percent
        formattedRAM = String(format: "%.0f%%", min(max(percent * 100, 0), 100))
    }

    private func getNetworkBytes() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            let name = String(cString: ptr.pointee.ifa_name)
            if !name.hasPrefix("lo") && ptr.pointee.ifa_addr != nil {
                let family = ptr.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_LINK) {
                    if let data = ptr.pointee.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self)
                        totalIn += UInt64(networkData.pointee.ifi_ibytes)
                        totalOut += UInt64(networkData.pointee.ifi_obytes)
                    }
                }
            }
            cursor = ptr.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }

    private func getCPULoad() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0.0 }

        guard let prev = prevCpuInfo else {
            prevCpuInfo = cpuInfo
            return 0.0
        }

        let userDiff = Double(cpuInfo.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDiff = Double(cpuInfo.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDiff = Double(cpuInfo.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDiff = Double(cpuInfo.cpu_ticks.3 - prev.cpu_ticks.3)

        prevCpuInfo = cpuInfo

        let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
        return totalTicks > 0 ? (userDiff + sysDiff + niceDiff) / totalTicks : 0.0
    }

    private func getRAM() -> (usedGB: Double, totalGB: Double, percent: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0, 0) }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let usedBytes = active + wired + compressed

        var totalBytes: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalBytes, &size, nil, 0)

        let total = Double(totalBytes)
        let percent = total > 0 ? (usedBytes / total) : 0.0
        return (usedBytes / (1024 * 1024 * 1024), total / (1024 * 1024 * 1024), percent)
    }

    private func formatSpeed(_ bytes: Double) -> String {
        if bytes >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytes / (1024 * 1024))
        } else if bytes >= 1024 {
            return String(format: "%.0f KB/s", bytes / 1024)
        } else {
            return String(format: "%.0f B/s", bytes)
        }
    }
}
