import Foundation
import Combine
import NetworkExtension
import UIKit

public class DNSManager: ObservableObject {
    public static let shared = DNSManager()

    @Published public var isEnabled: Bool = false
    @Published public var isProxyInstalled: Bool = false
    @Published public var isVerifying: Bool = false
    @Published public var statusMessage: String = "Sẵn sàng bảo vệ"
    @Published public var upstreamServer: String = "Cloudflare DoH (1.1.1.1)"
    @Published public var errorMessage: String? = nil

    private let dnsProxyManager = NEDNSProxyManager.shared()
    private let dnsSettingsManager = NEDNSSettingsManager.shared()

    private init() {
        loadStatus()
    }

    public func loadStatus() {
        // 1. Load DNS Proxy Manager status
        dnsProxyManager.loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                self?.isProxyInstalled = self?.dnsProxyManager.isEnabled ?? false
                if self?.isProxyInstalled == true {
                    self?.isEnabled = true
                    self?.statusMessage = "Đang kích hoạt Proxy DNS & Chặn Game"
                }
            }
        }

        // 2. Load DNS Settings Manager status
        dnsSettingsManager.loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                let settingsEnabled = self?.dnsSettingsManager.isEnabled ?? false
                if settingsEnabled {
                    self?.isEnabled = true
                    self?.statusMessage = "Đang áp dụng bộ lọc DNS VIP"
                }
            }
        }
    }

    public func toggleProtection() {
        if isEnabled || isProxyInstalled {
            disableAllProtection()
        } else {
            enableAllProtection()
        }
    }

    // Auto-request VPN & DNS permission like NextDNS without any codes!
    public func enableAllProtection(completion: ((Bool) -> Void)? = nil) {
        statusMessage = "Đang yêu cầu cấp quyền hệ thống..."
        errorMessage = nil

        // Step 1: Configure & Save NEDNSProxyManager -> Appears in iOS Settings > DNS with App Icon!
        dnsProxyManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            let proto = NEDNSProxyProviderProtocol()
            proto.providerBundleIdentifier = "com.nextdns.custom.dnsproxy"
            
            self.dnsProxyManager.providerProtocol = proto
            self.dnsProxyManager.localizedDescription = "DNS VIP"
            self.dnsProxyManager.isEnabled = true

            self.dnsProxyManager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        NSLog("[DNSManager] DNS Proxy save error: %@", saveError.localizedDescription)
                        self?.errorMessage = "Chưa cấp quyền: \(saveError.localizedDescription)"
                    } else {
                        self?.isProxyInstalled = true
                        self?.isEnabled = true
                        self?.statusMessage = "Đang bảo vệ • Đã kích hoạt DNS VIP"
                        NSLog("[DNSManager] DNS VIP Proxy installed into iOS Settings successfully!")
                    }
                }
            }
        }

        // Step 2: Configure System-wide DoH Resolver (Cloudflare / Quad9 / NextDNS Public)
        dnsSettingsManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }

            let doh = NEDNSOverHTTPSSettings(servers: ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111"])
            doh.serverURL = URL(string: "https://cloudflare-dns.com/dns-query")

            self.dnsSettingsManager.dnsSettings = doh
            self.dnsSettingsManager.localizedDescription = "DNS VIP"

            self.dnsSettingsManager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        NSLog("[DNSManager] Settings error: %@", saveError.localizedDescription)
                    } else {
                        self?.isEnabled = true
                        self?.statusMessage = "Đang bảo vệ • Đã kích hoạt DNS VIP"
                        completion?(true)
                    }
                }
            }
        }
    }

    public func disableAllProtection() {
        statusMessage = "Đang tắt..."
        
        dnsProxyManager.loadFromPreferences { [weak self] _ in
            self?.dnsProxyManager.removeFromPreferences { _ in
                DispatchQueue.main.async {
                    self?.isProxyInstalled = false
                }
            }
        }

        dnsSettingsManager.loadFromPreferences { [weak self] _ in
            self?.dnsSettingsManager.removeFromPreferences { _ in
                DispatchQueue.main.async {
                    self?.isEnabled = false
                    self?.statusMessage = "Chưa kích hoạt"
                }
            }
        }
    }

    public func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
