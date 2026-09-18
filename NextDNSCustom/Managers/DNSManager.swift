import Foundation
import Combine
import NetworkExtension

public enum DNSProtocolType: String, CaseIterable, Identifiable {
    case doh = "DNS-over-HTTPS (DoH)"
    case dot = "DNS-over-TLS (DoT)"
    
    public var id: String { self.rawValue }
}

public class DNSManager: ObservableObject {
    public static let shared = DNSManager()

    @Published public var isEnabled: Bool = false
    @Published public var isProxyActive: Bool = false
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
    @Published public var blockedQueriesCount: Int = 0
    @Published public var totalQueriesCount: Int = 0
    @Published public var errorMessage: String? = nil

    private let dnsSettingsManager = NEDNSSettingsManager.shared()
    private let dnsProxyManager = NEDNSProxyManager.shared()

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
                let doh = NEDNSOverHTTPSProtocol()
                let urlString: String
                if cleanID.isEmpty {
                    urlString = "https://dns.nextdns.io"
                } else {
                    urlString = "https://dns.nextdns.io/\(cleanID)/\(sanitizedDeviceName)"
                }
                doh.serverURL = URL(string: urlString)
                self.dnsSettingsManager.dnsSettings = doh

            case .dot:
                let dot = NEDNSOverTLSProtocol()
                if cleanID.isEmpty {
                    dot.serverName = "anycast.dns.nextdns.io"
                } else {
                    dot.serverName = "\(cleanID).dns.nextdns.io"
                }
                self.dnsSettingsManager.dnsSettings = dot
            }

            self.dnsSettingsManager.localizedDescription = cleanID.isEmpty ? "NextDNS Resolver" : "NextDNS (\(cleanID))"
            self.dnsSettingsManager.isEnabled = true

            self.dnsSettingsManager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        self?.errorMessage = "Lỗi lưu cấu hình: \(saveError.localizedDescription)"
                        self?.isEnabled = false
                    } else {
                        self?.isEnabled = true
                        self?.errorMessage = nil
                    }
                }
            }
        }
    }

    public func disableDNS() {
        dnsSettingsManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            self.dnsSettingsManager.isEnabled = false
            self.dnsSettingsManager.saveToPreferences { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isEnabled = false
                }
            }
        }
    }
}
