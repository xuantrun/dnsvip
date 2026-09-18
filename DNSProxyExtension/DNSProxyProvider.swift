import Foundation
import NetworkExtension

public class DNSProxyProvider: NEPacketTunnelProvider {

    public override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[DNS VIP] Packet Tunnel starting...")

        // Configure virtual network tunnel for DNS VIP
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // 1. IPv4 Settings: virtual subnet for DNS tunnel
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelSettings.ipv4Settings = ipv4Settings

        // 2. DNS Settings: System-wide DNS routing with matching for all domains
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
        dnsSettings.matchDomains = [""] // Intercept all DNS traffic
        tunnelSettings.dnsSettings = dnsSettings

        tunnelSettings.mtu = 1500

        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                NSLog("[DNS VIP] Failed to set tunnel network settings: %@", error.localizedDescription)
                completionHandler(error)
            } else {
                NSLog("[DNS VIP] Packet Tunnel started! iOS [VPN] icon is now active.")
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

    private func startReadingPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            for (index, packet) in packets.enumerated() {
                self.inspectAndFilterPacket(packet)
                self.packetFlow.writePackets([packet], withProtocols: [protocols[index]])
            }
            self.startReadingPackets()
        }
    }

    private func inspectAndFilterPacket(_ data: Data) {
        // Parse DNS query if packet has UDP DNS payload
        guard data.count > 28 else { return }
        let payload = data.subdata(in: 28..<data.count)
        if let domain = parseDNSQueryDomain(from: payload) {
            let blocked = BlockList.isBlocked(domain: domain)
            QueryLogManager.appendLog(domain: domain, isBlocked: blocked, queryType: "A", clientProtocol: "VPN")
            if blocked {
                NSLog("[DNS VIP] BLOCKED VPN query: %@", domain)
            }
        }
    }

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
