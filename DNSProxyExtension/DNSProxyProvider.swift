import Foundation
import NetworkExtension
import Darwin

public class DNSProxyProvider: NEPacketTunnelProvider {

    private var inMemoryLogs: [DNSQueryLogItem] = []
    private let maxInMemoryLogs = 350
    private let virtualInterfaceIP = "198.18.0.1"
    private let virtualDNSServerIP = "198.18.0.2"
    private let primaryUpstreamDNS = "45.90.28.0" // NextDNS Anycast
    private let fallbackDNS1 = "1.1.1.1"          // Cloudflare Anycast
    private let fallbackDNS2 = "8.8.8.8"          // Google Anycast
    private let packetQueue = DispatchQueue(label: "com.dnsvip.packetQueue", qos: .userInteractive)

    public override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[DNS VIP] Packet Tunnel starting in background...")

        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // 1. IPv4 Virtual Interface & Routing
        let ipv4Settings = NEIPv4Settings(addresses: [virtualInterfaceIP], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [
            NEIPv4Route(destinationAddress: virtualDNSServerIP, subnetMask: "255.255.255.255")
        ]
        tunnelSettings.ipv4Settings = ipv4Settings

        // 2. IPv6 Virtual Interface & Routing (Crucial for modern iOS carriers like Viettel/Vinaphone)
        let ipv6Settings = NEIPv6Settings(addresses: ["fd00::1"], networkPrefixLengths: [64])
        ipv6Settings.includedRoutes = [
            NEIPv6Route(destinationAddress: "fd00::2", networkPrefixLength: 128)
        ]
        tunnelSettings.ipv6Settings = ipv6Settings

        // 3. Direct ALL DNS traffic to our virtual DNS IPs
        let dnsSettings = NEDNSSettings(servers: [virtualDNSServerIP, "fd00::2"])
        dnsSettings.matchDomains = [""]
        tunnelSettings.dnsSettings = dnsSettings

        tunnelSettings.mtu = 1500

        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                NSLog("[DNS VIP] Failed to set tunnel network settings: %@", error.localizedDescription)
                completionHandler(error)
            } else {
                NSLog("[DNS VIP] Packet Tunnel active! 24/7 background filtering ready.")
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
        NSLog("[DNS VIP] System sleeping...")
        completionHandler()
    }

    public override func wake() {
        NSLog("[DNS VIP] System woke up, ready.")
    }

    // MARK: - IPC Communication with Main App
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

    // MARK: - Packet Interception & Processing
    private func startReadingPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            self.packetQueue.async {
                for (index, packet) in packets.enumerated() {
                    self.processPacket(packet, protocolFamily: protocols[index])
                }
            }
            self.startReadingPackets()
        }
    }

    private func processPacket(_ packet: Data, protocolFamily: NSNumber) {
        guard packet.count >= 28 else { return }

        let version = packet[0] >> 4

        if version == 4 {
            // IPv4 Packet
            let ipHeaderLen = Int(packet[0] & 0x0F) * 4
            guard packet.count >= ipHeaderLen + 8 else { return }
            guard packet[9] == 17 else { return } // UDP

            let dstPort = (UInt16(packet[ipHeaderLen + 2]) << 8) | UInt16(packet[ipHeaderLen + 3])
            guard dstPort == 53 else { return }

            let dnsPayload = packet.subdata(in: (ipHeaderLen + 8)..<packet.count)
            guard let queryInfo = parseDNSQuery(from: dnsPayload) else { return }

            let isBlocked = BlockList.isBlocked(domain: queryInfo.domain)
            recordLog(domain: queryInfo.domain, isBlocked: isBlocked, queryType: queryInfo.qtypeName)

            if isBlocked {
                if let responsePacket = makeIPv4SinkholeResponse(forPacket: packet, ipHeaderLen: ipHeaderLen, dnsPayload: dnsPayload, queryInfo: queryInfo) {
                    self.packetFlow.writePackets([responsePacket], withProtocols: [protocolFamily])
                    NSLog("[DNS VIP] Background BLOCKED (IPv4): %@", queryInfo.domain)
                }
            } else {
                if let answerData = forwardViaSocket(dnsPayload: dnsPayload) {
                    if let responsePacket = makeIPv4ResponsePacket(forPacket: packet, ipHeaderLen: ipHeaderLen, answerPayload: answerData) {
                        self.packetFlow.writePackets([responsePacket], withProtocols: [protocolFamily])
                    }
                }
            }
        }
    }

    private func recordLog(domain: String, isBlocked: Bool, queryType: String) {
        let item = DNSQueryLogItem(
            domain: domain,
            isBlocked: isBlocked,
            timestamp: Date(),
            queryType: queryType,
            clientProtocol: "VPN 24/7"
        )
        inMemoryLogs.insert(item, at: 0)
        if inMemoryLogs.count > maxInMemoryLogs {
            inMemoryLogs = Array(inMemoryLogs.prefix(maxInMemoryLogs))
        }

        QueryLogManager.appendLog(domain: domain, isBlocked: isBlocked, queryType: queryType, clientProtocol: "VPN 24/7")
    }

    // MARK: - DNS Parser Struct & Helper
    private struct DNSQueryInfo {
        let domain: String
        let qtype: UInt16
        let questionEndOffset: Int

        var qtypeName: String {
            switch qtype {
            case 1: return "A"
            case 28: return "AAAA"
            case 5: return "CNAME"
            case 65: return "HTTPS"
            default: return "T\(qtype)"
            }
        }
    }

    private func parseDNSQuery(from data: Data) -> DNSQueryInfo? {
        guard data.count > 12 else { return nil }
        var position = 12
        var labels: [String] = []

        while position < data.count {
            let length = Int(data[position])
            if length == 0 {
                position += 1
                break
            }
            position += 1
            if position + length > data.count { return nil }
            let subData = data.subdata(in: position..<(position + length))
            if let label = String(data: subData, encoding: .utf8) {
                labels.append(label)
            }
            position += length
        }

        guard !labels.isEmpty, position + 4 <= data.count else { return nil }
        let qtype = (UInt16(data[position]) << 8) | UInt16(data[position + 1])
        let questionEndOffset = position + 4
        return DNSQueryInfo(domain: labels.joined(separator: "."), qtype: qtype, questionEndOffset: questionEndOffset)
    }

    // MARK: - Resilient Socket Forward with Failover
    private func forwardViaSocket(dnsPayload: Data) -> Data? {
        // 1. Try primary upstream (NextDNS 45.90.28.0)
        if let res = querySocket(serverIP: primaryUpstreamDNS, dnsPayload: dnsPayload, timeoutMs: 500) {
            return res
        }
        // 2. Failover 1 (Cloudflare 1.1.1.1)
        if let res = querySocket(serverIP: fallbackDNS1, dnsPayload: dnsPayload, timeoutMs: 500) {
            return res
        }
        // 3. Failover 2 (Google 8.8.8.8)
        return querySocket(serverIP: fallbackDNS2, dnsPayload: dnsPayload, timeoutMs: 800)
    }

    private func querySocket(serverIP: String, dnsPayload: Data, timeoutMs: Int) -> Data? {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: Int32((timeoutMs % 1000) * 1000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var serverAddr = sockaddr_in()
        serverAddr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = UInt16(53).bigEndian
        inet_pton(AF_INET, serverIP, &serverAddr.sin_addr)

        let sent = dnsPayload.withUnsafeBytes { ptr in
            withUnsafePointer(to: &serverAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.sendto(fd, ptr.baseAddress, dnsPayload.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let recvd = Darwin.recv(fd, &buffer, buffer.count, 0)
        guard recvd > 0 else { return nil }

        return Data(buffer.prefix(recvd))
    }

    // MARK: - Construct RFC-Compliant Sinkhole Block Response
    private func makeIPv4SinkholeResponse(forPacket packet: Data, ipHeaderLen: Int, dnsPayload: Data, queryInfo: DNSQueryInfo) -> Data? {
        var respDNS = dnsPayload.subdata(in: 0..<queryInfo.questionEndOffset)

        // Header Flags: Standard response, No error
        respDNS[2] = 0x81
        respDNS[3] = 0x80

        // QDCOUNT = 1
        respDNS[4] = 0x00
        respDNS[5] = 0x01

        respDNS[8] = 0x00  // NSCOUNT = 0
        respDNS[9] = 0x00
        respDNS[10] = 0x00 // ARCOUNT = 0
        respDNS[11] = 0x00

        if queryInfo.qtype == 1 {
            // Type A: ANCOUNT = 1, Answer = 0.0.0.0
            respDNS[6] = 0x00
            respDNS[7] = 0x01

            let answerRecord = Data([
                0xc0, 0x0c,             // Pointer to offset 12 (QNAME)
                0x00, 0x01,             // Type: A
                0x00, 0x01,             // Class: IN
                0x00, 0x00, 0x00, 0x3c, // TTL: 60 seconds
                0x00, 0x04,             // Length: 4 bytes
                0x00, 0x00, 0x00, 0x00  // IP: 0.0.0.0
            ])
            respDNS.append(answerRecord)
        } else if queryInfo.qtype == 28 {
            // Type AAAA: ANCOUNT = 1, Answer = :: (all zeros)
            respDNS[6] = 0x00
            respDNS[7] = 0x01

            var answerRecord = Data([
                0xc0, 0x0c,             // Pointer to offset 12 (QNAME)
                0x00, 0x1c,             // Type: AAAA
                0x00, 0x01,             // Class: IN
                0x00, 0x00, 0x00, 0x3c, // TTL: 60 seconds
                0x00, 0x10              // Length: 16 bytes
            ])
            answerRecord.append(contentsOf: [UInt8](repeating: 0, count: 16))
            respDNS.append(answerRecord)
        } else {
            // Type 65 (HTTPS/SVCB) or other: ANCOUNT = 0 (Empty NOERROR)
            // Client resolver immediately falls back to A/AAAA and gets blocked
            respDNS[6] = 0x00
            respDNS[7] = 0x00
        }

        return makeIPv4ResponsePacket(forPacket: packet, ipHeaderLen: ipHeaderLen, answerPayload: respDNS)
    }

    // MARK: - Construct Returning IPv4/UDP Packet
    private func makeIPv4ResponsePacket(forPacket queryPacket: Data, ipHeaderLen: Int, answerPayload: Data) -> Data? {
        let totalLen = ipHeaderLen + 8 + answerPayload.count
        var respPacket = Data(count: totalLen)

        // Copy IP Header
        respPacket.replaceSubrange(0..<ipHeaderLen, with: queryPacket.subdata(in: 0..<ipHeaderLen))

        // Swap IP Source and Destination
        for i in 0..<4 {
            let src = queryPacket[12 + i]
            let dst = queryPacket[16 + i]
            respPacket[12 + i] = dst // Source is DNS Server
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
}
