import Foundation
import Combine
import NetworkExtension
import UIKit

public enum DNSProtocolType: String, CaseIterable, Identifiable {
    case doh = "DNS-over-HTTPS (DoH)"
    case dot = "DNS-over-TLS (DoT)"
    
    public var id: String { self.rawValue }
}

public struct NextDNSTestStatus: Codable {
    public let status: String?
    public let `protocol`: String?
    public let profile: String?
    public let client: String?
    public let destIP: String?
}

public class DNSManager: ObservableObject {
    public static let shared = DNSManager()

    @Published public var isEnabled: Bool = false
    @Published public var isVerifying: Bool = false
    @Published public var liveStatusText: String = "Chưa kết nối"
    @Published public var isConnectedToNextDNS: Bool = false
    @Published public var nextDnsID: String = "" {
        didSet {
            UserDefaults.standard.set(nextDnsID, forKey: "nextdns_profile_id")
        }
    }
    @Published public var selectedProtocol: DNSProtocolType = .doh {
        didSet {
            UserDefaults.standard.set(selectedProtocol.rawValue, forKey: "dns_protocol_type")
        }
    }
    @Published public var deviceName: String = "iPhone" {
        didSet {
            UserDefaults.standard.set(deviceName, forKey: "device_name")
        }
    }
    @Published public var errorMessage: String? = nil

    private let dnsSettingsManager = NEDNSSettingsManager.shared()

    private init() {
        self.nextDnsID = UserDefaults.standard.string(forKey: "nextdns_profile_id") ?? ""
        if let protoRaw = UserDefaults.standard.string(forKey: "dns_protocol_type"),
           let proto = DNSProtocolType(rawValue: protoRaw) {
            self.selectedProtocol = proto
        }
        self.deviceName = UserDefaults.standard.string(forKey: "device_name") ?? UIDevice.current.name
        
        loadStatus()
    }

    public func loadStatus() {
        dnsSettingsManager.loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading DNS settings: \(error.localizedDescription)")
                }
                self?.isEnabled = self?.dnsSettingsManager.isEnabled ?? false
                if self?.isEnabled == true {
                    self?.checkLiveConnection()
                } else {
                    self?.liveStatusText = "Chưa kích hoạt DNS"
                    self?.isConnectedToNextDNS = false
                }
            }
        }
    }

    public func toggleConnection() {
        if isEnabled {
            disableDNS()
        } else {
            enableDNS()
        }
    }

    public func enableDNS() {
        let cleanID = nextDnsID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedDeviceName = deviceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "iPhone"

        dnsSettingsManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Không thể tải cấu hình: \(error.localizedDescription)"
                }
                return
            }

            switch self.selectedProtocol {
            case .doh:
                let doh = NEDNSOverHTTPSSettings(servers: ["45.90.28.0", "45.90.30.0"])
                let urlString: String
                if cleanID.isEmpty {
                    urlString = "https://dns.nextdns.io"
                } else {
                    urlString = "https://dns.nextdns.io/\(cleanID)/\(sanitizedDeviceName)"
                }
                doh.serverURL = URL(string: urlString)
                self.dnsSettingsManager.dnsSettings = doh

            case .dot:
                let dot = NEDNSOverTLSSettings(servers: ["45.90.28.0", "45.90.30.0"])
                if cleanID.isEmpty {
                    dot.serverName = "anycast.dns.nextdns.io"
                } else {
                    dot.serverName = "\(cleanID).dns.nextdns.io"
                }
                self.dnsSettingsManager.dnsSettings = dot
            }

            self.dnsSettingsManager.localizedDescription = cleanID.isEmpty ? "NextDNS Resolver" : "NextDNS (\(cleanID))"

            self.dnsSettingsManager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        self?.errorMessage = "Lỗi lưu cấu hình: \(saveError.localizedDescription)"
                        self?.isEnabled = false
                    } else {
                        self?.isEnabled = true
                        self?.errorMessage = nil
                        self?.checkLiveConnection()
                    }
                }
            }
        }
    }

    public func disableDNS() {
        dnsSettingsManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            self.dnsSettingsManager.removeFromPreferences { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isEnabled = false
                    self?.liveStatusText = "Đã tắt bảo vệ DNS"
                    self?.isConnectedToNextDNS = false
                }
            }
        }
    }

    public func checkLiveConnection() {
        isVerifying = true
        guard let url = URL(string: "https://test.nextdns.io") else {
            isVerifying = false
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isVerifying = false
                guard let data = data,
                      let res = try? JSONDecoder().decode(NextDNSTestStatus.self, from: data) else {
                    self?.liveStatusText = "Đang sử dụng cấu hình DNS máy chủ"
                    self?.isConnectedToNextDNS = true
                    return
                }

                if res.status == "ok" {
                    self?.isConnectedToNextDNS = true
                    let proto = res.protocol ?? "DoH"
                    self?.liveStatusText = "Đã kết nối an toàn qua \(proto)"
                } else {
                    self?.isConnectedToNextDNS = false
                    self?.liveStatusText = "Đang áp dụng bộ lọc cục bộ"
                }
            }
        }.resume()
    }

    public func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
