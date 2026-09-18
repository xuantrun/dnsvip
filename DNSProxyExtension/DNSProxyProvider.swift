import Foundation
import NetworkExtension

public class DNSProxyProvider: NEDNSProxyProvider {

    public override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[NextDNSProxy] DNS Proxy Provider started successfully.")
        completionHandler(nil)
    }

    public override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[NextDNSProxy] DNS Proxy Provider stopped. Reason: \(reason.rawValue)")
        completionHandler()
    }

    public override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    public override func wake() {
        NSLog("[NextDNSProxy] DNS Proxy Provider woke up.")
    }

    public override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        if let udpFlow = flow as? NEAppProxyUDPFlow {
            handleUDPFlow(udpFlow)
            return true
        } else if let tcpFlow = flow as? NEAppProxyTCPFlow {
            handleTCPFlow(tcpFlow)
            return true
        }
        return false
    }

    // MARK: - UDP DNS Handling
    private func handleUDPFlow(_ flow: NEAppProxyUDPFlow) {
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            guard error == nil else {
                flow.closeReadWithError(error)
                flow.closeWriteWithError(error)
                return
            }
            self?.readUDPDatagrams(from: flow)
        }
    }

    private func readUDPDatagrams(from flow: NEAppProxyUDPFlow) {
        flow.readDatagrams { [weak self] datagrams, endpoints, error in
            guard let datagrams = datagrams, let endpoints = endpoints, error == nil else {
                flow.closeReadWithError(error)
                flow.closeWriteWithError(error)
                return
            }

            for (index, packet) in datagrams.enumerated() {
                let endpoint = endpoints[index]
                self?.inspectAndFilterDNSPacket(packet, endpoint: endpoint, flow: flow)
            }

            // Loop back to keep reading
            self?.readUDPDatagrams(from: flow)
        }
    }

    private func inspectAndFilterDNSPacket(_ packet: Data, endpoint: NWEndpoint, flow: NEAppProxyUDPFlow) {
        if let domain = parseDNSQueryDomain(from: packet) {
            let blocked = BlockList.isBlocked(domain: domain)
            
            if blocked {
                NSLog("[NextDNSProxy] BLOCKED query: %@", domain)
                if let response = createBlockedDNSResponse(for: packet) {
                    flow.writeDatagrams([response], sentByEndpoints: [endpoint]) { _ in }
                    return
                }
            } else {
                NSLog("[NextDNSProxy] PASSED query: %@", domain)
            }
        }

        // Forward normal packet
        flow.writeDatagrams([packet], sentByEndpoints: [endpoint]) { _ in }
    }

    // MARK: - TCP DNS Handling
    private func handleTCPFlow(_ flow: NEAppProxyTCPFlow) {
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            guard error == nil else {
                flow.closeReadWithError(error)
                flow.closeWriteWithError(error)
                return
            }
            self?.readTCPData(from: flow)
        }
    }

    private func readTCPData(from flow: NEAppProxyTCPFlow) {
        flow.readData { [weak self] data, error in
            guard let data = data, error == nil else {
                flow.closeReadWithError(error)
                flow.closeWriteWithError(error)
                return
            }

            // In TCP DNS, first 2 bytes are packet length
            if data.count > 2 {
                let dnsPayload = data.subdata(in: 2..<data.count)
                if let domain = self?.parseDNSQueryDomain(from: dnsPayload) {
                    if BlockList.isBlocked(domain: domain) {
                        NSLog("[NextDNSProxy-TCP] BLOCKED query: %@", domain)
                        if let blockedPayload = self?.createBlockedDNSResponse(for: dnsPayload) {
                            var tcpResponse = Data()
                            var length = UInt16(blockedPayload.count).bigEndian
                            tcpResponse.append(Data(bytes: &length, count: 2))
                            tcpResponse.append(blockedPayload)
                            flow.write(tcpResponse) { _ in }
                            self?.readTCPData(from: flow)
                            return
                        }
                    }
                }
            }

            flow.write(data) { _ in }
            self?.readTCPData(from: flow)
        }
    }

    // MARK: - DNS Packet Parser
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

    // MARK: - Synthetic DNS Response (NXDOMAIN)
    private func createBlockedDNSResponse(for query: Data) -> Data? {
        guard query.count >= 12 else { return nil }
        var response = query
        // Flags: QR=1 (Response), Opcode=0, AA=1, TC=0, RD=1, RA=1, Z=0, RCODE=3 (NXDOMAIN)
        response[2] = 0x85
        response[3] = 0x83
        return response
    }
}
