import NIO
import Foundation

class IGMPMulticastHandler {
    private var group: MultiThreadedEventLoopGroup
    private var bootstrap: DatagramBootstrap
    private var channel: Channel?
    private let multicastGroups: [String] = ["224.0.1.1"] // Add your relay multicast groups
    
    init() {
        // Create a multi-threaded EventLoopGroup
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Configure the bootstrap for UDP
        self.bootstrap = DatagramBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: 1)
            .channelInitializer { channel in
                // Add handlers to the pipeline
                return channel.pipeline.addHandler(IGMPMessageDecoder())
                    .flatMap { channel.pipeline.addHandler(RelayStatusHandler()) }
            }
    }
    
    func startListening(port: Int = 5000) {
        do {
            // Bind to the UDP socket
            let channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
            self.channel = channel
            
            // Join multicast groups
            for groupAddress in multicastGroups {
                try joinMulticastGroup(address: groupAddress, on: channel)
            }
            
            print("IGMP listener started on port \(port)")
        } catch {
            print("Failed to start IGMP listener: \(error)")
        }
    }
    
    private func joinMulticastGroup(address: String, on channel: Channel) throws {
        // Create socket address for the multicast group
        guard let group = try? SocketAddress(ipAddress: address, port: 0) else {
            throw IGMPError.invalidGroupAddress
        }
        
        // Get the socket from the channel
        guard let socketOption = channel.getOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_IP), IP_ADD_MEMBERSHIP)) else {
            throw IGMPError.socketOptionUnavailable
        }
        
        // Create multicast request structure
        var mreq = ip_mreq()
        mreq.imr_multiaddr = group.ipAddress.sin_addr
        mreq.imr_interface.s_addr = INADDR_ANY
        
        // Set the socket option to join the multicast group
        try channel.setOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_IP), IP_ADD_MEMBERSHIP), value: mreq).wait()
        
        print("Joined multicast group: \(address)")
    }
    
    func stop() {
        do {
            try group.syncShutdownGracefully()
            print("IGMP listener stopped")
        } catch {
            print("Error shutting down IGMP listener: \(error)")
        }
    }
    
    enum IGMPError: Error {
        case invalidGroupAddress
        case socketOptionUnavailable
    }
}

// Custom channel handler to decode multicast messages from relays
class IGMPMessageDecoder: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias InboundOut = RelayStatusMessage
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = self.unwrapInboundIn(data)
        let buffer = envelope.data
        
        // Example decoding logic - adapt based on your relay protocol
        if let message = decodeRelayMessage(buffer: buffer) {
            context.fireChannelRead(self.wrapInboundOut(message))
        }
    }
    
    private func decodeRelayMessage(buffer: ByteBuffer) -> RelayStatusMessage? {
        var buffer = buffer
        
        // Read message type (first byte)
        guard let messageType = buffer.readInteger(as: UInt8.self) else {
            return nil
        }
        
        // Read relay ID (next 4 bytes)
        guard let relayId = buffer.readInteger(as: UInt32.self) else {
            return nil
        }
        
        // Read status code
        guard let statusCode = buffer.readInteger(as: UInt16.self) else {
            return nil
        }
        
        // Read timestamp
        guard let timestamp = buffer.readInteger(as: UInt64.self) else {
            return nil
        }
        
        return RelayStatusMessage(
            messageType: messageType,
            relayId: relayId,
            statusCode: statusCode,
            timestamp: timestamp
        )
    }
}

// Handler that processes decoded relay messages
class RelayStatusHandler: ChannelInboundHandler {
    typealias InboundIn = RelayStatusMessage
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = self.unwrapInboundIn(data)
        
        // Handle the relay status message
        processRelayStatus(message)
    }
    
    private func processRelayStatus(_ message: RelayStatusMessage) {
        // Process based on message type
        switch message.messageType {
        case 1: // Example: Protection trip
            print("Relay \(message.relayId) reported protection trip: \(message.statusCode)")
            // Notify UI
            
        case 2: // Example: Warning condition
            print("Relay \(message.relayId) reported warning: \(message.statusCode)")
            // Notify UI
            
        default:
            print("Relay \(message.relayId) sent unknown message type: \(message.messageType)")
        }
    }
}

// Data structure for relay status messages
struct RelayStatusMessage {
    let messageType: UInt8
    let relayId: UInt32
    let statusCode: UInt16
    let timestamp: UInt64
}
