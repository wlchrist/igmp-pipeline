import NIOPosix
import Darwin

// Assuming `channel` is your bound UDP channel:
let multicastGroup = try! SocketAddress(ipAddress: "239.255.255.250", port: 1900)
let localInterface = in_addr(s_addr: INADDR_ANY.bigEndian) // or specific IP if needed

var mreq = ip_mreq(imr_multiaddr: in_addr(s_addr: inet_addr("239.255.255.250")),
                   imr_interface: localInterface)

let fd = (channel as! DatagramChannel).socket.fd
withUnsafePointer(to: &mreq) { ptr in
    let result = setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, ptr, socklen_t(MemoryLayout<ip_mreq>.size))
    if result != 0 {
        perror("setsockopt - IP_ADD_MEMBERSHIP")
    }
}