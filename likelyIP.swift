import Foundation

func getLikelyUSBCInterfaceIP() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }

    var candidates: [(String, String)] = [] // [(interfaceName, ip)]

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let interface = ptr.pointee
        let name = String(cString: interface.ifa_name)
        let flags = Int32(interface.ifa_flags)

        // Must be IPv4, UP and RUNNING
        guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
              (flags & (IFF_UP|IFF_RUNNING)) == (IFF_UP|IFF_RUNNING)
        else { continue }

        // Extract IP
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                 &hostname, socklen_t(hostname.count),
                                 nil, 0, NI_NUMERICHOST)

        guard result == 0 else { continue }
        let ip = String(cString: hostname)

        // Ignore loopback and APIPA (link-local)
        guard ip != "127.0.0.1", !ip.hasPrefix("169.") else { continue }

        // USB-C interfaces are usually en5/en6/en7
        if name.hasPrefix("en") {
            candidates.append((name, ip))
        }
    }

    // Heuristic: pick first match
    return candidates.first?.1
}
