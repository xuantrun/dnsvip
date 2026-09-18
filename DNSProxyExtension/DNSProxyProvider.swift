import Foundation
import NetworkExtension

public class DNSProxyProvider: NEPacketTunnelProvider {

    private var inMemoryLogs: [DNSQueryLogItem] = []
    private let maxInMemoryLogs = 250
    private let upstreamDoHURL = URL(string: "https://cloudflare-dns.com/dns-query")!
    private let dohSession = URLSession(configuration: .ephemeral)

    public override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[DNS VIP] Packet Tunnel starting...")

        // Virtual tunnel settings routing DNS queries to virtual IP 198.18.0.1
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // 1. IPv4 Route: Intercept traffic destined for the virtual DNS address
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [
            NEIPv4Route(destinationAddress: "198.18.0.1", subnetMask: "255.255.255.255")
        ]
        tunnelSettings.ipv4Settings = ipv4Settings

        // 2. DNS Settings: System-wide DNS routing directing queries to 198.18.0.1
        let dnsSettings = NEDNSSettings(servers: ["198.18.0.1"])
        dnsSettings.matchDomains = [""] // Intercept all DNS traffic
        tunnelSettings.dnsSettings = dnsSettings

        tunnelSettings.mtu = 1500

        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                NSLog("[DNS VIP] Failed to set tunnel network settings: %@", error.localizedDescription)
                completionHandler(error)
            } else {
                NSLog("[DNS VIP] Packet Tunnel started successfully! iOS [VPN] icon active.")
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

    // MARK: - IPC Communication with Main App (No App Groups Required)
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

    // MARK: - Packet Interception & DNS Routing
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

        // Verify IPv4
        let version = packet[0] >> 4
        guard version == 4 else { return }

        let ipHeaderLen = Int(packet[0] & 0x0F) * 4
        guard packet.count >= ipHeaderLen + 8 else { return }

        // Verify UDP (protocol 17)
        let proto = packet[9]
        guard proto == 17 else { return }

        // UDP Header
        let dstPort = (UInt16(packet[ipHeaderLen + 2]) << 8) | UInt16(packet[ipHeaderLen + 3])
        guard dstPort == 53 else { return } // Standard DNS port

        // Extract DNS Payload
        let dnsPayload = packet.subdata(in: (ipHeaderLen + 8)..<packet.count)
        guard dnsPayload.count >= 12 else { return }

        guard let domain = parseDNSQueryDomain(from: dnsPayload) else { return }
        let isBlocked = BlockList.isBlocked(domain: domain)

        // Record log item immediately
        recordLog(domain: domain, isBlocked: isBlocked)

        if isBlocked {
            // Synthetic instant NXDOMAIN response (0ms block)
            if let responsePacket = makeBlockedDNSResponse(forPacket: packet, ipHeaderLen: ipHeaderLen, dnsPayload: dnsPayload) {
                packetFlow.writePackets([responsePacket], withProtocols: [protocolFamily])
            }
        } else {
            // Forward query to Cloudflare DoH (RFC 8484)
            forwardDoHQuery(dnsPayload: dnsPayload) { [weak self] answerData in
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
            clientProtocol: "DoH/VPN"
        )
        inMemoryLogs.insert(item, at: 0)
        if inMemoryLogs.count > maxInMemoryLogs {
            inMemoryLogs = Array(inMemoryLogs.prefix(maxInMemoryLogs))
        }

        // Also persist to shared manager
        QueryLogManager.appendLog(domain: domain, isBlocked: isBlocked, queryType: "A", clientProtocol: "DoH/VPN")
    }

    // MARK: - Forwarding via Cloudflare DoH
    private func forwardDoHQuery(dnsPayload: Data, completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: upstreamDoHURL)
        request.httpMethod = "POST"
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = dnsPayload
        request.timeoutInterval = 3.0

        let task = dohSession.dataTask(with: request) { data, response, error in
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, let data = data {
                completion(data)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }

    // MARK: - Constructing Synthetic NXDOMAIN Response
    private func makeBlockedDNSResponse(forPacket packet: Data, ipHeaderLen: Int, dnsPayload: Data) -> Data? {
        var respDNS = dnsPayload
        // Header flags: 0x8183 = Response + Recursion Desired + Recursion Available + NXDOMAIN
        respDNS[2] = 0x81
        respDNS[3] = 0x83

        return makeDNSResponsePacket(forPacket: packet, ipHeaderLen: ipHeaderLen, answerPayload: respDNS)
    }

    // MARK: - IP/UDP Packet Builder
    private func makeDNSResponsePacket(forPacket queryPacket: Data, ipHeaderLen: Int, answerPayload: Data) -> Data? {
        let totalLen = ipHeaderLen + 8 + answerPayload.count
        var respPacket = Data(count: totalLen)

        // 1. Copy IP header from original query
        respPacket.replaceSubrange(0..<ipHeaderLen, with: queryPacket.subdata(in: 0..<ipHeaderLen))

        // Swap IP source and destination (answer goes back to client)
        for i in 0..<4 {
            let src = queryPacket[12 + i]
            let dst = queryPacket[16 + i]
            respPacket[12 + i] = dst // new source is DNS server
            respPacket[16 + i] = src // new dest is client
        }

        // Update IP total length
        respPacket[2] = UInt8((totalLen >> 8) & 0xFF)
        respPacket[3] = UInt8(totalLen & 0xFF)

        // 2. UDP Header
        let udpOffset = ipHeaderLen
        let clientPort0 = queryPacket[ipHeaderLen]
        let clientPort1 = queryPacket[ipHeaderLen + 1]

        // Source port = 53 (DNS)
        respPacket[udpOffset] = 0x00
        respPacket[udpOffset + 1] = 0x35
        // Dest port = client port
        respPacket[udpOffset + 2] = clientPort0
        respPacket[udpOffset + 3] = clientPort1

        let udpLen = 8 + answerPayload.count
        respPacket[udpOffset + 4] = UInt8((udpLen >> 8) & 0xFF)
        respPacket[udpOffset + 5] = UInt8(udpLen & 0xFF)
        // UDP checksum (0 is valid for IPv4)
        respPacket[udpOffset + 6] = 0x00
        respPacket[udpOffset + 7] = 0x00

        // 3. Append DNS Payload
        respPacket.replaceSubrange((ipHeaderLen + 8)..<totalLen, with: answerPayload)

        // Recalculate IP Checksum
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
