import Foundation
import Network

struct DiscoveredRobot: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let name: String?
    let model: String?

    var displayName: String {
        name ?? model ?? host
    }
}

@MainActor
class NetworkScanner: ObservableObject {
    @Published var discoveredRobots: [DiscoveredRobot] = []
    @Published var isScanning = false
    @Published var progress: Double = 0

    private var scanTask: Task<Void, Never>?

    func startScan() {
        stopScan()
        discoveredRobots = []
        isScanning = true
        progress = 0

        scanTask = Task {
            await scanNetwork()
            isScanning = false
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func scanNetwork() async {
        // Get local IP to determine subnet
        guard let localIP = getLocalIPAddress() else {
            print("Could not determine local IP address")
            return
        }

        let subnet = getSubnet(from: localIP)
        print("Scanning subnet: \(subnet).x")

        // Scan common IP ranges (1-254)
        let totalHosts = 254
        var scannedHosts = 0

        // Use concurrent scanning for speed
        await withTaskGroup(of: DiscoveredRobot?.self) { group in
            for i in 1...254 {
                let host = "\(subnet).\(i)"

                group.addTask {
                    await self.checkHost(host)
                }

                // Limit concurrent connections
                if i % 20 == 0 {
                    for await result in group {
                        scannedHosts += 1
                        await MainActor.run {
                            self.progress = Double(scannedHosts) / Double(totalHosts)
                        }
                        if let robot = result {
                            await MainActor.run {
                                self.discoveredRobots.append(robot)
                            }
                        }
                    }
                }
            }

            // Collect remaining results
            for await result in group {
                scannedHosts += 1
                await MainActor.run {
                    self.progress = Double(scannedHosts) / Double(totalHosts)
                }
                if let robot = result {
                    await MainActor.run {
                        self.discoveredRobots.append(robot)
                    }
                }
            }
        }

        await MainActor.run {
            self.progress = 1.0
        }
    }

    private func checkHost(_ host: String) async -> DiscoveredRobot? {
        // Quick check if port 80 is open and it's a Valetudo instance
        let url = URL(string: "http://\(host)/api/v2/robot")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5 // Short timeout for scanning

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Try to decode robot info
            let decoder = JSONDecoder()
            if let robotInfo = try? decoder.decode(RobotInfo.self, from: data) {
                return DiscoveredRobot(
                    host: host,
                    name: nil,
                    model: robotInfo.modelName ?? robotInfo.manufacturer
                )
            }

            // If decoding fails but we got 200, it's still likely a Valetudo instance
            return DiscoveredRobot(host: host, name: nil, model: "Valetudo")
        } catch {
            return nil
        }
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }

            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                // Look for WiFi or Ethernet interface
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }

        return address
    }

    private func getSubnet(from ip: String) -> String {
        let components = ip.split(separator: ".")
        guard components.count == 4 else { return "192.168.1" }
        return "\(components[0]).\(components[1]).\(components[2])"
    }
}
