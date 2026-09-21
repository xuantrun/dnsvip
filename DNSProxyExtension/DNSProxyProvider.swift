import Foundation
import NetworkExtension
import Network

public class DNSProxyProvider: NEPacketTunnelProvider {

    private var inMemoryLogs: [DNSQueryLogItem] = []
    private let maxInMemoryLogs = 300
    private let virtualInterfaceIP = "198.18.0.1"
    private let virtualDNSServerIP = "198.18.0.2"

    public override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[DNS VIP] Packet Tunnel starting...")

        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // 1. Virtual Tunnel Interface (Client IP: 198.18.0.1)
        let ipv4Settings = NEIPv4Settings(addresses: [virtualInterfaceIP], subnetMasks: ["255.255.255.0"])
        
        // 2. Included Routes: Route virtual DNS server IP (198.18.0.2) into the tunnel
        // Crucial: 198.18.0.2 is DIFFERENT from interface IP 198.18.0.1 so the iOS kernel routes packets across TUN!
        ipv4Settings.includedRoutes = [
            NEIPv4Route(destinationAddress: virtualDNSServerIP, subnetMask: "255.255.255.255")
        ]
        tunnelSettings.ipv4Settings = ipv4Settings

        // 3. System-wide DNS Settings directing ALL domains to our virtual DNS resolver 198.18.0.2
        let dnsSettings = NEDNSSettings(servers: [virtualDNSServerIP])
        dnsSettings.matchDomains = [""] // Intercept all DNS traffic
        tunnelSettings.dnsSettings = dnsSettings

        tunnelSettings.mtu = 1500

        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                NSLog("[DNS VIP] Failed to set tunnel network settings: %@", error.localizedDescription)
                completionHandler(error)
            } else {
                NSLog("[DNS VIP] Packet Tunnel active! iOS [VPN] icon ON. Listening for DNS on %@", self?.virtualDNSServerIP ?? "")
                completionHandler(nil)
                self?.startReadingPackets()
            }
        }
    }

    public override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[DNS VIP] Packet Tunnel stopped. Reason: \(reason.rawValue)")
        completionHandler()
    }

    public override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    public override func wake() {
        NSLog("[DNS VIP] Packet Tunnel woke up.")
    }

    // MARK: - IPC Communication with Main App (Zero App Group Dependency)
    public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let command = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        if command == "get_logs" {
            let data = try? JSONEncoder().encode(self.inMemoryLogs)
            completionHandler?(data)
        } else if command == "clear_logs" {
            self.inMemoryLogs.removeAll()
            completionHandler?("ok".data(using: .utf8))
        } else {
            completionHandler?(nil)
        }
    }

    // MARK: - Read & Filter Packets
    private func startReadingPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            for (index, packet) in packets.enumerated() {
                self.processPacket(packet, protocolFamily: protocols[index])
            }
            self.startReadingPackets()
        }
    }

    private func processPacket(_ packet: Data, protocolFamily: NSNumber) {
        guard packet.count >= 28 else { return }

        // Must be IPv4
        guard (packet[0] >> 4) == 4 else { return }

        let ipHeaderLen = Int(packet[0] & 0x0F) * 4
        guard packet.count >= ipHeaderLen + 8 else { return }

        // Must be UDP (protocol 17)
        guard packet[9] == 17 else { return }

        // Destination port must be 53 (DNS)
        let dstPort = (UInt16(packet[ipHeaderLen + 2]) << 8) | UInt16(packet[ipHeaderLen + 3])
        guard dstPort == 53 else { return }

        // Extract raw DNS Payload
        let dnsPayload = packet.subdata(in: (ipHeaderLen + 8)..<packet.count)
        guard dnsPayload.count >= 12 else { return }

        guard let domain = parseDNSQueryDomain(from: dnsPayload) else { return }
        let isBlocked = BlockList.isBlocked(domain: domain)

        // Record log item immediately
        recordLog(domain: domain, isBlocked: isBlocked)

        if isBlocked {
            // Instant 0ms Sinkhole Block (0.0.0.0 Answer)
            if let responsePacket = makeSinkholeBlockedResponse(forPacket: packet, ipHeaderLen: ipHeaderLen, dnsPayload: dnsPayload) {
                packetFlow.writePackets([responsePacket], withProtocols: [protocolFamily])
                NSLog("[DNS VIP] >>> BLOCKED: %@ -> 0.0.0.0", domain)
            }
        } else {
            // Forward allowed query to upstream DNS (1.1.1.1:53)
            forwardUpstreamDNS(dnsPayload: dnsPayload) { [weak self] answerData in
                guard let self = self, let answerData = answerData else { return }
                if let responsePacket = self.makeDNSResponsePacket(forPacket: packet, ipHeaderLen: ipHeaderLen, answerPayload: answerData) {
                    self.packetFlow.writePackets([responsePacket], withProtocols: [protocolFamily])
                }
            }
        }
    }

    private func recordLog(domain: String, isBlocked: Bool) {
        let item = DNSQueryLogItem(
            domain: domain,
            isBlocked: isBlocked,
            timestamp: Date(),
            queryType: "A",
            clientProtocol: "VPN"
        )
        inMemoryLogs.insert(item, at: 0)
        if inMemoryLogs.count > maxInMemoryLogs {
            inMemoryLogs = Array(inMemoryLogs.prefix(maxInMemoryLogs))
        }

        QueryLogManager.appendLog(domain: domain, isBlocked: isBlocked, queryType: "A", clientProtocol: "VPN")
    }

    // MARK: - Upstream Forwarding via UDP 45.90.28.0:53 (NextDNS Anycast)
    private func forwardUpstreamDNS(dnsPayload: Data, completion: @escaping (Data?) -> Void) {
        let host = NWEndpoint.Host("45.90.28.0")
        let port = NWEndpoint.Port(rawValue: 53)!
        let connection = NWConnection(host: host, port: port, using: .udp)

        var hasFinished = false
        func finish(data: Data?) {
            guard !hasFinished else { return }
            hasFinished = true
            connection.cancel()
            completion(data)
        }

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connection.send(content: dnsPayload, completion: .contentProcessed({ sendError in
                    if sendError != nil {
                        finish(data: nil)
                        return
                    }
                    connection.receive(minimumIncompleteLength: 12, maximumLength: 4096) { recvData, _, _, _ in
                        finish(data: recvData)
                    }
                }))
            } else if case .failed(_) = state {
                finish(data: nil)
            }
        }

        // 1.5s timeout safety
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            finish(data: nil)
        }

        connection.start(queue: .global())
    }

    // MARK: - Construct Sinkhole Block Response (0.0.0.0 Answer)
    private func makeSinkholeBlockedResponse(forPacket packet: Data, ipHeaderLen: Int, dnsPayload: Data) -> Data? {
        var respDNS = dnsPayload

        // Flags: 0x8180 = Response, Standard Query, No Error
        respDNS[2] = 0x81
        respDNS[3] = 0x80

        // Answer Count = 1 (ANCOUNT = 1)
        respDNS[6] = 0x00
        respDNS[7] = 0x01

        // Authority Count = 0
        respDNS[8] = 0x00
        respDNS[9] = 0x00

        // Additional Count = 0
        respDNS[10] = 0x00
        respDNS[11] = 0x00

        // 16-byte A Answer Record: Name pointer 0xC00C, Type A (1), Class IN (1), TTL 60s, Len 4, IP 0.0.0.0
        let answerRecord = Data([
            0xc0, 0x0c,             // Name pointer -> offset 12 (QNAME)
            0x00, 0x01,             // Type: A
            0x00, 0x01,             // Class: IN
            0x00, 0x00, 0x00, 0x3c, // TTL: 60 seconds
            0x00, 0x04,             // Data length: 4 bytes
            0x00, 0x00, 0x00, 0x00  // IP Address: 0.0.0.0 (Sinkhole blocked!)
        ])
        respDNS.append(answerRecord)

        return makeDNSResponsePacket(forPacket: packet, ipHeaderLen: ipHeaderLen, answerPayload: respDNS)
    }

    // MARK: - Construct Returning IPv4/UDP Packet
    private func makeDNSResponsePacket(forPacket queryPacket: Data, ipHeaderLen: Int, answerPayload: Data) -> Data? {
        let totalLen = ipHeaderLen + 8 + answerPayload.count
        var respPacket = Data(count: totalLen)

        // Copy IP Header
        respPacket.replaceSubrange(0..<ipHeaderLen, with: queryPacket.subdata(in: 0..<ipHeaderLen))

        // Swap IP Source and Destination
        for i in 0..<4 {
            let src = queryPacket[12 + i]
            let dst = queryPacket[16 + i]
            respPacket[12 + i] = dst // Source is now 198.18.0.2 (DNS Server)
            respPacket[16 + i] = src // Destination is client
        }

        // Update IP Length
        respPacket[2] = UInt8((totalLen >> 8) & 0xFF)
        respPacket[3] = UInt8(totalLen & 0xFF)

        // UDP Header
        let udpOffset = ipHeaderLen
        let clientPort0 = queryPacket[ipHeaderLen]
        let clientPort1 = queryPacket[ipHeaderLen + 1]

        // Source Port = 53
        respPacket[udpOffset] = 0x00
        respPacket[udpOffset + 1] = 0x35

        // Dest Port = Client Port
        respPacket[udpOffset + 2] = clientPort0
        respPacket[udpOffset + 3] = clientPort1

        // UDP Length
        let udpLen = 8 + answerPayload.count
        respPacket[udpOffset + 4] = UInt8((udpLen >> 8) & 0xFF)
        respPacket[udpOffset + 5] = UInt8(udpLen & 0xFF)

        // UDP Checksum = 0
        respPacket[udpOffset + 6] = 0x00
        respPacket[udpOffset + 7] = 0x00

        // DNS Payload
        respPacket.replaceSubrange((ipHeaderLen + 8)..<totalLen, with: answerPayload)

        // Recalculate IPv4 Checksum
        respPacket[10] = 0x00
        respPacket[11] = 0x00
        var checksum: UInt32 = 0
        for i in stride(from: 0, to: ipHeaderLen, by: 2) {
            let word = (UInt32(respPacket[i]) << 8) | UInt32(respPacket[i + 1])
            checksum += word
        }
        while (checksum >> 16) > 0 {
            checksum = (checksum & 0xFFFF) + (checksum >> 16)
        }
        let finalChecksum = ~UInt16(checksum)
        respPacket[10] = UInt8((finalChecksum >> 8) & 0xFF)
        respPacket[11] = UInt8(finalChecksum & 0xFF)

        return respPacket
    }

    // MARK: - DNS Domain Parser
    private func parseDNSQueryDomain(from data: Data) -> String? {
        guard data.count > 12 else { return nil }
        var position = 12
        var labels: [String] = []

        while position < data.count {
            let length = Int(data[position])
            if length == 0 { break }
            position += 1
            if position + length > data.count { return nil }
            let subData = data.subdata(in: position..<(position + length))
            if let label = String(data: subData, encoding: .utf8) {
                labels.append(label)
            }
            position += length
        }

        return labels.isEmpty ? nil : labels.joined(separator: ".")
    }
}
